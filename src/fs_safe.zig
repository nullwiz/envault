const std = @import("std");

pub const SafeError = error{
    InvalidName,
    RefusingToOverwrite,
    FileNotFound,
    NotAFile,
};

pub fn validateSegment(segment: []const u8) SafeError!void {
    if (segment.len == 0) return error.InvalidName;
    if (std.mem.eql(u8, segment, ".") or std.mem.eql(u8, segment, "..")) return error.InvalidName;
    if (std.mem.indexOfAny(u8, segment, "/\\\x00") != null) return error.InvalidName;
}

pub fn exists(io: std.Io, path: []const u8) bool {
    std.Io.Dir.cwd().access(io, path, .{}) catch return false;
    return true;
}

pub fn requireFile(io: std.Io, path: []const u8) !void {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return error.FileNotFound,
        else => return err,
    };
    if (stat.kind != .file) return error.NotAFile;
}

pub fn ensureParentDir(io: std.Io, allocator: std.mem.Allocator, path: []const u8) !void {
    const parent = std.fs.path.dirname(path) orelse return;
    try std.Io.Dir.cwd().createDirPath(io, parent);
    _ = allocator;
}

pub fn tempPath(io: std.Io, allocator: std.mem.Allocator, final_path: []const u8) ![]u8 {
    var bytes: [8]u8 = undefined;
    try io.randomSecure(&bytes);
    const suffix = std.mem.readInt(u64, &bytes, .little);
    return std.fmt.allocPrint(allocator, "{s}.tmp.{d}", .{ final_path, suffix });
}

pub fn renameIntoPlace(io: std.Io, tmp_path: []const u8, final_path: []const u8) !void {
    try std.Io.Dir.rename(std.Io.Dir.cwd(), tmp_path, std.Io.Dir.cwd(), final_path, io);
}

pub fn chmod600(io: std.Io, path: []const u8) !void {
    try std.Io.Dir.cwd().setFilePermissions(io, path, .fromMode(0o600), .{});
}

test "validateSegment accepts simple names" {
    try validateSegment("dev");
    try validateSegment("prod_2026");
    try validateSegment("owner.repo");
}

test "validateSegment rejects traversal and separators" {
    try std.testing.expectError(error.InvalidName, validateSegment(""));
    try std.testing.expectError(error.InvalidName, validateSegment("."));
    try std.testing.expectError(error.InvalidName, validateSegment(".."));
    try std.testing.expectError(error.InvalidName, validateSegment("dev/prod"));
    try std.testing.expectError(error.InvalidName, validateSegment("dev\\prod"));
}
