// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// Copyright 2018 Geofrey Ernest MIT LICENSE

const std = @import("std");
const time = @import("time.zig");
const timezone = @import("timezone.zig");
const mem = std.mem;
const warn = std.debug.warn;

const January = time.Month.January;
const April = time.Month.April;
const September = time.Month.September;
const December = time.Month.December;
const Monday = time.Weekday.Monday;
const Wednesday = time.Weekday.Wednesday;
const Thursday = time.Weekday.Thursday;
const Saturday = time.Weekday.Saturday;
const Sunday = time.Weekday.Sunday;

const parsedTime = struct {
    year: isize,
    month: time.Month,
    day: isize,
    hour: isize,
    minute: isize,
    second: isize,
    nanosecond: isize,
    weekday: time.Weekday,
    zone_offset: isize,
    zone: []const u8,

    fn init(year: isize, month: time.Month, day: isize, hour: isize, minute: isize, second: isize, nanosecond: isize, weekday: time.Weekday, zone_offset: isize, zone: []const u8) parsedTime {
        return parsedTime{
            .year = year,
            .month = month,
            .day = day,
            .hour = hour,
            .minute = minute,
            .second = second,
            .nanosecond = nanosecond,
            .weekday = weekday,
            .zone_offset = zone_offset,
            .zone = zone,
        };
    }
};

const TimeTest = struct {
    seconds: i64,
    golden: parsedTime,
};

const utc_tests = []TimeTest{
    TimeTest{ .seconds = 0, .golden = parsedTime.init(1970, January, 1, 0, 0, 0, 0, Thursday, 0, "UTC") },
    TimeTest{ .seconds = 1221681866, .golden = parsedTime.init(2008, September, 17, 20, 4, 26, 0, Wednesday, 0, "UTC") },
    TimeTest{ .seconds = -1221681866, .golden = parsedTime.init(1931, April, 16, 3, 55, 34, 0, Thursday, 0, "UTC") },
    TimeTest{ .seconds = -11644473600, .golden = parsedTime.init(1601, January, 1, 0, 0, 0, 0, Monday, 0, "UTC") },
    TimeTest{ .seconds = 599529660, .golden = parsedTime.init(1988, December, 31, 0, 1, 0, 0, Saturday, 0, "UTC") },
    TimeTest{ .seconds = 978220860, .golden = parsedTime.init(2000, December, 31, 0, 1, 0, 0, Sunday, 0, "UTC") },
};

fn same(t: time.Time, u: *parsedTime) bool {
    const date = t.date();
    const clock = t.clock();
    const zone = t.zone();
    const check = date.year != u.year or @enumToInt(date.month) != @enumToInt(u.month) or
        date.day != u.day or clock.hour != u.hour or clock.min != u.minute or clock.sec != u.second or
        !mem.eql(u8, zone.?.name, u.zone) or zone.?.offset != u.zone_offset;
    if (check) {
        return false;
    }
    return t.year() == u.year and
        @enumToInt(t.month()) == @enumToInt(u.month) and
        t.day() == u.day and
        t.hour() == u.hour and
        t.minute() == u.minute and
        t.second() == u.second and
        t.nanosecond() == u.nanosecond and
        @enumToInt(t.weekday()) == @enumToInt(u.weekday);
}

test "TestSecondsToUTC" {
    for (utc_tests) |ts| {
        var tm = time.unix(ts.seconds, 0, timezone.utc_local);
        const ns = tm.unix();
        if (ns != ts.seconds) {
            warn("SecondsToUTC({}).Seconds() = {}\n", ts.seconds, ns);
            return error.WrongUnixSeconds;
        }
        var golden = ts.golden;
        if (!same(tm, &golden)) {
            warn("wrong utc time\n");
            return error.WrongUTCTime;
        }
    }
}

const formatTest = struct {
    name: []const u8,
    format: []const u8,
    result: []const u8,

    fn init(name: []const u8, format: []const u8, result: []const u8) formatTest {
        return formatTest{ .name = name, .format = format, .result = result };
    }
};

const format_tests = []formatTest{
    formatTest.init("ANSIC", time.ANSIC, "Wed Feb  4 21:00:57 2009"),
    formatTest.init("UnixDate", time.UnixDate, "Wed Feb  4 21:00:57 PST 2009"),
    formatTest.init("RubyDate", time.RubyDate, "Wed Feb 04 21:00:57 -0800 2009"),
    formatTest.init("RFC822", time.RFC822, "04 Feb 09 21:00 PST"),
    formatTest.init("RFC850", time.RFC850, "Wednesday, 04-Feb-09 21:00:57 PST"),
    formatTest.init("RFC1123", time.RFC1123, "Wed, 04 Feb 2009 21:00:57 PST"),
    formatTest.init("RFC1123Z", time.RFC1123Z, "Wed, 04 Feb 2009 21:00:57 -0800"),
    formatTest.init("RFC3339", time.RFC3339, "2009-02-04T21:00:57-08:00"),
    formatTest.init("RFC3339Nano", time.RFC3339Nano, "2009-02-04T21:00:57.0123456-08:00"),
    formatTest.init("Kitchen", time.Kitchen, "9:00PM"),
    formatTest.init("am/pm", "3pm", "9pm"),
    formatTest.init("AM/PM", "3PM", "9PM"),
    formatTest.init("two-digit year", "06 01 02", "09 02 04"),
    // Three-letter months and days must not be followed by lower-case letter.
    formatTest.init("Janet", "Hi Janet, the Month is January", "Hi Janet, the Month is February"),
    // Time stamps, Fractional seconds.
    formatTest.init("Stamp", time.Stamp, "Feb  4 21:00:57"),
    formatTest.init("StampMilli", time.StampMilli, "Feb  4 21:00:57.012"),
    formatTest.init("StampMicro", time.StampMicro, "Feb  4 21:00:57.012345"),
    formatTest.init("StampNano", time.StampNano, "Feb  4 21:00:57.012345600"),
};

test "TestFormat" {
    var ts = time.unix(0, 1233810057012345600, timezone.utc_local);
    var buf = try std.Buffer.init(std.debug.global_allocator, "");
    defer buf.deinit();
    for (format_tests) |value| {
        try ts.format(&buf, value.format);
        warn("{}: formtat = {} output= {}\n", value.name, value.format, buf.toSlice());
    }
}