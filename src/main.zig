const std = @import("std");
const FileWatcher = @import("watcher.zig");
const Library = @import("dyn_lib.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var reload_flag = std.atomic.Value(bool).init(false);
    var halt_flag = std.atomic.Value(bool).init(false);

    var lib = try Library.init(&reload_flag);
    defer lib.deinit();

    var watcher = try FileWatcher.init(allocator, "./src/lib");
    defer watcher.deinit();

    // here we pass the reload flag since a reload is a halt to the run procedure
    var lib_thread = try std.Thread.spawn(.{ .allocator = allocator }, Library.run, .{ &lib, &reload_flag });
    const watcher_thread = try std.Thread.spawn(.{ .allocator = allocator }, FileWatcher.watch, .{ &watcher, &reload_flag, &halt_flag });
    defer {
        watcher_thread.join();
        lib_thread.join();
    }

    while (!halt_flag.load(.acquire)) {
        if (reload_flag.load(.acquire)) {
            lib_thread.join();
            try lib.recompile(allocator);
            lib_thread = try std.Thread.spawn(.{ .allocator = allocator }, Library.run, .{ &lib, &reload_flag });
        }

        // TODO: wait on condition variable
        std.time.sleep(std.time.ns_per_s);
    }
}
