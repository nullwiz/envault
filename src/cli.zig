const std = @import("std");

pub const Command = union(enum) {
    get: Get,
    put: Put,
    list: void,
    where: Where,
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

pub fn usage(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.writeAll(
        \\Usage:
        \\  envault get [env] [--to .env] [--force] [--print]
        \\  envault put [env] [--from .env]
        \\  envault list
        \\  envault where [env]
        \\
        \\Defaults:
        \\  env=dev, target=.env, source=.env
        \\
        \\Environment:
        \\  ENAULT_ROOT
        \\  ENAULT_IDENTITY
        \\  ENAULT_RECIPIENT
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

test "parse errors are explicit" {
    try std.testing.expectError(error.UnknownCommand, parse(&.{ "envault", "edit" }));
    try std.testing.expectError(error.UnknownOption, parse(&.{ "envault", "get", "--bad" }));
    try std.testing.expectError(error.MissingOptionValue, parse(&.{ "envault", "put", "--from" }));
    try std.testing.expectError(error.TooManyArguments, parse(&.{ "envault", "where", "dev", "prod" }));
}
