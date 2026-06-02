const std = @import("std");

pub const Command = union(enum) {
    get: Get,
    put: Put,
    list: void,
    where: Where,
    backup: Backup,
    help: void,
};

pub const Get = struct {
    env_name: []const u8 = "dev",
    target: []const u8 = ".env",
    force: bool = false,
    print: bool = false,
};

pub const Put = struct {
    env_name: []const u8 = "dev",
    source: []const u8 = ".env",
};

pub const Where = struct {
    env_name: []const u8 = "dev",
};

pub const Backup = union(enum) {
    init: BackupInit,
    status: void,
    commit: BackupCommit,
    push: void,
};

pub const BackupInit = struct {
    remote: ?[]const u8 = null,
};

pub const BackupCommit = struct {
    message: []const u8 = "envault backup",
};

pub const ParseError = error{
    UnknownCommand,
    UnknownOption,
    MissingOptionValue,
    TooManyArguments,
};

pub fn parse(args: []const []const u8) ParseError!Command {
    if (args.len <= 1) return .help;

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
        return .help;
    }
    if (std.mem.eql(u8, cmd, "get")) return .{ .get = try parseGet(args[2..]) };
    if (std.mem.eql(u8, cmd, "put")) return .{ .put = try parsePut(args[2..]) };
    if (std.mem.eql(u8, cmd, "list")) {
        if (args.len != 2) return error.TooManyArguments;
        return .{ .list = {} };
    }
    if (std.mem.eql(u8, cmd, "where")) return .{ .where = try parseWhere(args[2..]) };
    if (std.mem.eql(u8, cmd, "backup")) return .{ .backup = try parseBackup(args[2..]) };

    return error.UnknownCommand;
}

fn parseGet(args: []const []const u8) ParseError!Get {
    var result: Get = .{};
    var saw_env = false;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--force")) {
            result.force = true;
        } else if (std.mem.eql(u8, arg, "--print")) {
            result.print = true;
        } else if (std.mem.eql(u8, arg, "--to")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.target = args[i];
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else if (!saw_env) {
            result.env_name = arg;
            saw_env = true;
        } else {
            return error.TooManyArguments;
        }
    }
    return result;
}

fn parsePut(args: []const []const u8) ParseError!Put {
    var result: Put = .{};
    var saw_env = false;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--from")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.source = args[i];
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else if (!saw_env) {
            result.env_name = arg;
            saw_env = true;
        } else {
            return error.TooManyArguments;
        }
    }
    return result;
}

fn parseWhere(args: []const []const u8) ParseError!Where {
    var result: Where = .{};
    if (args.len > 1) return error.TooManyArguments;
    if (args.len == 1) result.env_name = args[0];
    return result;
}

fn parseBackup(args: []const []const u8) ParseError!Backup {
    if (args.len == 0) return error.MissingOptionValue;

    const subcmd = args[0];
    if (std.mem.eql(u8, subcmd, "init")) return .{ .init = try parseBackupInit(args[1..]) };
    if (std.mem.eql(u8, subcmd, "status")) {
        if (args.len != 1) return error.TooManyArguments;
        return .{ .status = {} };
    }
    if (std.mem.eql(u8, subcmd, "commit")) return .{ .commit = try parseBackupCommit(args[1..]) };
    if (std.mem.eql(u8, subcmd, "push")) {
        if (args.len != 1) return error.TooManyArguments;
        return .{ .push = {} };
    }

    return error.UnknownCommand;
}

fn parseBackupInit(args: []const []const u8) ParseError!BackupInit {
    var result: BackupInit = .{};
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--remote")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.remote = args[i];
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else {
            return error.TooManyArguments;
        }
    }
    return result;
}

fn parseBackupCommit(args: []const []const u8) ParseError!BackupCommit {
    var result: BackupCommit = .{};
    if (args.len > 1) return error.TooManyArguments;
    if (args.len == 1) result.message = args[0];
    return result;
}

pub fn usage(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.writeAll(
        \\Usage:
        \\  envault get [env] [--to .env] [--force] [--print]
        \\  envault put [env] [--from .env]
        \\  envault list
        \\  envault where [env]
        \\  envault backup init [--remote URL]
        \\  envault backup status
        \\  envault backup commit [message]
        \\  envault backup push
        \\
        \\Defaults:
        \\  env=dev, target=.env, source=.env
        \\
        \\Environment:
        \\  ENVAULT_ROOT
        \\  ENVAULT_IDENTITY
        \\  ENVAULT_RECIPIENT
        \\
    );
}

test "parse get defaults and flags" {
    const cmd = try parse(&.{ "envault", "get", "prod", "--force", "--to", "custom.env" });
    try std.testing.expectEqualStrings("prod", cmd.get.env_name);
    try std.testing.expectEqualStrings("custom.env", cmd.get.target);
    try std.testing.expect(cmd.get.force);
}

test "parse put defaults" {
    const cmd = try parse(&.{ "envault", "put" });
    try std.testing.expectEqualStrings("dev", cmd.put.env_name);
    try std.testing.expectEqualStrings(".env", cmd.put.source);
}

test "parse get supports print without force" {
    const cmd = try parse(&.{ "envault", "get", "--print" });
    try std.testing.expectEqualStrings("dev", cmd.get.env_name);
    try std.testing.expect(cmd.get.print);
    try std.testing.expect(!cmd.get.force);
}

test "parse backup commands" {
    const init_cmd = try parse(&.{ "envault", "backup", "init", "--remote", "git@example.com:vault.git" });
    try std.testing.expectEqualStrings("git@example.com:vault.git", init_cmd.backup.init.remote.?);

    const init_default_cmd = try parse(&.{ "envault", "backup", "init" });
    try std.testing.expect(init_default_cmd.backup.init.remote == null);

    const status_cmd = try parse(&.{ "envault", "backup", "status" });
    try std.testing.expect(status_cmd.backup == .status);

    const default_commit_cmd = try parse(&.{ "envault", "backup", "commit" });
    try std.testing.expectEqualStrings("envault backup", default_commit_cmd.backup.commit.message);

    const commit_cmd = try parse(&.{ "envault", "backup", "commit", "snapshot" });
    try std.testing.expectEqualStrings("snapshot", commit_cmd.backup.commit.message);

    const push_cmd = try parse(&.{ "envault", "backup", "push" });
    try std.testing.expect(push_cmd.backup == .push);
}

test "parse errors are explicit" {
    try std.testing.expectError(error.UnknownCommand, parse(&.{ "envault", "edit" }));
    try std.testing.expectError(error.UnknownOption, parse(&.{ "envault", "get", "--bad" }));
    try std.testing.expectError(error.MissingOptionValue, parse(&.{ "envault", "put", "--from" }));
    try std.testing.expectError(error.TooManyArguments, parse(&.{ "envault", "where", "dev", "prod" }));
    try std.testing.expectError(error.UnknownCommand, parse(&.{ "envault", "backup", "bad" }));
    try std.testing.expectError(error.MissingOptionValue, parse(&.{ "envault", "backup" }));
    try std.testing.expectError(error.MissingOptionValue, parse(&.{ "envault", "backup", "init", "--remote" }));
    try std.testing.expectError(error.UnknownOption, parse(&.{ "envault", "backup", "init", "--bad" }));
    try std.testing.expectError(error.TooManyArguments, parse(&.{ "envault", "backup", "status", "extra" }));
}
