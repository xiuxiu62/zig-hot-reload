const builtin = @import("builtin");
const std = @import("std");

const Library = @import("dyn_lib.zig");

root_path: []const u8,
files: std.StringHashMap(i128),
dir_stack: std.ArrayList([]const u8),
allocator: std.mem.Allocator,

const Self = @This();

pub fn init(allocator: std.mem.Allocator, path: []const u8) !Self {
    return .{
        .root_path = try allocator.dupe(u8, path),
        .files = std.StringHashMap(i128).init(allocator),
        .dir_stack = std.ArrayList([]const u8).init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    // NOTE: not sure if freeing entries is necessary
    var it = self.files.keyIterator();
    while (it.next()) |key|
        self.allocator.free(key.*);

    self.files.deinit();
    self.dir_stack.deinit();
    self.allocator.free(self.root_path);
}

pub fn watch(
    self: *Self,
    reload_flag: *std.atomic.Value(bool),
    halt_flag: *std.atomic.Value(bool),
) !void {
    while (!halt_flag.load(.acquire)) {
        const absolute_root_path = try std.fs.realpathAlloc(self.allocator, self.root_path);
        try self.dir_stack.append(absolute_root_path);

        check: while (self.dir_stack.items.len > 0) {
            const current_dir = self.dir_stack.pop();
            var dir = try std.fs.openDirAbsolute(current_dir, .{ .iterate = true });
            defer dir.close();
            defer self.allocator.free(current_dir);

            var it = dir.iterate();
            while (try it.next()) |entry| {
                const full_path = try std.fs.path.join(self.allocator, &.{ current_dir, entry.name });
                defer self.allocator.free(full_path);

                switch (entry.kind) {
                    .file => {
                        const stat = try dir.statFile(entry.name);
                        const last_modified = stat.mtime;

                        const previous_modified = try self.files.getOrPut(full_path);
                        if (!previous_modified.found_existing) {
                            const key = try self.allocator.dupe(u8, full_path);
                            previous_modified.key_ptr.* = key;
                        } else if (last_modified != previous_modified.value_ptr.*) {
                            // previous_modified.value_ptr.* = last_modified;

                            reload_flag.store(true, .release);
                            break :check;
                            // has_changed = true;
                        }

                        previous_modified.value_ptr.* = last_modified;
                    },
                    .directory => {
                        const key = try self.allocator.dupe(u8, full_path);
                        // const full_current_path = try std.fs.realpathAlloc(self.allocator, full_path);
                        try self.dir_stack.append(key);
                    },
                    else => {},
                }
            }
        }

        for (self.dir_stack.items) |item| self.allocator.free(item);
        self.dir_stack.clearRetainingCapacity();

        std.time.sleep(std.time.ns_per_s * 0.5);
    }
}
