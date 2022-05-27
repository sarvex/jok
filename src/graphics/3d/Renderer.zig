const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const sdl = @import("sdl");
const jok = @import("../../jok.zig");
const @"3d" = jok.gfx.@"3d";
const zmath = @"3d".zmath;
const Camera = @"3d".Camera;
const Self = @This();

/// Vertex Indices
indices: std.ArrayList(u32),
sorted: bool = false,

/// Triangle vertices
vertices: std.ArrayList(sdl.Vertex),

/// Depth of vertices
depths: std.ArrayList(f32),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .indices = std.ArrayList(u32).init(allocator),
        .vertices = std.ArrayList(sdl.Vertex).init(allocator),
        .depths = std.ArrayList(f32).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.indices.deinit();
    self.vertices.deinit();
    self.depths.deinit();
}

/// Clear mesh data
pub fn clearVertex(self: *Self, retain_memory: bool) void {
    if (retain_memory) {
        self.indices.clearRetainingCapacity();
        self.vertices.clearRetainingCapacity();
        self.depths.clearRetainingCapacity();
    } else {
        self.indices.clearAndFree();
        self.vertices.clearAndFree();
        self.depths.clearAndFree();
    }
    self.sorted = false;
}

/// Append vertex data
pub fn appendVertex(
    self: *Self,
    renderer: sdl.Renderer,
    model: zmath.Mat,
    camera: *Camera,
    indices: []const u16,
    positions: []const [3]f32,
    colors: ?[]const sdl.Color,
    texcoords: ?[]const [2]f32,
    cull_faces: bool,
) !void {
    assert(@rem(indices.len, 3) == 0);
    assert(if (colors) |cs| cs.len == positions.len else true);
    assert(if (texcoords) |ts| ts.len == positions.len else true);
    if (indices.len == 0) return;
    const vp = renderer.getViewport();
    const mvp = zmath.mul(model, camera.getViewProjectMatrix());
    const base_index = @intCast(u32, self.vertices.items.len);
    var clipped_indices = std.StaticBitSet(math.maxInt(u16)).initEmpty();

    // Add vertices
    try self.vertices.ensureTotalCapacity(self.vertices.items.len + positions.len);
    try self.depths.ensureTotalCapacity(self.vertices.items.len + positions.len);
    for (positions) |pos, i| {
        // Do MVP transforming
        const pos_clip = zmath.mul(zmath.f32x4(pos[0], pos[1], pos[2], 1.0), mvp);
        const ndc = pos_clip / zmath.splat(zmath.Vec, pos_clip[3]);
        if ((ndc[0] < -1 or ndc[0] > 1) or
            (ndc[1] < -1 or ndc[1] > 1) or
            (ndc[2] < -1 or ndc[2] > 1))
        {
            clipped_indices.set(i);
        }
        const pos_screen = zmath.mul(ndc, zmath.loadMat43(&[_]f32{
            // zig fmt: off
            0.5 * @intToFloat(f32, vp.width), 1.0, 0.0,
            0.0, -0.5 * @intToFloat(f32, vp.height), 0.0,
            0.0, 0.0, 0.5,
            0.5 * @intToFloat(f32, vp.width), 0.5 * @intToFloat(f32, vp.height), 0.5,
        }));
        self.vertices.appendAssumeCapacity(.{
            .position = .{ .x = pos_screen[0], .y = pos_screen[1] },
            .color = if (colors) |cs| cs[i] else sdl.Color.white,
            .tex_coord = if (texcoords) |tex| .{ .x = tex[i][0], .y = tex[i][1] } else undefined,
        });
        self.depths.appendAssumeCapacity(pos_screen[2]);
    }
    errdefer {
        self.vertices.resize(self.vertices.items.len - positions.len) catch unreachable;
        self.depths.resize(self.vertices.items.len - positions.len) catch unreachable;
    }

    // Add indices
    try self.indices.ensureTotalCapacity(self.indices.items.len + indices.len);
    var i: usize = 2;
    while (i < indices.len) : (i += 3) {
        const idx0 = indices[i - 2];
        const idx1 = indices[i - 1];
        const idx2 = indices[i];

        // Ignore triangles outside of clip space
        if (clipped_indices.isSet(idx0) and
            clipped_indices.isSet(idx1) and
            clipped_indices.isSet(idx2))
        {
            const pos_clip0 = zmath.mul(zmath.f32x4(
                positions[idx0][0],
                positions[idx0][1],
                positions[idx0][2],
                1.0,
            ), mvp);
            const ndc0 = pos_clip0 / zmath.splat(zmath.Vec, pos_clip0[3]);
            const pos_clip1 = zmath.mul(zmath.f32x4(
                positions[idx1][0],
                positions[idx1][1],
                positions[idx1][2],
                1.0,
            ), mvp);
            const ndc1 = pos_clip1 / zmath.splat(zmath.Vec, pos_clip1[3]);
            const pos_clip2 = zmath.mul(zmath.f32x4(
                positions[idx2][0],
                positions[idx2][1],
                positions[idx2][2],
                1.0,
            ), mvp);
            const ndc2 = pos_clip2 / zmath.splat(zmath.Vec, pos_clip2[3]);
            if (isTriangleOutside(ndc0, ndc1, ndc2)) {
                continue;
            }
        }

        // Ignore triangles facing away from camera (front faces' vertices are clock-wise organized)
        if (cull_faces) {
            const v0 = zmath.mul(zmath.f32x4(positions[idx0][0], positions[idx0][1], positions[idx0][2], 1), model);
            const v1 = zmath.mul(zmath.f32x4(positions[idx1][0], positions[idx1][1], positions[idx1][2], 1), model);
            const v2 = zmath.mul(zmath.f32x4(positions[idx2][0], positions[idx2][1], positions[idx2][2], 1), model);
            const center = (v0 + v1 + v2) / zmath.splat(zmath.Vec, 3.0);
            const v0v1 = v1 - v0;
            const v0v2 = v2 - v0;
            const face_dir = zmath.normalize3(zmath.cross3(v0v1, v0v2));
            const camera_dir = zmath.normalize3(center - camera.position);
            const angles = zmath.dot3(face_dir, camera_dir);
            if (angles[0] >= 0) continue;
        }

        // Append indices
        self.indices.appendSliceAssumeCapacity(&[_]u32{
            idx0 + base_index,
            idx1 + base_index,
            idx2 + base_index,
        });
    }

    self.sorted = false;
}

/// Test whether a triangle is outside of clipping space
/// Using Seperating Axis Therom (aka SAT) algorithm
inline fn isTriangleOutside(v0: zmath.Vec, v1: zmath.Vec, v2: zmath.Vec) bool {
    const S = struct {
        // Face normals of the AABB, which is our clipping space [-1, 1]
        const n0 = @"3d".v_right;
        const n1 = @"3d".v_up;
        const n2 = @"3d".v_forward;

        // Testing axis
        inline fn checkAxis(axis: zmath.Vec, _v0: zmath.Vec, _v1: zmath.Vec, _v2: zmath.Vec) bool {
            // Project all 3 vertices of the triangle onto the Seperating axis
            const p0 = zmath.dot3(_v0, axis)[0];
            const p1 = zmath.dot3(_v1, axis)[0];
            const p2 = zmath.dot3(_v2, axis)[0];

            // Project the AABB onto the seperating axis
            const r = @fabs(zmath.dot3(n0, axis)[0]) +
                @fabs(zmath.dot3(n1, axis)[0]) + @fabs(zmath.dot3(n2, axis)[0]);

            // Now do the actual test, basically see if either of
            // the most extreme of the triangle points intersects r
            if (math.max(-math.max3(p0, p1, p2), math.min3(p0, p1, p2)) > r) {
                // This means BOTH of the points of the projected triangle
                // are outside the projected half-length of the AABB
                return true;
            }
            return false;
        }
    };

    // Compute the edge vectors of the triangle  (ABC)
    // That is, get the lines between the points as vectors
    const f0 = v1 - v0;
    const f1 = v2 - v1;
    const f2 = v0 - v2;

    // We first test against 9 axis, these axis are given by
    // cross product combinations of the edges of the triangle
    // and the edges of the AABB.
    const axis_n0_f0 = zmath.normalize3(zmath.cross3(S.n0, f0));
    const axis_n0_f1 = zmath.normalize3(zmath.cross3(S.n0, f1));
    const axis_n0_f2 = zmath.normalize3(zmath.cross3(S.n0, f2));
    const axis_n1_f0 = zmath.normalize3(zmath.cross3(S.n1, f0));
    const axis_n1_f1 = zmath.normalize3(zmath.cross3(S.n1, f1));
    const axis_n1_f2 = zmath.normalize3(zmath.cross3(S.n1, f2));
    const axis_n2_f0 = zmath.normalize3(zmath.cross3(S.n2, f0));
    const axis_n2_f1 = zmath.normalize3(zmath.cross3(S.n2, f1));
    const axis_n2_f2 = zmath.normalize3(zmath.cross3(S.n2, f2));

    // Testing axises
    if (S.checkAxis(axis_n0_f0, v0, v1, v2)) return true;
    if (S.checkAxis(axis_n0_f1, v0, v1, v2)) return true;
    if (S.checkAxis(axis_n0_f2, v0, v1, v2)) return true;
    if (S.checkAxis(axis_n1_f0, v0, v1, v2)) return true;
    if (S.checkAxis(axis_n1_f1, v0, v1, v2)) return true;
    if (S.checkAxis(axis_n1_f2, v0, v1, v2)) return true;
    if (S.checkAxis(axis_n2_f0, v0, v1, v2)) return true;
    if (S.checkAxis(axis_n2_f1, v0, v1, v2)) return true;
    if (S.checkAxis(axis_n2_f2, v0, v1, v2)) return true;

    // Next, we have 3 face normals from the AABB
    // for these tests we are conceptually checking if the bounding box
    // of the triangle intersects the bounding box of the AABB
    if (S.checkAxis(S.n0, v0, v1, v2)) return true;
    if (S.checkAxis(S.n1, v0, v1, v2)) return true;
    if (S.checkAxis(S.n2, v0, v1, v2)) return true;

    // Finally, we have one last axis to test, the face normal of the triangle
    // We can get the normal of the triangle by crossing the first two line segments
    if (S.checkAxis(zmath.normalize3(zmath.cross3(f0, f1)), v0, v1, v2)) return true;

    return false;
}

/// Sort triangles by depth values
fn compareTriangleDepths(self: *Self, lhs: [3]u32, rhs: [3]u32) bool {
    const d1 = (self.depths.items[lhs[0]] + self.depths.items[lhs[1]] + self.depths.items[lhs[2]]) / 3.0;
    const d2 = (self.depths.items[rhs[0]] + self.depths.items[rhs[1]] + self.depths.items[rhs[2]]) / 3.0;
    return d1 > d2;
}

/// Draw the meshes, fill triangles, using texture if possible
pub fn draw(self: *Self, renderer: sdl.Renderer, tex: ?sdl.Texture) !void {
    if (!self.sorted) {
        // Sort triangles by depth, from farthest to closest
        const indices = @bitCast([][3]u32, self.indices.items)[0..@divTrunc(self.indices.items.len, 3)];
        std.sort.sort(
            [3]u32,
            indices,
            self,
            compareTriangleDepths,
        );
        self.sorted = true;
    }

    try renderer.drawGeometry(
        tex,
        self.vertices.items,
        self.indices.items,
    );
}

/// Draw the wireframe
pub fn drawWireframe(self: Self, renderer: sdl.Renderer) !void {
    var i: usize = 2;
    while (i < self.indices.items.len) : (i += 3) {
        try renderer.drawLineF(
            self.vertices.items[self.indices.items[i - 2]].position.x,
            self.vertices.items[self.indices.items[i - 2]].position.y,
            self.vertices.items[self.indices.items[i - 1]].position.x,
            self.vertices.items[self.indices.items[i - 1]].position.y,
        );
        try renderer.drawLineF(
            self.vertices.items[self.indices.items[i - 1]].position.x,
            self.vertices.items[self.indices.items[i - 1]].position.y,
            self.vertices.items[self.indices.items[i]].position.x,
            self.vertices.items[self.indices.items[i]].position.y,
        );
        try renderer.drawLineF(
            self.vertices.items[self.indices.items[i]].position.x,
            self.vertices.items[self.indices.items[i]].position.y,
            self.vertices.items[self.indices.items[i - 2]].position.x,
            self.vertices.items[self.indices.items[i - 2]].position.y,
        );
    }
}
