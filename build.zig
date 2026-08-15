const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });
    
    // Build shared library
    const lib = b.addSharedLibrary(.{
        .name = "kestrel",
        .root_source_file = b.path("03-ffi-bridge/bridge.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    // Link libc
    lib.linkLibC();
    
    // Install to zig-out/bin by default, but we want it in ./bin
    const install_lib = b.addInstallArtifact(lib, .{
        .dest_dir = .{ .override = .{ .custom = "bin" } },
    });
    b.getInstallStep().dependOn(&install_lib.step);
    
    // Also copy to current directory for easy access
    const copy_lib = b.addSystemCommand(&.{
        "cp",
        "zig-out/bin/libkestrel.so",
        "libkestrel.so",
    });
    copy_lib.step.dependOn(&install_lib.step);
    b.getInstallStep().dependOn(&copy_lib.step);
    
    // Tests
    const test_step = b.step("test", "Run all tests");
    
    const arena_tests = b.addTest(.{
        .root_source_file = b.path("01-memory-manager/arena.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const stream_tests = b.addTest(.{
        .root_source_file = b.path("04-streaming/stream.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const bridge_tests = b.addTest(.{
        .root_source_file = b.path("03-ffi-bridge/bridge.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    test_step.dependOn(&arena_tests.step);
    test_step.dependOn(&stream_tests.step);
    test_step.dependOn(&bridge_tests.step);
    
    // Benchmark step
    const bench_step = b.step("bench", "Run benchmarks");
    const bench_cmd = b.addSystemCommand(&.{
        "luajit",
        "05-benchmark/bench.lua",
    });
    bench_cmd.step.dependOn(&install_lib.step);
    bench_step.dependOn(&bench_cmd.step);
}
