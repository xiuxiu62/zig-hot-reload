const std = @import("std");
const FileWatcher = @import("watcher.zig");
const Library = @import("dyn_lib.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const reload_flag = std.atomic.Value(bool).init(false);
    const halt_flag = std.atomic.Value(bool).init(false);

    const watcher_thread = try std.Thread.spawn(.{ .allocator = allocator }, FileWatcher.watch, .{ &reload_flag, &halt_flag });

    const lib = try Library.init(&reload_flag);
    defer lib.deinit();
    const lib_thread = try std.Thread.spawn(
        .{ .allocator = allocator },
        Library.run,
        .{ &lib, &reload_flag }, // here we pass the reload flag since a reload is a halt to the run procedure
    );

    while (!halt_flag.load(.release)) {
        // TODO: wait on condition variable
        std.time.sleep(std.time.ns_per_s);
    }

    watcher_thread.join();
    lib_thread.join();
}
