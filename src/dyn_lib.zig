const std = @import("std");
const options = @import("options");

handle: std.DynLib,
run_fn: *const fn (halt_flag: *std.atomic.Value(bool)) void = undefined,
reload_flag: *std.atomic.Value(bool),

const Self = @This();

pub fn init(reload_flag: *std.atomic.Value(bool)) !Self {
    var self: Self = .{
        .handle = try std.DynLib.open(options.lib_path),
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

pub fn recompile(self: *Self, allocator: std.mem.Allocator) !void {
    std.debug.print("Recompiling\n", .{});

    var comp_proc = std.process.Child.init(&.{ "zig", "build", "lib-only" }, allocator);
    comp_proc.stdout_behavior = .Inherit;
    comp_proc.stderr_behavior = .Inherit;

    std.debug.print("1\n", .{});

    const term = try comp_proc.spawnAndWait();
    std.debug.print("2\n", .{});
    if (term.Exited == 0) {
        std.debug.print("3\n", .{});
        self.handle.close();
        std.debug.print("4\n", .{});
        self.handle = try std.DynLib.open(options.lib_path);
        std.debug.print("5\n", .{});
        try self.load_run_fn();
        std.debug.print("6\n", .{});
        self.reload_flag.store(false, .release);
        std.debug.print("7\n", .{});
    }
}

fn load_run_fn(self: *Self) !void {
    const RunFn = fn (halt_flag: *std.atomic.Value(bool)) void;
    self.run_fn = self.handle.lookup(*const RunFn, "run") orelse return error.FunctionNotFound;
}
