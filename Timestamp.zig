//! Simple wrapper around nekto/zig-time
//!
//! This struct only parses timestamp (string) in the format of YYYY-mm-ddTHH:MM:SS.sssZ
//! all fields are as normally written; no 0-index
//!     day 1 is .day = 1
//!     janurary is .month = 1

inner: DateTime,

const std = @import("std");
const time = @import("time");
const mecha = @import("mecha");
const DateTime = time.DateTime;

test {
    std.testing.refAllDeclsRecursive(time);
}

pub fn toDateTime(this: @This()) DateTime {
    return this.inner;
}

test "toDateTime -> format" {
    const t = std.testing;
    const time0 = try parse("2000-01-01T00:00:00.000Z");
    const datetime = time0.toDateTime();
    const s = try datetime.formatAlloc(t.allocator, "YYYY-MM-DD HH:mm:ss.SSS");
    defer t.allocator.free(s);
    try t.expectEqualStrings("2000-01-01 00:00:00.000", s);
}

pub fn formatAlloc(this: @This(), alloc: std.mem.Allocator, comptime format: []const u8) ![]const u8 {
    return this.toDateTime().formatAlloc(alloc, format);
}

test "format" {
    const t = std.testing;
    const time0 = try parse("2000-01-01T00:00:00.000Z");
    const s = try time0.formatAlloc(t.allocator, "YYYY-MM-DD HH:mm:ss.SSS");
    defer t.allocator.free(s);
    try t.expectEqualStrings("2000-01-01 00:00:00.000", s);
}

pub fn parse(
    s: []const u8,
) !@This() {
    var result = (Intermediate.rule_time.parse(undefined, s) catch |err| switch (err) {
        error.ParserFailed => return error.InvalidCharacter,
        error.OutOfMemory => unreachable,
        error.OtherError => unreachable,
    }).value;
    const ms = parseMs(result.millisecond) catch |err| switch (err) {
        error.ParserFailed => return error.InvalidCharacter,
        error.OutOfMemory => unreachable,
        error.OtherError => unreachable,
    };

    const dt = DateTime{
        .years = @intCast(result.year),
        .months = result.month - 1,
        .days = result.day - 1,
        .hours = result.hour,
        .minutes = result.minute,
        .seconds = result.second,
        .ms = ms,
        .timezone = .UTC,
        .era = .AD,
    };

    return .{ .inner = dt };
}

pub fn jsonParse(
    allocator: std.mem.Allocator,
    source: *std.json.Scanner,
    options: std.json.ParseOptions,
) std.json.ParseError(@TypeOf(source.*))!@This() {
    const rawInput = try std.json.innerParse([]const u8, allocator, source, options);
    return parse(rawInput);
}

/// .sss => sss ms
/// .ss => (ss * 10) ms
/// .s => (s * 100) ms
fn parseMs(v: []const u8) !u16 {
    return switch (v.len) {
        3 => try mecha.toInt(u16, 10)(undefined, v),
        2 => (try mecha.toInt(u16, 10)(undefined, v)) * 10,
        1 => (try mecha.toInt(u16, 10)(undefined, v)) * 100,
        else => @panic("the timestamp's sub-second part is weird"),
    };
}

const Intermediate = struct {
    //! A hack, because mecha's API is rigid
    //! can only parse "%Y-%m-%dT%H:%M:%S,%N%:z",
    //
    // ISO8601 has the following formats (unsupported by this)
    // "%Y-%m-%d",
    // "%Y-%m-%dT%H:%M:%S%:z",
    // "%Y-%m-%dT%H:%M:%S,%N%:z",
    // "%Y-%m-%dT%H%:z",
    // "%Y-%m-%dT%H:%M%:z"

    year: i32,
    month: u16,
    day: u16,

    hour: u16,
    minute: u16,
    second: u16,
    millisecond: []const u8,

    const rule_i32 = mecha.int(i32, .{
        .parse_sign = true, // negative year? (BC)
        .base = 10,
    });
    const rule_u16 = mecha.int(u16, .{
        .parse_sign = false,
        .base = 10,
    });
    pub const rule_time = mecha.combine(.{
        rule_i32,
        mecha.ascii.char('-').discard(),
        rule_u16,
        mecha.ascii.char('-').discard(),
        rule_u16,

        mecha.ascii.char('T').discard(),

        rule_u16,
        mecha.ascii.char(':').discard(),
        rule_u16,
        mecha.ascii.char(':').discard(),
        rule_u16,
        mecha.ascii.char('.').discard(),
        rule_u16.asStr(),

        mecha.ascii.char('Z').discard(),
    }).map(mecha.toStruct(@This()));
};

test {
    _ = tests;
    std.testing.refAllDeclsRecursive(time);
}

const Timestamp = @This();

const tests = struct {
    const t = std.testing;

    fn testDuration(earlier: DateTime, later: DateTime, expected: []const u8) !void {
        const dur = later.since(earlier);
        const duration = try dur.formatHuman(t.allocator);
        defer t.allocator.free(duration);
        try t.expectEqualStrings(expected, duration);
    }

    test "time.Duration.formatHuman" {
        const time0 = (try parse("2000-01-01T00:00:00.000Z")).inner;
        const time1 = (try parse("2000-01-03T00:00:00.000Z")).inner;
        const time2 = (try parse("2000-01-02T00:00:00.000Z")).inner;
        const time3 = (try parse("2000-01-01T05:00:00.000Z")).inner;
        const time4 = (try parse("2000-01-01T00:03:00.000Z")).inner;
        const time5 = (try parse("2000-01-01T00:00:03.000Z")).inner;
        try testDuration(time0, time1, "2 days ago");
        try testDuration(time0, time2, "1 day ago");
        try testDuration(time0, time3, "5h ago");
        try testDuration(time0, time4, "3m ago");
        try testDuration(time0, time5, "3s ago");
    }

    test "json can deserialize string" {
        const input =
            \\"2023-09-08T16:22:06.279Z"
        ;
        const parsed = try std.json.parseFromSlice([]const u8, t.allocator, input, .{});
        defer parsed.deinit();
    }

    test "json can deserialize time" {
        const input =
            \\"2023-09-08T16:22:06.279Z"
        ;
        const parsed = try std.json.parseFromSlice(Timestamp, t.allocator, input, .{});
        defer parsed.deinit();

        const dt = parsed.value.inner;
        try t.expectEqual(@as(u16, 2023), dt.years);
        try t.expectEqual(@as(u16, 9 - 1), dt.months);
        try t.expectEqual(@as(u16, 8 - 1), dt.days);
        try t.expectEqual(@as(u16, 16), dt.hours);
        try t.expectEqual(@as(u16, 22), dt.minutes);
        try t.expectEqual(@as(u16, 6), dt.seconds);
        try t.expectEqual(@as(u16, 279), dt.ms);
    }
};
