const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod_time = b.addModule("time", .{
        .source_file = .{ .path = "time.zig" },
    });

    const mod_mecha = b.addModule("mecha", .{
        .source_file = .{ .path = "mecha/mecha.zig" },
    });

    const mod_Timestamp = b.addModule("Timestamp", .{
        .source_file = .{ .path = "Timestamp.zig" },
        .dependencies = &.{
            .{
                .name = "time",
                .module = mod_time,
            },
            .{
                .name = "mecha",
                .module = mod_mecha,
            },
        },
    });

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "test_wrapper.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.addModule("Timestamp", mod_Timestamp);

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
