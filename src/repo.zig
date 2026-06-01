const std = @import("std");
const fs_safe = @import("fs_safe.zig");

pub const RepoId = struct {
    host: []const u8,
    owner: []const u8,
    name: ?[]const u8,
};

pub fn detect(allocator: std.mem.Allocator, io: std.Io) !RepoId {
    if (try gitRemote(allocator, io)) |remote| {
        if (parseRemote(remote)) |parsed| return parsed;
    }
    return fallbackLocal(allocator, io);
}

fn gitRemote(allocator: std.mem.Allocator, io: std.Io) !?[]const u8 {
    const result = std.process.run(allocator, io, .{
        .argv = &.{ "git", "config", "--get", "remote.origin.url" },
        .stdout_limit = .limited(4096),
        .stderr_limit = .limited(4096),
    }) catch return null;
    defer allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| if (code != 0) {
            allocator.free(result.stdout);
            return null;
        },
        else => {
            allocator.free(result.stdout);
            return null;
        },
    }

    const trimmed = std.mem.trim(u8, result.stdout, " \t\r\n");
    return try allocator.dupe(u8, trimmed);
}

pub fn parseRemote(remote: []const u8) ?RepoId {
    if (std.mem.startsWith(u8, remote, "git@github.com:")) {
        return parseGitHubPath(remote["git@github.com:".len..]);
    }
    if (std.mem.startsWith(u8, remote, "https://github.com/")) {
        return parseGitHubPath(remote["https://github.com/".len..]);
    }
    if (std.mem.startsWith(u8, remote, "http://github.com/")) {
        return parseGitHubPath(remote["http://github.com/".len..]);
    }
    if (std.mem.startsWith(u8, remote, "ssh://git@github.com/")) {
        return parseGitHubPath(remote["ssh://git@github.com/".len..]);
    }
    return null;
}

fn parseGitHubPath(path: []const u8) ?RepoId {
    var split = std.mem.splitScalar(u8, path, '/');
    const owner = split.next() orelse return null;
    const repo_part = split.next() orelse return null;
    if (split.next() != null) return null;

    const name = stripGitSuffix(repo_part);
    fs_safe.validateSegment(owner) catch return null;
    fs_safe.validateSegment(name) catch return null;
    return .{ .host = "github.com", .owner = owner, .name = name };
}

fn stripGitSuffix(value: []const u8) []const u8 {
    if (std.mem.endsWith(u8, value, ".git")) return value[0 .. value.len - 4];
    return value;
}

fn fallbackLocal(allocator: std.mem.Allocator, io: std.Io) !RepoId {
    const cwd = try std.process.currentPathAlloc(io, allocator);
    const base = std.fs.path.basename(cwd);
    try fs_safe.validateSegment(base);
    return .{
        .host = "local",
        .owner = try allocator.dupe(u8, base),
        .name = null,
    };
}

test "parse ssh github remote" {
    const parsed = parseRemote("git@github.com:owner/repo.git").?;
    try std.testing.expectEqualStrings("github.com", parsed.host);
    try std.testing.expectEqualStrings("owner", parsed.owner);
    try std.testing.expectEqualStrings("repo", parsed.name.?);
}

test "parse https github remote" {
    const parsed = parseRemote("https://github.com/owner/repo.git").?;
    try std.testing.expectEqualStrings("owner", parsed.owner);
    try std.testing.expectEqualStrings("repo", parsed.name.?);
}

test "parse ssh url github remote" {
    const parsed = parseRemote("ssh://git@github.com/owner/repo.git").?;
    try std.testing.expectEqualStrings("github.com", parsed.host);
    try std.testing.expectEqualStrings("owner", parsed.owner);
    try std.testing.expectEqualStrings("repo", parsed.name.?);
}

test "parseRemote rejects unsupported remotes and unsafe paths" {
    try std.testing.expect(parseRemote("git@gitlab.com:owner/repo.git") == null);
    try std.testing.expect(parseRemote("https://github.com/owner/repo/extra.git") == null);
    try std.testing.expect(parseRemote("git@github.com:../repo.git") == null);
    try std.testing.expect(parseRemote("git@github.com:owner/..git") == null);
}
