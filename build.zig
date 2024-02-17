const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
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
    exe.addCSourceFiles(.{
        .files = &[_][]const u8{
            "imgui/imgui.cpp",
            "imgui/imgui_demo.cpp",
            "imgui/imgui_draw.cpp",
            "imgui/imgui_tables.cpp",
            "imgui/imgui_widgets.cpp",
            "dear_bindings/cimgui.cpp",
        },
        .flags = &[_][]const u8{},
    });
    if (exe.rootModuleTarget().os.tag == .windows) {
        exe.linkSystemLibrary("User32");
        exe.linkSystemLibrary("Gdi32");
        exe.linkSystemLibrary("OpenGL32");
        exe.linkSystemLibrary("Dwmapi");
        exe.addCSourceFiles(.{
            .files = &[_][]const u8{
                "src/gui_windows.cpp",
                "imgui/backends/imgui_impl_opengl3.cpp",
                "imgui/backends/imgui_impl_win32.cpp",
            },
            .flags = &[_][]const u8{},
        });
    } else if (exe.rootModuleTarget().os.tag.isDarwin()) {
        exe.addCSourceFiles(.{
            .files = &[_][]const u8{
                "src/gui_macos.mm",
                "imgui/backends/imgui_impl_osx.mm",
                "imgui/backends/imgui_impl_metal.mm",
            },
            .flags = &[_][]const u8{"-ObjC++"},
        });
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

    step: std.Build.Step,
    builder: *std.Build,
    artifact: *std.Build.Step.Compile,

    pub fn create(builder: *std.Build, artifact: *std.Build.Step.Compile) *Self {
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
        if (self.artifact.rootModuleTarget().os.tag == .windows) {
            var dir = try std.fs.openDirAbsolute(self.builder.build_root.path.?, .{});
            _ = try dir.updateFile("zig-out/lib/clap-imgui.dll", dir, "zig-out/lib/clap-imgui.dll.clap", .{});
        } else if (self.artifact.rootModuleTarget().os.tag.isDarwin()) {
            var dir = try std.fs.openDirAbsolute(self.builder.build_root.path.?, .{});
            _ = try dir.updateFile("zig-out/lib/libclap-imgui.dylib", dir, "zig-out/lib/Clap Imgui.clap/Contents/MacOS/Clap Imgui", .{});
            _ = try dir.updateFile("macos/info.plist", dir, "zig-out/lib/Clap Imgui.clap/Contents/info.plist", .{});
            _ = try dir.updateFile("macos/PkgInfo", dir, "zig-out/lib/Clap Imgui.clap/Contents/PkgInfo", .{});
        }
    }
};
