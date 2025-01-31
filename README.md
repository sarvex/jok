# jok
A minimal 2d/3d game framework for zig.

## What you need?
* Latest zig compiler (download in [here](https://ziglang.org/download/))
* SDL library (download in [here](https://libsdl.org/), or use your beloved package manager)
* Any code editor you like

## Features
* Pure-software rendering support
* 2D sprite rendering
* 2D sprite sheet generation/save/load
* 2D animation system
* 2D particle system
* 2D vector graphics
* 2D scene management
* 3D skybox rendering
* 3D mesh rendering
* 3D model loading/rendering (glTF 2.0)
* 3D skeleton animation rendering/blending
* 3D lighting effect (Blinn-Phong model)
* 3D sprite rendering
* 3D particle system
* 3D scene management
* Friendly easing system
* Font loading/rendering (TrueType)
* Sound/Music playing/mixing
* Fully integrated Dear-ImGui

## How to start?
Copy or clone repo (recursively) to `libs` subdirectory of the root of your project.
Install SDL2 library, please refer to [docs of SDL2.zig](https://github.com/MasterQ32/SDL.zig).
Then in your `build.zig` add:

```zig
const std = @import("std");
const jok = @import("libs/jok/build.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOptions(.{});
    const exe = jok.createGame(
        b, 
        "mygame",
        "src/main.zig",
        target,
        optimize,
        .{},
    );
    exe.install();

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run game");
    run_step.dependOn(&run_cmd.step);
}
```

Now in your code you may import and use jok:

```zig
const std = @import("std");
const jok = @import("jok");
const sdl = jok.sdl;
const j2d = jok.j2d;
const j3d = jok.j3d;

pub fn init(ctx: jok.Context) !void {
    // your init code
}

pub fn event(ctx: jok.Context, e: sdl.Event) !void {
    // your event processing code
}

pub fn update(ctx: jok.Context) !void {
    // your game state updating code
}

pub fn draw(ctx: jok.Context) !void {
  // your 2d drawing
  {
      try j2d.begin(.{});
      // ......
      try j2d.end();
  }

  // your 3d drawing
  {
      try j3d.begin(.{});
      // ......
      try j3d.end();
  }
}

pub fn quit(ctx: jok.Context) void {
    // your deinit code
}
```

Noticed yet? That's right, you don't need to write main function, `jok` got your back.
The game is deemed as a separate package to `jok`'s runtime as a matter of fact. 
Your responsibility is to provide 5 pub functions: `init/event/update/draw/quit`, that's all (pretty much).

Of course, you can customize some setup settings, such as width/height/title/position of window,
by defining some public constants using predefined names (they're all prefixed with `jok_`).
Checkout [`src/config.zig`](https://github.com/Jack-Ji/jok/blob/main/src/config.zig) to see available options.

## What's supported platforms?
Theoretically anywhere SDL2 can run. But I'm focusing on PC platforms for now.

TIPS: To eliminate console terminal on Windows platform, override `exe.subsystem` with `.Windows` in your build script.

## Watch out!
It's way too minimal (perhaps), you can't write shaders (It doesn't mean performance is bad! Checkout
benchmark example `sprite_benchmark/benchmark_3d`. [And the situation might change in the future.](https://gist.github.com/icculus/f731224bef3906e4c5e8cbed6f98bb08)).
If you want to achieve something fancy, you should resort to some clever art tricks or algorithms.
Welcome to old golden time of 90s! Or, you can choose other more powerful/modern libraries/engines.
It's also very **WIP**, please do expect some breaking changes in the future.

## Third-Party Libraries
* [SDL2](https://www.libsdl.org) (zlib license)
* [zig-gamedev](https://github.com/michal-z/zig-gamedev) (MIT license)
* [stb headers](https://github.com/nothings/stb) (MIT license)
* [nativefiledialog](https://github.com/mlabbe/nativefiledialog) (zlib license)

## Built-in Fonts
* [Classic Console Neue](http://webdraft.hu/fonts/classic-console/) (MIT license)

