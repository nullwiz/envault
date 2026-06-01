const std = @import("std");

pub fn ensureAge(io: std.Io) !void {
    const argv = &.{ "age", "--version" };
    try runChecked(io, argv, .ignore, .ignore);
}

pub fn encrypt(io: std.Io, recipient: []const u8, source: []const u8, tmp_output: []const u8) !void {
    const argv = &.{ "age", "-R", recipient, "-o", tmp_output, source };
    try runChecked(io, argv, .ignore, .inherit);
}

pub fn decryptToFile(io: std.Io, identity: []const u8, vault_file: []const u8, tmp_output: []const u8) !void {
    const argv = &.{ "age", "-d", "-i", identity, "-o", tmp_output, vault_file };
    try runChecked(io, argv, .ignore, .inherit);
}

pub fn decryptToStdout(io: std.Io, identity: []const u8, vault_file: []const u8) !void {
    const argv = &.{ "age", "-d", "-i", identity, vault_file };
    try runChecked(io, argv, .inherit, .inherit);
}

fn runChecked(
    io: std.Io,
    argv: []const []const u8,
    stdout: std.process.SpawnOptions.StdIo,
    stderr: std.process.SpawnOptions.StdIo,
) !void {
    var child = try std.process.spawn(io, .{
        .argv = argv,
        .stdin = .ignore,
        .stdout = stdout,
        .stderr = stderr,
    });
    const term = try child.wait(io);
    switch (term) {
        .exited => |code| if (code == 0) return,
        else => {},
    }
    return error.CommandFailed;
}
