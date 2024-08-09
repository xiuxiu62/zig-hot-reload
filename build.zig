const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const build_options = b.addOptions();

    const lib = b.addSharedLibrary(.{
        .name = "example-lib",
        .root_source_file = b.path("src/lib/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    // var lib_step = b.step("lib-only", "Build only the shared library");

    const lib_only: bool = if (b.args) |args|
        args.len > 0 and std.mem.eql(u8, args[0], "lib-only")
    else
        false;

    if (lib_only) {
        b.installArtifact(lib);
    } else {
        var exe = b.addExecutable(.{
            .name = "zig-hot-reload",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        build_options.addOption([]const u8, "lib_path", b.getInstallPath(.lib, lib.out_filename));
        exe.root_module.addImport("build_options", build_options.createModule());

        b.installArtifact(lib);
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        // run_cmd.addArgs(b.args);

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}
