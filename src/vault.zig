const std = @import("std");
const repo = @import("repo.zig");
const fs_safe = @import("fs_safe.zig");

pub const Config = struct {
    root: []const u8,
    identity: []const u8,
    recipient: []const u8,
};

pub fn loadConfig(allocator: std.mem.Allocator, env: *std.process.Environ.Map) !Config {
    return .{
        .root = try expandHome(allocator, env, env.get("ENVVAULT_ROOT") orelse "~/.env-vault"),
        .identity = try expandHome(allocator, env, env.get("ENVVAULT_IDENTITY") orelse "~/.ssh/id_ed25519"),
        .recipient = try expandHome(allocator, env, env.get("ENVVAULT_RECIPIENT") orelse "~/.ssh/id_ed25519.pub"),
    };
}

pub fn repoDir(allocator: std.mem.Allocator, cfg: Config, id: repo.RepoId) ![]const u8 {
    try fs_safe.validateSegment(id.host);
    try fs_safe.validateSegment(id.owner);
    if (id.name) |name| {
        try fs_safe.validateSegment(name);
        return std.fs.path.join(allocator, &.{ cfg.root, id.host, id.owner, name });
    }
    return std.fs.path.join(allocator, &.{ cfg.root, id.host, id.owner });
}

pub fn envFile(allocator: std.mem.Allocator, repo_dir: []const u8, env_name: []const u8) ![]const u8 {
    try fs_safe.validateSegment(env_name);
    const filename = try std.fmt.allocPrint(allocator, "{s}.env.age", .{env_name});
    defer allocator.free(filename);
    return std.fs.path.join(allocator, &.{ repo_dir, filename });
}

fn expandHome(allocator: std.mem.Allocator, env: *std.process.Environ.Map, value: []const u8) ![]const u8 {
    if (std.mem.eql(u8, value, "~")) {
        return allocator.dupe(u8, env.get("HOME") orelse return error.HomeNotSet);
    }
    if (std.mem.startsWith(u8, value, "~/")) {
        const home = env.get("HOME") orelse return error.HomeNotSet;
        return std.mem.concat(allocator, u8, &.{ home, value[1..] });
    }
    return allocator.dupe(u8, value);
}

test "loadConfig expands defaults under HOME" {
    const allocator = std.testing.allocator;
    var env = std.process.Environ.Map.init(allocator);
    defer env.deinit();
    try env.put("HOME", "/home/tester");

    const cfg = try loadConfig(allocator, &env);
    defer allocator.free(cfg.root);
    defer allocator.free(cfg.identity);
    defer allocator.free(cfg.recipient);

    try std.testing.expectEqualStrings("/home/tester/.env-vault", cfg.root);
    try std.testing.expectEqualStrings("/home/tester/.ssh/id_ed25519", cfg.identity);
    try std.testing.expectEqualStrings("/home/tester/.ssh/id_ed25519.pub", cfg.recipient);
}

test "loadConfig honors environment overrides" {
    const allocator = std.testing.allocator;
    var env = std.process.Environ.Map.init(allocator);
    defer env.deinit();
    try env.put("HOME", "/home/tester");
    try env.put("ENVVAULT_ROOT", "~/vault");
    try env.put("ENVVAULT_IDENTITY", "/keys/id");
    try env.put("ENVVAULT_RECIPIENT", "/keys/id.pub");

    const cfg = try loadConfig(allocator, &env);
    defer allocator.free(cfg.root);
    defer allocator.free(cfg.identity);
    defer allocator.free(cfg.recipient);

    try std.testing.expectEqualStrings("/home/tester/vault", cfg.root);
    try std.testing.expectEqualStrings("/keys/id", cfg.identity);
    try std.testing.expectEqualStrings("/keys/id.pub", cfg.recipient);
}

test "repoDir and envFile construct expected paths" {
    const allocator = std.testing.allocator;
    const cfg: Config = .{ .root = "/vault", .identity = "/id", .recipient = "/id.pub" };

    const github_dir = try repoDir(allocator, cfg, .{
        .host = "github.com",
        .owner = "owner",
        .name = "repo",
    });
    defer allocator.free(github_dir);
    try std.testing.expectEqualStrings("/vault/github.com/owner/repo", github_dir);

    const local_dir = try repoDir(allocator, cfg, .{
        .host = "local",
        .owner = "project",
        .name = null,
    });
    defer allocator.free(local_dir);
    try std.testing.expectEqualStrings("/vault/local/project", local_dir);

    const env_path = try envFile(allocator, github_dir, "dev");
    defer allocator.free(env_path);
    try std.testing.expectEqualStrings("/vault/github.com/owner/repo/dev.env.age", env_path);
}
