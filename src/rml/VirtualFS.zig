//! VirtualFS tracks virtual file handles that are opened

const builtin = @import("builtin");
const log = @import("std").log.scoped(.VirtualFS);
const File = @import("std").fs.File;
const panic = @import("std").debug.panic;

items: [MaxFileHandles]Data,

const MaxFileHandles = 8;

pub const empty: VirtualFS = .{
    .items = [1]Data{.void} ** MaxFileHandles,
};

const ReadError = File.ReadError;
const SeekError = File.SeekError;

pub const Whence = enum(u8) {
    /// SEEK_START
    start = 0,
    /// SEEK_CURR
    current = 1,
    /// SEEK_END
    end = 2,
};

pub fn fromFile(self: *VirtualFS, file: File) error{ProcessFdQuotaExceeded}!Handle {
    return self.newHandle(.{
        .file = file,
    });
}

pub fn fromEmbedFile(self: *VirtualFS, path: [:0]const u8, data: [:0]const u8) error{ProcessFdQuotaExceeded}!Handle {
    return self.newHandle(.{
        .embed_file = .{
            .path = path,
            .data = data,
            .pos = 0,
        },
    });
}

pub fn read(self: *VirtualFS, handle: Handle, buf: []u8) ReadError!usize {
    const index = handle.index();
    switch (self.items[index]) {
        .void => unreachable,
        .embed_file => {
            var embed_file = &self.items[index].embed_file;
            const pos = embed_file.pos;

            // If at end of file
            if (pos >= embed_file.data.len) return 0;

            const remaining_data: []const u8 = if (pos + buf.len < embed_file.data.len)
                embed_file.data[pos .. pos + buf.len]
            else
                embed_file.data[pos..];

            const dest: []u8 = if (remaining_data.len < buf.len)
                buf[0..remaining_data.len]
            else
                buf;
            if (remaining_data.len > buf.len) {
                @memcpy(dest, remaining_data[0..buf.len]);
            } else {
                @memcpy(dest, remaining_data);
            }
            embed_file.pos += dest.len;
            return dest.len;
        },
        .file => {
            if (builtin.os.tag == .freestanding) unreachable;

            var file = &self.items[index].file;
            const len = file.read(buf) catch |err| {
                panic("error reading file: {s}", .{@errorName(err)});
            };
            return len;
        },
    }
}

pub fn seek(self: *VirtualFS, handle: Handle, offset: isize, whence: Whence) SeekError!void {
    const index = handle.index();
    switch (self.items[index]) {
        .void => unreachable,
        .embed_file => {
            var embed_file = &self.items[index].embed_file;
            const pos: usize = blk: switch (whence) {
                .start => {
                    if (offset < 0) return error.Unseekable;
                    break :blk @intCast(offset);
                },
                .current => embed_file.pos + @as(usize, @intCast(offset)),
                .end => embed_file.data.len - @as(usize, @intCast(offset)),
            };
            if (pos < 0 or pos > embed_file.data.len) {
                // log.debug("seek({}): failed, position too low or high: {} out of {}", .{ handle, pos, embed_file.data.len });
                return error.Unseekable;
            }
            embed_file.pos = @intCast(pos);
            // log.debug("seek({}): pos={}", .{ handle, embed_file.pos });
            return;
        },
        .file => {
            if (builtin.os.tag == .freestanding) unreachable;

            var file = &self.items[index].file;
            switch (whence) {
                .start => try file.seekTo(@intCast(offset)),
                .current => try file.seekBy(@intCast(offset)),
                .end => try file.seekFromEnd(@intCast(offset)),
            }
            return;
        },
    }
}

pub fn tell(self: *const VirtualFS, handle: Handle) usize {
    const index = handle.index();
    switch (self.items[index]) {
        .void => unreachable,
        .embed_file => |embed_file| {
            // log.info("tell({}): pos={}", .{ handle, embed_file.pos });
            return embed_file.pos;
        },
        .file => |file| {
            if (builtin.os.tag == .freestanding) unreachable;
            return file.getPos() catch |err| {
                panic("failed to get pos: {s}", .{@errorName(err)});
            };
        },
    }
}

pub fn close(self: *VirtualFS, handle: Handle) void {
    const index = handle.index();
    switch (self.items[index]) {
        .void => unreachable,
        .embed_file => {
            self.items[index] = .void;
        },
        .file => {
            if (builtin.os.tag == .freestanding) unreachable;

            self.items[index].file.close();
            self.items[index] = .void;
        },
    }
}

fn newHandle(self: *VirtualFS, data: Data) error{ProcessFdQuotaExceeded}!Handle {
    for (0..self.items.len) |index| {
        switch (self.items[index]) {
            .void => |_| {
                self.items[index] = data;
                return @enumFromInt(index + Handle.Offset);
            },
            else => {},
        }
    }
    return error.ProcessFdQuotaExceeded;
}

fn destroyHandle(self: *VirtualFS, handle: Handle) void {
    self.items[@intFromEnum(handle) - Handle.Offset] = .{.void};
}

/// Handle is a handle to a file starting from 100
const Handle = enum(u16) {
    none = 0,
    _,

    /// Offset means the file handles start at 2048
    const Offset = 2048;

    fn index(handle: Handle) u16 {
        const handle_as_int: u16 = @intFromEnum(handle);
        if (handle_as_int < Offset) unreachable;
        return handle_as_int - Offset;
    }
};

const Data = union(enum) {
    void,
    file: File,
    embed_file: EmbedFile,
};

const EmbedFile = struct {
    path: [:0]const u8,
    data: [:0]const u8,
    /// current position of file
    pos: usize,
};

const VirtualFS = @This();

const testing = @import("std").testing;

test {
    testing.refAllDecls(VirtualFS);
}
