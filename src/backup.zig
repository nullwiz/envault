const std = @import("std");

pub const Init = struct {
    remote: ?[]const u8 = null,
};

pub const Commit = struct {
    message: []const u8 = "envault backup",
};

pub fn init(allocator: std.mem.Allocator, io: std.Io, root: []const u8, opts: Init) !void {
    try ensureGit(io);
    try std.Io.Dir.cwd().createDirPath(io, root);
    try runGit(allocator, io, root, &.{ "init" }, .inherit, .inherit);
    if (opts.remote) |remote| try setRemote(allocator, io, root, remote);
}

pub fn status(allocator: std.mem.Allocator, io: std.Io, root: []const u8) !void {
    try ensureGit(io);
    try runGit(allocator, io, root, &.{ "status", "--short", "--", "*.env.age" }, .inherit, .inherit);
}

pub fn commit(allocator: std.mem.Allocator, io: std.Io, root: []const u8, opts: Commit) !void {
    try ensureGit(io);
    try runGit(allocator, io, root, &.{ "add", "-A", "--", "*.env.age" }, .inherit, .inherit);
    if (!try hasStagedEnvChanges(allocator, io, root)) return;
    try runGit(allocator, io, root, &.{ "commit", "-m", opts.message }, .inherit, .inherit);
}

pub fn push(allocator: std.mem.Allocator, io: std.Io, root: []const u8) !void {
    try ensureGit(io);
    try runGit(allocator, io, root, &.{ "push" }, .inherit, .inherit);
}

fn ensureGit(io: std.Io) !void {
    try runChecked(io, &.{ "git", "--version" }, .ignore, .ignore);
}

fn setRemote(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    remote: []const u8,
) !void {
    runGit(allocator, io, root, &.{ "remote", "set-url", "origin", remote }, .ignore, .ignore) catch |err| switch (err) {
        error.CommandFailed => try runGit(allocator, io, root, &.{ "remote", "add", "origin", remote }, .inherit, .inherit),
        else => return err,
    };
}

fn runGit(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    args: []const []const u8,
    stdout: std.process.SpawnOptions.StdIo,
    stderr: std.process.SpawnOptions.StdIo,
) !void {
    var argv: std.ArrayList([]const u8) = .empty;
    try argv.append(allocator, "git");
    try argv.append(allocator, "-C");
    try argv.append(allocator, root);
    try argv.appendSlice(allocator, args);

    try runChecked(io, argv.items, stdout, stderr);
}

fn hasStagedEnvChanges(allocator: std.mem.Allocator, io: std.Io, root: []const u8) !bool {
    const code = try runGitExitCode(allocator, io, root, &.{ "diff", "--cached", "--quiet", "--", "*.env.age" });
    return switch (code) {
        0 => false,
        1 => true,
        else => error.CommandFailed,
    };
}

fn runGitExitCode(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    args: []const []const u8,
) !u8 {
    var argv: std.ArrayList([]const u8) = .empty;
    try argv.append(allocator, "git");
    try argv.append(allocator, "-C");
    try argv.append(allocator, root);
    try argv.appendSlice(allocator, args);

    return try runExitCode(io, argv.items);
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

fn runExitCode(io: std.Io, argv: []const []const u8) !u8 {
    var child = try std.process.spawn(io, .{
        .argv = argv,
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
    });
    const term = try child.wait(io);
    return switch (term) {
        .exited => |code| code,
        else => error.CommandFailed,
    };
}
