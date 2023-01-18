const std = @import("std");
const sdl = @import("sdl");
const jok = @import("jok");
const imgui = jok.imgui;
const font = jok.font;
const zmesh = jok.zmesh;
const j3d = jok.j3d;
const primitive = j3d.primitive;

var camera: j3d.Camera = undefined;
var cube: zmesh.Shape = undefined;
var tex: sdl.Texture = undefined;
var texcoords = [_][2]f32{
    .{ 0, 1 },
    .{ 0, 0 },
    .{ 1, 0 },
    .{ 1, 1 },
    .{ 1, 1 },
    .{ 0, 1 },
    .{ 0, 0 },
    .{ 1, 0 },
};
var skybox_textures: [6]sdl.Texture = undefined;
var skybox_rd: *j3d.SkyboxRenderer = undefined;
var skybox_tint_color: sdl.Color = sdl.Color.white;

pub fn init(ctx: *jok.Context) !void {
    std.log.info("game init", .{});

    camera = j3d.Camera.fromPositionAndTarget(
        .{
            //.orthographic = .{
            //    .width = 2 * ctx.getAspectRatio(),
            //    .height = 2,
            //    .near = 0.1,
            //    .far = 100,
            //},
            .perspective = .{
                .fov = std.math.pi / 4.0,
                .aspect_ratio = ctx.getAspectRatio(),
                .near = 0.1,
                .far = 100,
            },
        },
        [_]f32{ 0, 1, -2 },
        [_]f32{ 0, 0, 0 },
        null,
    );
    cube = zmesh.Shape.initCube();
    cube.computeNormals();
    cube.texcoords = texcoords[0..];
    tex = try jok.utils.gfx.createTextureFromFile(
        ctx.renderer,
        "assets/images/image5.jpg",
        .static,
        false,
    );

    skybox_textures[0] = try jok.utils.gfx.createTextureFromFile(
        ctx.renderer,
        "assets/images/skybox/right.jpg",
        .static,
        true,
    );
    skybox_textures[1] = try jok.utils.gfx.createTextureFromFile(
        ctx.renderer,
        "assets/images/skybox/left.jpg",
        .static,
        true,
    );
    skybox_textures[2] = try jok.utils.gfx.createTextureFromFile(
        ctx.renderer,
        "assets/images/skybox/top.jpg",
        .static,
        true,
    );
    skybox_textures[3] = try jok.utils.gfx.createTextureFromFile(
        ctx.renderer,
        "assets/images/skybox/bottom.jpg",
        .static,
        true,
    );
    skybox_textures[4] = try jok.utils.gfx.createTextureFromFile(
        ctx.renderer,
        "assets/images/skybox/front.jpg",
        .static,
        true,
    );
    skybox_textures[5] = try jok.utils.gfx.createTextureFromFile(
        ctx.renderer,
        "assets/images/skybox/back.jpg",
        .static,
        true,
    );
    skybox_rd = try j3d.SkyboxRenderer.create(ctx.allocator, .{});

    try ctx.renderer.setColorRGB(77, 77, 77);
}

pub fn event(ctx: *jok.Context, e: sdl.Event) !void {
    _ = ctx;
    _ = e;
}

pub fn update(ctx: *jok.Context) !void {
    // camera movement
    const distance = ctx.delta_tick * 2;
    if (ctx.isKeyPressed(.w)) {
        camera.move(.forward, distance);
    }
    if (ctx.isKeyPressed(.s)) {
        camera.move(.backward, distance);
    }
    if (ctx.isKeyPressed(.a)) {
        camera.move(.left, distance);
    }
    if (ctx.isKeyPressed(.d)) {
        camera.move(.right, distance);
    }
    if (ctx.isKeyPressed(.left)) {
        camera.rotate(0, -std.math.pi / 180.0);
    }
    if (ctx.isKeyPressed(.right)) {
        camera.rotate(0, std.math.pi / 180.0);
    }
    if (ctx.isKeyPressed(.up)) {
        camera.rotate(std.math.pi / 180.0, 0);
    }
    if (ctx.isKeyPressed(.down)) {
        camera.rotate(-std.math.pi / 180.0, 0);
    }
}

pub fn draw(ctx: *jok.Context) !void {
    try skybox_rd.draw(ctx.renderer, camera, skybox_textures, skybox_tint_color);

    primitive.clear(.{});
    try primitive.addShape(
        cube,
        j3d.zmath.mul(
            j3d.zmath.translation(-0.5, -0.5, -0.5),
            j3d.zmath.mul(
                j3d.zmath.scaling(0.5, 0.5, 0.5),
                j3d.zmath.rotationY(@floatCast(f32, ctx.tick) * std.math.pi),
            ),
        ),
        camera,
        null,
        .{ .texture = tex },
    );
    try primitive.draw();

    primitive.clear(.{});
    try primitive.addShape(
        cube,
        j3d.zmath.mul(
            j3d.zmath.translation(-0.5, -0.5, -0.5),
            j3d.zmath.rotationY(@floatCast(f32, ctx.tick) * std.math.pi / 3.0),
        ),
        camera,
        null,
        .{},
    );
    try primitive.drawWireframe(sdl.Color.green);

    _ = try font.debugDraw(
        ctx.renderer,
        .{ .pos = .{ .x = 200, .y = 10 } },
        "Press WSAD and up/down/left/right to move camera around the view",
        .{},
    );
    _ = try font.debugDraw(
        ctx.renderer,
        .{ .pos = .{ .x = 200, .y = 28 } },
        "Camera: pos({d:.3},{d:.3},{d:.3}) dir({d:.3},{d:.3},{d:.3})",
        .{
            // zig fmt: off
            camera.position[0],camera.position[1],camera.position[2],
            camera.dir[0],camera.dir[1],camera.dir[2],
        },
    );

    imgui.sdl.newFrame(ctx.*);
    defer imgui.sdl.draw();
    if (imgui.begin("Tint Color", .{})) {
        var cs: [3]f32 = .{
            @intToFloat(f32, skybox_tint_color.r) / 255, 
            @intToFloat(f32, skybox_tint_color.g) / 255, 
            @intToFloat(f32, skybox_tint_color.b) / 255, 
        };
        if (imgui.colorEdit3("Tint Color", .{.col=&cs})) {
            skybox_tint_color.r = @floatToInt(u8, cs[0] * 255);
            skybox_tint_color.g = @floatToInt(u8, cs[1] * 255);
            skybox_tint_color.b = @floatToInt(u8, cs[2] * 255);
        }
    }
    imgui.end();
}

pub fn quit(ctx: *jok.Context) void {
    _ = ctx;
    std.log.info("game quit", .{});

    cube.deinit();
    skybox_rd.destroy();
}
