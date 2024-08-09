pub const FileEvent = struct {
    path: []const u8,
    kind: enum {
        Created,
        Modified,
        Deleted,
    },
};

root_path: []const u8,
