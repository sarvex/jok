const std = @import("std");
const builtin = @import("builtin");
const Sdk = @import("src/deps/sdl/Sdk.zig");
const stb = @import("src/deps/stb/build.zig");
const imgui = @import("src/deps/imgui/build.zig");
const nfd = @import("src/deps/nfd/build.zig");
const zmath = @import("src/deps/zmath/build.zig");
const zmesh = @import("src/deps/zmesh/build.zig");
const znoise = @import("src/deps/znoise/build.zig");
const zpool = @import("src/deps/zpool/build.zig");
const zflecs = @import("src/deps/zflecs/build.zig");
const zaudio = @import("src/deps/zaudio/build.zig");
const zphysics = @import("src/deps/zphysics/build.zig");
const ztracy = @import("src/deps/ztracy/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const assets_install = b.addInstallDirectory(.{
        .source_dir = "examples/assets",
        .install_dir = .bin,
        .install_subdir = "assets",
    });
    const examples = [_]struct { name: []const u8, opt: BuildOptions }{
        .{ .name = "hello", .opt = .{} },
        .{ .name = "imgui_demo", .opt = .{} },
        .{ .name = "sprite_sheet", .opt = .{} },
        .{ .name = "sprite_scene", .opt = .{} },
        .{ .name = "sprite_benchmark", .opt = .{} },
        .{ .name = "particle_2d", .opt = .{} },
        .{ .name = "particle_3d", .opt = .{} },
        .{ .name = "animation_2d", .opt = .{} },
        .{ .name = "sprite_scene_3d", .opt = .{} },
        .{ .name = "meshes_and_lighting", .opt = .{} },
        .{ .name = "intersection_2d", .opt = .{} },
        .{ .name = "affine_texture", .opt = .{} },
        .{ .name = "solar_system", .opt = .{} },
        .{ .name = "font_demo", .opt = .{} },
        .{ .name = "skybox", .opt = .{} },
        .{ .name = "benchmark_3d", .opt = .{} },
        .{ .name = "particle_life", .opt = .{ .use_nfd = true } },
        .{ .name = "zaudio_demo", .opt = .{ .use_zaudio = true } },
        .{ .name = "audio_synthesize_demo", .opt = .{} },
        .{ .name = "hypocycloids", .opt = .{} },
        .{ .name = "spiraling_squares", .opt = .{} },
        .{ .name = "easing", .opt = .{} },
        .{ .name = "gltf", .opt = .{} },
        .{ .name = "generative_art", .opt = .{} },
    };
    const build_examples = b.step("examples", "compile and install all examples");
    inline for (examples) |demo| {
        const exe = createGame(
            b,
            demo.name,
            "examples/" ++ demo.name ++ ".zig",
            target,
            optimize,
            demo.opt,
        );
        const install_cmd = b.addInstallArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&install_cmd.step);
        run_cmd.step.dependOn(&assets_install.step);
        run_cmd.cwd = "zig-out/bin";
        const run_step = b.step(
            demo.name,
            "run example " ++ demo.name,
        );
        run_step.dependOn(&run_cmd.step);
        build_examples.dependOn(&install_cmd.step);
    }
}

pub const BuildOptions = struct {
    use_nfd: bool = false,
    use_zaudio: bool = false,
    use_zphysics: bool = false,
    enable_ztracy: bool = false,
};

/// Create game executable
pub fn createGame(
    b: *std.Build,
    name: []const u8,
    root_file: []const u8,
    target: std.zig.CrossTarget,
    optimize: std.builtin.Mode,
    opt: BuildOptions,
) *std.Build.CompileStep {
    // Initialize jok module
    const bos = b.addOptions();
    bos.addOption(bool, "use_nfd", opt.use_nfd);
    bos.addOption(bool, "use_zaudio", opt.use_zaudio);
    bos.addOption(bool, "use_zphysics", opt.use_zphysics);
    const sdl_sdk = Sdk.init(b, null);
    const zmath_pkg = zmath.package(b, target, optimize, .{});
    const zmesh_pkg = zmesh.package(b, target, optimize, .{});
    const znoise_pkg = znoise.package(b, target, optimize, .{});
    const zpool_pkg = zpool.package(b, target, optimize, .{});
    const zflecs_pkg = zflecs.package(b, target, optimize, .{});
    const zaudio_pkg = zaudio.package(b, target, optimize, .{});
    const zphysics_pkg = zphysics.package(b, target, optimize, .{});
    const ztracy_pkg = ztracy.package(b, target, optimize, .{
        .options = .{ .enable_ztracy = opt.enable_ztracy },
    });
    const jok = b.createModule(.{
        .source_file = .{ .path = thisDir() ++ "/src/jok.zig" },
        .dependencies = &.{
            .{ .name = "build_options", .module = bos.createModule() },
            .{ .name = "sdl", .module = sdl_sdk.getWrapperModule() },
            .{ .name = "zgui", .module = imgui.getZguiModule(b, target, optimize) },
            .{ .name = "zmath", .module = zmath_pkg.zmath },
            .{ .name = "zmesh", .module = zmesh_pkg.zmesh },
            .{ .name = "znoise", .module = znoise_pkg.znoise },
            .{ .name = "zflecs", .module = zflecs_pkg.zflecs },
            .{ .name = "zpool", .module = zpool_pkg.zpool },
            .{ .name = "zaudio", .module = zaudio_pkg.zaudio },
            .{ .name = "zphysics", .module = zphysics_pkg.zphysics },
            .{ .name = "ztracy", .module = ztracy_pkg.ztracy },
        },
    });

    // Initialize executable
    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = thisDir() ++ "/src/app.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("jok", jok);
    exe.addModule("game", b.createModule(.{
        .source_file = .{ .path = root_file },
        .dependencies = &.{
            .{ .name = "jok", .module = jok },
        },
    }));

    // Link libraries
    sdl_sdk.link(exe, .dynamic);
    stb.link(exe);
    imgui.link(b, exe);
    zmesh_pkg.link(exe);
    znoise_pkg.link(exe);
    zflecs_pkg.link(exe);
    ztracy_pkg.link(exe);
    if (opt.use_nfd) {
        nfd.link(exe);
    }
    if (opt.use_zaudio) {
        zaudio_pkg.link(exe);
    }
    if (opt.use_zphysics) {
        zphysics_pkg.link(exe);
    }

    return exe;
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
