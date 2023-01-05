const jok = @import("../../jok.zig");
const zgui = @import("zgui/src/main.zig");
const sdl = @import("sdl");
const imgui = @import("imgui.zig");

pub fn init(ctx: jok.Context) void {
    zgui.init(ctx.allocator);

    if (!ImGui_ImplSDL2_InitForSDLRenderer(ctx.window.ptr, ctx.renderer.ptr)) {
        unreachable;
    }

    if (!ImGui_ImplSDLRenderer_Init(ctx.renderer.ptr)) {
        unreachable;
    }

    zgui.getStyle().scaleAllSizes(ctx.getPixelRatio());

    const font = zgui.io.addFontFromMemory(jok.font.clacon_font_data, 16);
    zgui.io.setDefaultFont(font);

    zgui.plot.init();

    // NOTE: workaround for initializing imgui's internal state
    newFrame(ctx);
    defer draw();
}

pub fn deinit() void {
    zgui.plot.deinit();
    ImGui_ImplSDLRenderer_Shutdown();
    ImGui_ImplSDL2_Shutdown();
    zgui.deinit();
}

pub fn newFrame(ctx: jok.Context) void {
    ImGui_ImplSDLRenderer_NewFrame();
    ImGui_ImplSDL2_NewFrame();

    const fb_size = ctx.getFramebufferSize();
    imgui.io.setDisplaySize(@intToFloat(f32, fb_size.w), @intToFloat(f32, fb_size.h));
    imgui.io.setDisplayFramebufferScale(1.0, 1.0);

    imgui.newFrame();
}

pub fn draw() void {
    imgui.render();
    ImGui_ImplSDLRenderer_RenderDrawData(imgui.getDrawData());
}

pub fn processEvent(event: sdl.c.SDL_Event) bool {
    return ImGui_ImplSDL2_ProcessEvent(&event);
}

// Those functions are defined in `imgui_impl_sdl.cpp` and 'imgui_impl_sdlrenderer.cpp`
extern fn ImGui_ImplSDL2_InitForSDLRenderer(window: *const anyopaque, renderer: *const anyopaque) bool;
extern fn ImGui_ImplSDL2_NewFrame() void;
extern fn ImGui_ImplSDL2_Shutdown() void;
extern fn ImGui_ImplSDL2_ProcessEvent(event: *const anyopaque) bool;
extern fn ImGui_ImplSDLRenderer_Init(renderer: *const anyopaque) bool;
extern fn ImGui_ImplSDLRenderer_NewFrame() void;
extern fn ImGui_ImplSDLRenderer_RenderDrawData(draw_data: *const anyopaque) void;
extern fn ImGui_ImplSDLRenderer_Shutdown() void;
