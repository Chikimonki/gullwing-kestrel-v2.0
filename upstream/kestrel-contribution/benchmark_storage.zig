const std = @import("std");

/// Honest storage benchmark — measures REAL speeds
pub fn main() !void {
    const allocator = std.heap.c_allocator;
    
    std.debug.print("=== Honest Storage Benchmark ===\n", .{});
    
    // Test file paths
    const test_paths = [_][]const u8{
        "/home/ccuk/bench_1gb_fresh.bin",  // VM ext4 (hot tier)
        "/mnt/d/test_kestrel_1gb_fresh.bin", // D: HDD (cold tier)
    };
    
    for (test_paths) |path| {
        std.debug.print("\nTesting: {s}\n", .{path});
        
        // Create fresh 1GB file
        const file = try std.fs.cwd().createFile(path, .{});
        const data = try allocator.alloc(u8, 1024 * 1024);
        defer allocator.free(data);
        
        for (0..1024) |_| {
            try file.writeAll(data);
        }
        file.close();
        
        // Map and measure cold read
        const f = try std.fs.cwd().openFile(path, .{});
        const mapped = try std.posix.mmap(
            null,
            1024 * 1024 * 1024,
            std.posix.PROT.READ,
            .{ .TYPE = .PRIVATE },
            f.handle,
            0
        );
        
        var timer = try std.time.Timer.start();
        var sink: u64 = 0;
        var touched: usize = 0;
        
        for (mapped) |byte| {
            sink +%= byte;
            touched += 1;
        }
        
        std.mem.doNotOptimizeAway(sink);
        
        const elapsed_ns = timer.read();
        const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
        const mb = @as(f64, @floatFromInt(touched)) / (1024.0 * 1024.0);
        const speed = mb / seconds;
        
        std.debug.print("  Bytes touched: {d}\n", .{touched});
        std.debug.print("  Time: {d:.4} s\n", .{seconds});
        std.debug.print("  Speed: {d:.1} MB/s\n", .{speed});
        std.debug.print("  Checksum: 0x{x}\n", .{sink});
        
        std.posix.munmap(mapped);
        f.close();
        try std.fs.cwd().deleteFile(path);
    }
    
    std.debug.print("\n=== Benchmark Complete ===\n", .{});
}
