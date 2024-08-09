const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "example-lib",
        .root_source_file = b.path("src/lib/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    // var lib_step = b.step("lib-only", "Build only the shared library");

    b.installArtifact(lib);

    const lib_install = b.addInstallArtifact(lib, .{});

    const lib_step = b.step("lib-only", "Build only the shared library");
    lib_step.dependOn(&lib_install.step);
    // lib_step.dependOn(&lib.step);

    const lib_install_path = b.getInstallPath(.bin, lib.out_filename);

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "lib_path", lib_install_path);

    const lib_only = b.option(bool, "lib-only", "Build only the shared library") orelse false;

    if (!lib_only) {
        const exe = b.addExecutable(.{
            .name = "example",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        exe.root_module.addImport("options", build_options.createModule());

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    b.getInstallStep().dependOn(&lib_install.step);

    // if (lib_only) {
    //     b.installArtifact(lib);
    // } else {
    //     var exe = b.addExecutable(.{
    //         .name = "example",
    //         .root_source_file = b.path("src/main.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     });

    //     build_options.addOption([]const u8, "lib_path", b.getInstallPath(.lib, lib.out_filename));
    //     exe.root_module.addImport("build_options", build_options.createModule());

    //     b.installArtifact(lib);
    //     b.installArtifact(exe);

    //     const run_cmd = b.addRunArtifact(exe);
    //     run_cmd.step.dependOn(b.getInstallStep());
    //     // run_cmd.addArgs(b.args);

    //     const run_step = b.step("run", "Run the app");
    //     run_step.dependOn(&run_cmd.step);
    // }

}
