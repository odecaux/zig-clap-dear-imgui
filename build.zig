const std = @import("std");
const Step = std.build.Step;
const Builder = std.build.Builder;

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addSharedLibrary(.{
        .name = "clap-imgui",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/main.zig" },
    });
    exe.linkLibC();
    exe.linkLibCpp();
    exe.addIncludePath(.{ .cwd_relative = "clap/include" });
    exe.addIncludePath(.{ .cwd_relative = "src" });
    exe.addIncludePath(.{ .cwd_relative = "dear_bindings" });
    exe.addIncludePath(.{ .cwd_relative = "imgui/backends" });
    exe.addIncludePath(.{ .cwd_relative = "imgui" });
    exe.addCSourceFiles(&[_][]const u8{
        "imgui/imgui.cpp",
        "imgui/imgui_demo.cpp",
        "imgui/imgui_draw.cpp",
        "imgui/imgui_tables.cpp",
        "imgui/imgui_widgets.cpp",
        "dear_bindings/cimgui.cpp",
    }, &[_][]const u8{});
    if (exe.target.isWindows()) {
        exe.linkSystemLibrary("User32");
        exe.linkSystemLibrary("Gdi32");
        exe.linkSystemLibrary("OpenGL32");
        exe.linkSystemLibrary("Dwmapi");
        exe.addCSourceFiles(&[_][]const u8{
            "src/gui_windows.cpp",
            "imgui/backends/imgui_impl_opengl3.cpp",
            "imgui/backends/imgui_impl_win32.cpp",
        }, &[_][]const u8{});
    } else if (exe.target.isDarwin()) {
        exe.addCSourceFiles(&[_][]const u8{
            "src/gui_macos.mm",
            "imgui/backends/imgui_impl_osx.mm",
            "imgui/backends/imgui_impl_metal.mm",
        }, &[_][]const u8{"-ObjC++"});
        exe.linkFramework("Cocoa");
        exe.linkFramework("Metal");
        exe.linkFramework("MetalKit");
        exe.linkFramework("GameController");
    }

    const rename_dll_step = CreateClapPluginStep.create(b, exe);
    b.getInstallStep().dependOn(&rename_dll_step.step);
}

pub const CreateClapPluginStep = struct {
    pub const base_id = .top_level;

    const Self = @This();

    step: Step,
    builder: *Builder,
    artifact: *std.build.LibExeObjStep,

    pub fn create(builder: *Builder, artifact: *std.build.LibExeObjStep) *Self {
        const self = builder.allocator.create(Self) catch unreachable;
        const name = "create clap plugin";

        self.* = Self{
            .step = std.Build.Step.init(.{
                .id = .top_level,
                .name = name,
                .owner = builder,
                .makeFn = make,
            }),
            .builder = builder,
            .artifact = artifact,
        };

        const install = builder.addInstallArtifact(artifact, .{});
        self.step.dependOn(&install.step);
        return self;
    }

    fn make(step: *std.Build.Step, prog_node: *std.Progress.Node) !void {
        _ = prog_node;
        const self = @fieldParentPtr(Self, "step", step);
        if (self.artifact.target.isWindows()) {
            var dir = try std.fs.openDirAbsolute(self.builder.build_root.path.?, .{});
            _ = try dir.updateFile("zig-out/lib/clap-imgui.dll", dir, "zig-out/lib/clap-imgui.dll.clap", .{});
        } else if (self.artifact.target.isDarwin()) {
            var dir = try std.fs.openDirAbsolute(self.builder.build_root.path.?, .{});
            _ = try dir.updateFile("zig-out/lib/libclap-imgui.dylib", dir, "zig-out/lib/Clap Imgui.clap/Contents/MacOS/Clap Imgui", .{});
            _ = try dir.updateFile("macos/info.plist", dir, "zig-out/lib/Clap Imgui.clap/Contents/info.plist", .{});
            _ = try dir.updateFile("macos/PkgInfo", dir, "zig-out/lib/Clap Imgui.clap/Contents/PkgInfo", .{});
        }
    }
};
