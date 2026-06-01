const std = @import("std");
const envvault = @import("envvault");
const cli = envvault.cli;
const repo = envvault.repo;
const vault = envvault.vault;
const crypto = envvault.crypto;
const fs_safe = envvault.fs_safe;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(allocator);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const command = cli.parse(args) catch |err| {
        std.debug.print("envvault: {s}\n\n", .{@errorName(err)});
        try cli.usage(stdout);
        std.process.exit(2);
    };

    run(allocator, io, init.environ_map, stdout, command) catch |err| {
        std.debug.print("envvault: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
}

fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    env: *std.process.Environ.Map,
    stdout: *std.Io.Writer,
    command: cli.Command,
) !void {
    switch (command) {
        .help => try cli.usage(stdout),
        .get => |opts| try cmdGet(allocator, io, env, opts),
        .put => |opts| try cmdPut(allocator, io, env, opts),
        .list => try cmdList(allocator, io, env, stdout),
        .where => |opts| try cmdWhere(allocator, io, env, stdout, opts),
    }
}

fn commonPaths(
    allocator: std.mem.Allocator,
    io: std.Io,
    env: *std.process.Environ.Map,
    env_name: []const u8,
) !struct { cfg: vault.Config, repo_dir: []const u8, vault_file: []const u8 } {
    try fs_safe.validateSegment(env_name);
    const cfg = try vault.loadConfig(allocator, env);
    const id = try repo.detect(allocator, io);
    const repo_dir = try vault.repoDir(allocator, cfg, id);
    const vault_file = try vault.envFile(allocator, repo_dir, env_name);
    return .{ .cfg = cfg, .repo_dir = repo_dir, .vault_file = vault_file };
}

fn cmdPut(allocator: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, opts: cli.Put) !void {
    const paths = try commonPaths(allocator, io, env, opts.env_name);

    try fs_safe.requireFile(io, opts.source);
    try fs_safe.requireFile(io, paths.cfg.recipient);
    try crypto.ensureAge(io);
    try std.Io.Dir.cwd().createDirPath(io, paths.repo_dir);

    const tmp_path = try fs_safe.tempPath(io, allocator, paths.vault_file);
    errdefer std.Io.Dir.cwd().deleteFile(io, tmp_path) catch {};

    try crypto.encrypt(io, paths.cfg.recipient, opts.source, tmp_path);
    try fs_safe.renameIntoPlace(io, tmp_path, paths.vault_file);
    try fs_safe.chmod600(io, paths.vault_file);
}

fn cmdGet(allocator: std.mem.Allocator, io: std.Io, env: *std.process.Environ.Map, opts: cli.Get) !void {
    const paths = try commonPaths(allocator, io, env, opts.env_name);

    try fs_safe.requireFile(io, paths.vault_file);
    try fs_safe.requireFile(io, paths.cfg.identity);
    try crypto.ensureAge(io);

    if (opts.print) {
        try crypto.decryptToStdout(io, paths.cfg.identity, paths.vault_file);
        return;
    }

    if (!opts.force and fs_safe.exists(io, opts.target)) return error.RefusingToOverwrite;

    try fs_safe.ensureParentDir(io, allocator, opts.target);
    const tmp_path = try fs_safe.tempPath(io, allocator, opts.target);
    errdefer std.Io.Dir.cwd().deleteFile(io, tmp_path) catch {};

    try crypto.decryptToFile(io, paths.cfg.identity, paths.vault_file, tmp_path);
    try fs_safe.renameIntoPlace(io, tmp_path, opts.target);
    try fs_safe.chmod600(io, opts.target);
}

fn cmdList(
    allocator: std.mem.Allocator,
    io: std.Io,
    env: *std.process.Environ.Map,
    stdout: *std.Io.Writer,
) !void {
    const cfg = try vault.loadConfig(allocator, env);
    const id = try repo.detect(allocator, io);
    const dir_path = try vault.repoDir(allocator, cfg, id);

    var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer dir.close(io);

    var names: std.ArrayList([]const u8) = .empty;
    var iterator = dir.iterateAssumeFirstIteration();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".env.age")) continue;
        const name = entry.name[0 .. entry.name.len - ".env.age".len];
        try names.append(allocator, try allocator.dupe(u8, name));
    }

    std.sort.insertion([]const u8, names.items, {}, lessThanString);
    for (names.items) |name| {
        try stdout.print("{s}\n", .{name});
    }
}

fn lessThanString(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.lessThan(u8, lhs, rhs);
}

fn cmdWhere(
    allocator: std.mem.Allocator,
    io: std.Io,
    env: *std.process.Environ.Map,
    stdout: *std.Io.Writer,
    opts: cli.Where,
) !void {
    const paths = try commonPaths(allocator, io, env, opts.env_name);
    try stdout.print("{s}\n", .{paths.vault_file});
}
