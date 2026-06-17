const std = @import("std");
const cli = @import("cli.zig");
const fs_safe = @import("fs_safe.zig");
const vault = @import("vault.zig");

const plugin = "age-plugin-yubikey";

pub fn doctor(io: std.Io, stdout: *std.Io.Writer) !void {
    try runChecked(io, &.{ "age", "--version" }, .ignore, .ignore);
    try runChecked(io, &.{ plugin, "--help" }, .ignore, .ignore);
    try stdout.writeAll("age: ok\nage-plugin-yubikey: ok\n");
}

pub fn list(io: std.Io, opts: cli.YubiKeyList) !void {
    const argv: []const []const u8 = if (opts.all)
        &[_][]const u8{ plugin, "--list-all" }
    else
        &[_][]const u8{ plugin, "--list" };
    try runChecked(io, argv, .inherit, .inherit);
}

pub fn setup(
    allocator: std.mem.Allocator,
    io: std.Io,
    env: *std.process.Environ.Map,
    stdout: *std.Io.Writer,
    opts: cli.YubiKeySetup,
) !void {
    const identity = try vault.expandHome(allocator, env, opts.identity);
    const recipient = try vault.expandHome(allocator, env, opts.recipient);

    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(allocator, &.{ plugin, "--identity", "--slot", opts.slot });
    if (opts.serial) |serial| try argv.appendSlice(allocator, &.{ "--serial", serial });

    try writePluginIdentity(allocator, io, argv.items, identity, recipient);
    try printConfigured(stdout, identity, recipient);
}

pub fn generate(
    allocator: std.mem.Allocator,
    io: std.Io,
    env: *std.process.Environ.Map,
    stdout: *std.Io.Writer,
    opts: cli.YubiKeyGenerate,
) !void {
    const identity = try vault.expandHome(allocator, env, opts.identity);
    const recipient = try vault.expandHome(allocator, env, opts.recipient);

    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(allocator, &.{ plugin, "--generate" });
    if (opts.slot) |slot| try argv.appendSlice(allocator, &.{ "--slot", slot });
    if (opts.serial) |serial| try argv.appendSlice(allocator, &.{ "--serial", serial });
    if (opts.name) |name| try argv.appendSlice(allocator, &.{ "--name", name });
    if (opts.pin_policy) |policy| try argv.appendSlice(allocator, &.{ "--pin-policy", policy });
    if (opts.touch_policy) |policy| try argv.appendSlice(allocator, &.{ "--touch-policy", policy });

    try writePluginIdentity(allocator, io, argv.items, identity, recipient);
    try printConfigured(stdout, identity, recipient);
}

fn writePluginIdentity(
    allocator: std.mem.Allocator,
    io: std.Io,
    argv: []const []const u8,
    identity_path: []const u8,
    recipient_path: []const u8,
) !void {
    try fs_safe.ensureParentDir(io, allocator, identity_path);
    try fs_safe.ensureParentDir(io, allocator, recipient_path);

    const tmp_identity = try fs_safe.tempPath(io, allocator, identity_path);
    errdefer std.Io.Dir.cwd().deleteFile(io, tmp_identity) catch {};

    try runCheckedToFile(io, argv, tmp_identity);
    try fs_safe.chmod600(io, tmp_identity);

    const identity = try std.Io.Dir.cwd().readFileAlloc(io, tmp_identity, allocator, .limited(128 * 1024));
    defer allocator.free(identity);

    const recipient = try extractRecipient(identity);
    const recipient_file = try std.fmt.allocPrint(allocator, "{s}\n", .{recipient});
    defer allocator.free(recipient_file);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = recipient_path, .data = recipient_file });
    try fs_safe.chmod600(io, recipient_path);

    try fs_safe.renameIntoPlace(io, tmp_identity, identity_path);
}

fn extractRecipient(identity: []const u8) ![]const u8 {
    var lines = std.mem.splitScalar(u8, identity, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        const prefix = "# recipient: ";
        if (std.mem.startsWith(u8, trimmed, prefix)) return trimmed[prefix.len..];
    }
    return error.YubiKeyRecipientNotFound;
}

fn printConfigured(stdout: *std.Io.Writer, identity: []const u8, recipient: []const u8) !void {
    try stdout.print(
        \\YubiKey identity: {s}
        \\YubiKey recipient: {s}
        \\
        \\Use this profile with:
        \\  ENVAULT_YUBIKEY=1 envault put dev
        \\  ENVAULT_YUBIKEY=1 envault get dev
        \\
    , .{ identity, recipient });
}

fn runCheckedToFile(io: std.Io, argv: []const []const u8, output_path: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(io, output_path, .{ .truncate = true });
    defer file.close(io);

    var child = std.process.spawn(io, .{
        .argv = argv,
        .stdin = .inherit,
        .stdout = .{ .file = file },
        .stderr = .inherit,
    }) catch |err| return mapSpawnError(argv[0], err);
    const term = try child.wait(io);
    switch (term) {
        .exited => |code| if (code == 0) return,
        else => {},
    }
    return error.CommandFailed;
}

fn runChecked(
    io: std.Io,
    argv: []const []const u8,
    stdout: std.process.SpawnOptions.StdIo,
    stderr: std.process.SpawnOptions.StdIo,
) !void {
    var child = std.process.spawn(io, .{
        .argv = argv,
        .stdin = .ignore,
        .stdout = stdout,
        .stderr = stderr,
    }) catch |err| return mapSpawnError(argv[0], err);
    const term = try child.wait(io);
    switch (term) {
        .exited => |code| if (code == 0) return,
        else => {},
    }
    return error.CommandFailed;
}

fn mapSpawnError(program: []const u8, err: std.process.SpawnError) anyerror!void {
    if (err == error.FileNotFound or err == error.NotDir) {
        if (std.mem.eql(u8, program, "age")) return error.AgeNotFound;
        if (std.mem.eql(u8, program, plugin)) return error.AgePluginYubiKeyNotFound;
    }
    return err;
}

test "extractRecipient reads age-plugin-yubikey identity comment" {
    const identity =
        \\# created: 2026-06-17T00:00:00Z
        \\# recipient: age1yubikey1qexample
        \\AGE-PLUGIN-YUBIKEY-1EXAMPLE
        \\
    ;
    try std.testing.expectEqualStrings("age1yubikey1qexample", try extractRecipient(identity));
}

test "extractRecipient rejects identity without recipient comment" {
    try std.testing.expectError(error.YubiKeyRecipientNotFound, extractRecipient("AGE-PLUGIN-YUBIKEY-1EXAMPLE\n"));
}
