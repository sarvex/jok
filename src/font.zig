const std = @import("std");
const assert = std.debug.assert;
const sdl = @import("sdl");
const jok = @import("jok.zig");
const gfx = jok.gfx;

/// Wrapper of truetype font
pub const Font = @import("font/Font.zig");

/// Font-atlas for generating vertex data
pub const Atlas = @import("font/Atlas.zig");

/// Regularly used codepoints
pub const codepoint_ranges = @import("font/codepoint_ranges.zig");

/// Embedded font data
pub const clacon_font_data = @embedFile("font/clacon2.ttf");

/// Draw debug text using builtin font
pub const DrawOption = struct {
    pos: sdl.PointF,
    ypos_type: Atlas.YPosType = .top,
    box_type: Atlas.BoxType = .aligned,
    color: sdl.Color = sdl.Color.white,
    font_size: u32 = 16,
};
pub const DrawResult = struct {
    area: sdl.RectangleF,
    next_line_ypos: f32,
};
pub fn debugDraw(ctx: *const jok.Context, opt: DrawOption, comptime fmt: []const u8, args: anytype) !DrawResult {
    const S = struct {
        const max_text_size = 1000;
        var font: ?*Font = null;
        var atlases: std.AutoHashMap(u32, *Atlas) = undefined;
        var vattrib: std.ArrayList(sdl.Vertex) = undefined;
        var vindices: std.ArrayList(u32) = undefined;
        var text_buf: [1024]u8 = undefined;
    };

    var text = try std.fmt.bufPrint(&S.text_buf, fmt, args);
    if (text.len == 0) return DrawResult{
        .area = .{ .x = opt.pos.x, .y = opt.pos.y, .width = 0, .height = 0 },
        .next_line_ypos = 0,
    };

    // Initialize font data and atlases as needed
    if (S.font == null) {
        S.font = Font.fromTrueTypeData(ctx.allocator, clacon_font_data) catch unreachable;
        S.atlases = std.AutoHashMap(u32, *Atlas).init(ctx.allocator);
        S.vattrib = std.ArrayList(sdl.Vertex).initCapacity(ctx.allocator, S.max_text_size * 4) catch unreachable;
        S.vindices = std.ArrayList(u32).initCapacity(ctx.allocator, S.max_text_size * 6) catch unreachable;
    }
    var atlas = S.atlases.get(opt.font_size) orelse BLK: {
        var a = S.font.?.createAtlas(
            ctx.renderer,
            opt.font_size,
            &[_][2]u32{.{ 0x0020, 0x00FF }},
            1024,
        ) catch unreachable;
        try S.atlases.put(opt.font_size, a);
        break :BLK a;
    };

    defer S.vattrib.clearRetainingCapacity();
    defer S.vindices.clearRetainingCapacity();

    assert(text.len < S.max_text_size);
    const area = try atlas.appendDrawDataFromUTF8String(
        text,
        opt.pos,
        opt.ypos_type,
        opt.box_type,
        opt.color,
        &S.vattrib,
        &S.vindices,
    );
    try ctx.renderer.drawGeometry(atlas.tex, S.vattrib.items, S.vindices.items);
    return DrawResult{
        .area = area,
        .next_line_ypos = atlas.getVPosOfNextLine(opt.pos.y),
    };
}
