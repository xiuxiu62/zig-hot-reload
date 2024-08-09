const std = @import("std");
const build_options = @import("build_options");

handle: std.DynLib,
run_fn: *const fn (halt_flag: *std.atomic.Value(bool)) void = undefined,
reload_flag: *std.atomic.Value(bool),

const Self = @This();

pub fn init(reload_flag: *std.atomic.Value(bool)) !Self {
    var self: Self = .{
        .handle = try std.DynLib.open(build_options.lib_path),
        .reload_flag = reload_flag,
    };
    errdefer self.deinit();

    try self.load_run_fn();
    return self;
}

pub fn deinit(self: *Self) void {
    self.handle.close();
}

pub fn run(self: *Self, halt_flag: *std.atomic.Value(bool)) void {
    self.run_fn(halt_flag);
}

pub fn recompile(self: *Self) !void {
    const comp_proc = std.process.Child.init(.{
        "zig",
        "build",
        "-Dhot-reload=true",
        "lib-only",
    }, self.allocator);
    comp_proc.stdout_behavior = .Inherit;
    comp_proc.stderr_behavior = .Inherit;

    const term = comp_proc.spawnAndWait() orelse return;
    if (term.Exited == 0) {
        self.handle.close();
        self.handle = try std.DynLib.open(build_options.game_lib_path);
        self.load_run_function();
        self.reload_flag.store(false, .acquire);
    }
}

fn load_run_fn(self: *Self) !void {
    const RunFn = fn (halt_flag: *std.atomic.Value(bool)) void;
    self.run_fn = self.handle.lookup(*const RunFn, "run") orelse return error.FunctionNotFound;
}
