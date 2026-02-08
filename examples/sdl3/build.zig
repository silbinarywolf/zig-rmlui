const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const app = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const library_optimize = optimize;

    // add sdl
    const sdl_include_path = depblk: {
        const sdl_dep = b.dependency("sdl", .{
            .optimize = library_optimize,
            .target = target,
        });
        const sdl_include_path = sdl_dep.path("include"); // Contains <SDL3/SDL.h> folder
        const sdl_lib = sdl_dep.artifact("SDL3");
        app.linkLibrary(sdl_lib);

        const sdl_module = blk: {
            var c_translate = b.addTranslateC(.{
                .target = target,
                .optimize = optimize,
                .root_source_file = b.path("src/zig-sdl.h"),
            });
            c_translate.addIncludePath(sdl_include_path);
            break :blk c_translate.createModule();
        };
        app.addImport("sdl", sdl_module);

        break :depblk sdl_include_path;
    };

    // add freetype
    const freetype_include_path = depblk: {
        var freetype_dep = b.dependency("freetype", .{
            .target = target,
            .optimize = library_optimize,
        });
        app.linkLibrary(freetype_dep.artifact("freetype"));
        break :depblk freetype_dep.namedLazyPath("include_path");
    };

    // add rmlui
    {
        var rmlui_dep = b.dependency("rmlui", .{
            .target = target,
            .optimize = library_optimize,
            // Add directory containing "ft2build.h" so we can compile with Freetype support
            .freetype_include_path = freetype_include_path,
            // Add directory containing "SDL3/SDL.h" so we can compile the platform/rendering backends
            .sdl_include_path = sdl_include_path,
        });
        app.addImport("rml", rmlui_dep.module("rml"));
        app.addImport("rmldebug", rmlui_dep.module("rmldebug"));
        app.addImport("rmlsdl", rmlui_dep.module("rmlsdl"));
    }

    const exe = b.addExecutable(.{
        .name = "rmlui_sdl3_example",
        .root_module = app,
    });

    const run_step = b.step("run", "Run the application");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    const installed_exe = b.addInstallArtifact(exe, .{});
    b.getInstallStep().dependOn(&installed_exe.step);
}
