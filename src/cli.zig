const std = @import("std");

pub const Command = union(enum) {
    get: Get,
    put: Put,
    list: void,
    where: Where,
    backup: Backup,
    yubikey: YubiKey,
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

pub const YubiKey = union(enum) {
    doctor: void,
    list: YubiKeyList,
    setup: YubiKeySetup,
    generate: YubiKeyGenerate,
};

pub const YubiKeyList = struct {
    all: bool = false,
};

pub const YubiKeySetup = struct {
    slot: []const u8,
    serial: ?[]const u8 = null,
    identity: []const u8 = "~/.envault/yubikey-identity.txt",
    recipient: []const u8 = "~/.envault/yubikey-recipient.txt",
};

pub const YubiKeyGenerate = struct {
    slot: ?[]const u8 = null,
    serial: ?[]const u8 = null,
    name: ?[]const u8 = null,
    pin_policy: ?[]const u8 = null,
    touch_policy: ?[]const u8 = null,
    identity: []const u8 = "~/.envault/yubikey-identity.txt",
    recipient: []const u8 = "~/.envault/yubikey-recipient.txt",
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
    if (std.mem.eql(u8, cmd, "yubikey")) return .{ .yubikey = try parseYubiKey(args[2..]) };

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

fn parseYubiKey(args: []const []const u8) ParseError!YubiKey {
    if (args.len == 0) return error.MissingOptionValue;

    const subcmd = args[0];
    if (std.mem.eql(u8, subcmd, "doctor")) {
        if (args.len != 1) return error.TooManyArguments;
        return .{ .doctor = {} };
    }
    if (std.mem.eql(u8, subcmd, "list")) return .{ .list = try parseYubiKeyList(args[1..]) };
    if (std.mem.eql(u8, subcmd, "setup")) return .{ .setup = try parseYubiKeySetup(args[1..]) };
    if (std.mem.eql(u8, subcmd, "generate")) return .{ .generate = try parseYubiKeyGenerate(args[1..]) };

    return error.UnknownCommand;
}

fn parseYubiKeyList(args: []const []const u8) ParseError!YubiKeyList {
    var result: YubiKeyList = .{};
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--all")) {
            result.all = true;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else {
            return error.TooManyArguments;
        }
    }
    return result;
}

fn parseYubiKeySetup(args: []const []const u8) ParseError!YubiKeySetup {
    var result = YubiKeySetup{ .slot = undefined };
    var saw_slot = false;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--slot")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.slot = args[i];
            saw_slot = true;
        } else if (std.mem.eql(u8, arg, "--serial")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.serial = args[i];
        } else if (std.mem.eql(u8, arg, "--identity")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.identity = args[i];
        } else if (std.mem.eql(u8, arg, "--recipient")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.recipient = args[i];
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else {
            return error.TooManyArguments;
        }
    }
    if (!saw_slot) return error.MissingOptionValue;
    return result;
}

fn parseYubiKeyGenerate(args: []const []const u8) ParseError!YubiKeyGenerate {
    var result: YubiKeyGenerate = .{};
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--slot")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.slot = args[i];
        } else if (std.mem.eql(u8, arg, "--serial")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.serial = args[i];
        } else if (std.mem.eql(u8, arg, "--name")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.name = args[i];
        } else if (std.mem.eql(u8, arg, "--pin-policy")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.pin_policy = args[i];
        } else if (std.mem.eql(u8, arg, "--touch-policy")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.touch_policy = args[i];
        } else if (std.mem.eql(u8, arg, "--identity")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.identity = args[i];
        } else if (std.mem.eql(u8, arg, "--recipient")) {
            i += 1;
            if (i >= args.len) return error.MissingOptionValue;
            result.recipient = args[i];
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else {
            return error.TooManyArguments;
        }
    }
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
        \\  envault yubikey doctor
        \\  envault yubikey list [--all]
        \\  envault yubikey setup --slot SLOT [--serial SERIAL] [--identity PATH] [--recipient PATH]
        \\  envault yubikey generate [--slot SLOT] [--serial SERIAL] [--name NAME] [--pin-policy POLICY] [--touch-policy POLICY] [--identity PATH] [--recipient PATH]
        \\
        \\Defaults:
        \\  env=dev, target=.env, source=.env
        \\  yubikey identity=~/.envault/yubikey-identity.txt
        \\  yubikey recipient=~/.envault/yubikey-recipient.txt
        \\
        \\Environment:
        \\  ENVAULT_ROOT
        \\  ENVAULT_IDENTITY
        \\  ENVAULT_RECIPIENT
        \\  ENVAULT_YUBIKEY=1
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

test "parse yubikey commands" {
    const doctor_cmd = try parse(&.{ "envault", "yubikey", "doctor" });
    try std.testing.expect(doctor_cmd.yubikey == .doctor);

    const list_cmd = try parse(&.{ "envault", "yubikey", "list", "--all" });
    try std.testing.expect(list_cmd.yubikey.list.all);

    const setup_cmd = try parse(&.{ "envault", "yubikey", "setup", "--slot", "9a", "--serial", "1234", "--identity", "id.txt", "--recipient", "recipients.txt" });
    try std.testing.expectEqualStrings("9a", setup_cmd.yubikey.setup.slot);
    try std.testing.expectEqualStrings("1234", setup_cmd.yubikey.setup.serial.?);
    try std.testing.expectEqualStrings("id.txt", setup_cmd.yubikey.setup.identity);
    try std.testing.expectEqualStrings("recipients.txt", setup_cmd.yubikey.setup.recipient);

    const generate_cmd = try parse(&.{ "envault", "yubikey", "generate", "--name", "envault", "--pin-policy", "once", "--touch-policy", "cached" });
    try std.testing.expectEqualStrings("envault", generate_cmd.yubikey.generate.name.?);
    try std.testing.expectEqualStrings("once", generate_cmd.yubikey.generate.pin_policy.?);
    try std.testing.expectEqualStrings("cached", generate_cmd.yubikey.generate.touch_policy.?);

    try std.testing.expectError(error.MissingOptionValue, parse(&.{ "envault", "yubikey" }));
    try std.testing.expectError(error.MissingOptionValue, parse(&.{ "envault", "yubikey", "setup" }));
    try std.testing.expectError(error.UnknownOption, parse(&.{ "envault", "yubikey", "list", "--bad" }));
}
