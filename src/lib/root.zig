const std = @import("std");

export fn run(halt_flag: *std.atomic.Value(bool)) void {
    while (!halt_flag.load(.acquire)) {
        std.debug.print("lib event loop tick", .{});
        std.time.sleep(std.time.ns_per_s);
    }
}
