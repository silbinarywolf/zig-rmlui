//! ZigFileInterface is a FileInterface implementation for RmlUi

const std = @import("std");
const builtin = @import("builtin");
const Dir = std.fs.Dir;
const File = std.fs.File;

const crml = @import("crml");
const rmlui = @import("root.zig");
const VirtualFS = @import("VirtualFS.zig");

const log = std.log.scoped(.FileInterface);

root_directory: ?Dir,
impl: *crml.RmlFileInterface,
embedded_files: []const EmbedFile,
fs: VirtualFS,

pub const Options = struct {
    root_directory: ?Dir = null,
    embedded_files: []const EmbedFile = &.{},
};

const EmbedFile = struct {
    path: [:0]const u8,
    data: [:0]const u8,
};

pub fn init(self: *ZigFileInterface, allocator: std.mem.Allocator, options: Options) error{OutOfMemory}!void {
    _ = allocator;
    const impl = crml.rmlFileInterface_new(&.{
        .userdata = self,
        .open = fileOpen,
        .close = fileClose,
        .read = fileRead,
        .seek = fileSeek,
        .tell = fileTell,
    }) orelse return error.OutOfMemory;
    self.* = .{
        .root_directory = null,
        .impl = impl,
        .embedded_files = options.embedded_files,
        .fs = .empty,
    };
}

pub fn deinit(self: *ZigFileInterface, allocator: std.mem.Allocator) void {
    _ = allocator;
    self.* = undefined;
}

pub fn interface(self: *ZigFileInterface) *rmlui.FileInterface {
    return @ptrCast(self.impl);
}

fn fileOpen(path_ptr: [*c]const u8, path_len: c_uint, userdata: ?*anyopaque) callconv(.c) crml.RmlFileHandle {
    const self: *ZigFileInterface = @ptrCast(@alignCast(userdata));
    const path = path_ptr[0..path_len];
    for (self.embedded_files) |embedded_file| {
        if (std.mem.eql(u8, embedded_file.path, path)) {
            const handle = self.fs.fromEmbedFile(embedded_file.path, embedded_file.data) catch |err| switch (err) {
                error.ProcessFdQuotaExceeded => @panic("failed to open embedded file, no more file descriptor slots for RmlUi interface"),
            };
            return @intFromEnum(handle);
        }
    }
    if (builtin.os.tag == .freestanding) {
        log.err("no file found '{s}'", .{path});
        return 0;
    }
    const root_directory = if (self.root_directory) |r|
        r
    else if (builtin.os.tag == .freestanding)
        .{ .fd = -2 }
    else
        std.fs.cwd();
    const f = root_directory.openFile(path, .{}) catch |err| {
        log.err("error '{s}' when opening file '{s}'", .{ @errorName(err), path });
        return 0;
    };
    const handle = self.fs.fromFile(f) catch |err| switch (err) {
        error.ProcessFdQuotaExceeded => @panic("failed to open file, no more file descriptor slots for RmlUi interface"),
    };
    return @intFromEnum(handle);
}

fn fileClose(file: crml.RmlFileHandle, userdata: ?*anyopaque) callconv(.c) void {
    const self: *ZigFileInterface = @ptrCast(@alignCast(userdata));
    return self.fs.close(@enumFromInt(file));
}

fn fileRead(buf_ptr: [*c]u8, amount_to_read: usize, file: crml.RmlFileHandle, userdata: ?*anyopaque) callconv(.c) usize {
    const self: *ZigFileInterface = @ptrCast(@alignCast(userdata));
    const buf: []u8 = buf_ptr[0..amount_to_read];
    return self.fs.read(@enumFromInt(file), buf) catch |err|
        std.debug.panic("file read failed with {s} error", .{@errorName(err)});
}

fn fileSeek(file: crml.RmlFileHandle, offset: c_long, origin: c_int, userdata: ?*anyopaque) callconv(.c) bool {
    const self: *ZigFileInterface = @ptrCast(@alignCast(userdata));
    self.fs.seek(@enumFromInt(file), @intCast(offset), switch (origin) {
        // SEEK_START
        0 => .start,
        // SEEK_CURR
        1 => .current,
        // SEEK_END
        2 => .end,
        else => unreachable,
    }) catch |err| switch (err) {
        error.Unseekable => return false,
        else => std.debug.panic("file seek failed with {s} error", .{@errorName(err)}),
    };
    return true;
}

fn fileTell(file: crml.RmlFileHandle, userdata: ?*anyopaque) callconv(.c) usize {
    const self: *ZigFileInterface = @ptrCast(@alignCast(userdata));
    return self.fs.tell(@enumFromInt(file));
}

const ZigFileInterface = @This();

const testing = @import("std").testing;

test {
    testing.refAllDecls(ZigFileInterface);
}
