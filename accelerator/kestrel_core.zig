const std = @import("std");

pub const Accelerator = struct {
    allocator: std.mem.Allocator,
    model_data: ?[]align(4096) u8,
    model_size: usize,
    loaded: bool,
    checksum: u64,
    bytes_touched: usize,
    
    pub fn init(allocator: std.mem.Allocator) Accelerator {
        return .{
            .allocator = allocator,
            .model_data = null,
            .model_size = 0,
            .loaded = false,
            .checksum = 0,
            .bytes_touched = 0,
        };
    }
    
    pub fn loadModel(self: *Accelerator, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        
        const file_size = (try file.stat()).size;
        
        const mapped = try std.posix.mmap(
            null,
            file_size,
            std.posix.PROT.READ,
            .{ .TYPE = .PRIVATE },
            file.handle,
            0
        );
        
        self.model_data = mapped;
        self.model_size = file_size;
        self.loaded = true;
    }
    
    pub fn benchmarkRead(self: *Accelerator, bytes_to_read: usize) !f64 {
        if (!self.loaded or self.model_data == null) {
            return error.NotLoaded;
        }
        
        const data = self.model_data.?;
        const read_len = @min(bytes_to_read, data.len);
        
        var timer = try std.time.Timer.start();
        var sink: u64 = 0;
        var touched: usize = 0;
        
        // Touch every byte and COUNT what we touch
        for (data[0..read_len]) |byte| {
            sink +%= byte;
            touched += 1;
        }
        
        std.mem.doNotOptimizeAway(sink);
        self.checksum = sink;
        self.bytes_touched = touched;
        
        const elapsed_ns = timer.read();
        const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
        
        // Speed in MB/s using ACTUAL bytes touched
        const mb = @as(f64, @floatFromInt(touched)) / (1024.0 * 1024.0);
        return mb / seconds;
    }
    
    pub fn deinit(self: *Accelerator) void {
        if (self.model_data) |data| {
            std.posix.munmap(data);
        }
        self.loaded = false;
    }
};

var global_accel: ?*Accelerator = null;

export fn kestrel_accel_create() ?*anyopaque {
    const allocator = std.heap.c_allocator;
    const accel = allocator.create(Accelerator) catch return null;
    accel.* = Accelerator.init(allocator);
    global_accel = accel;
    return accel;
}

export fn kestrel_accel_load(path: [*:0]const u8) i32 {
    if (global_accel) |accel| {
        const path_slice = std.mem.span(path);
        accel.loadModel(path_slice) catch return -1;
        return 0;
    }
    return -1;
}

export fn kestrel_accel_benchmark_read(bytes: usize) f64 {
    if (global_accel) |accel| {
        return accel.benchmarkRead(bytes) catch return -1.0;
    }
    return -1.0;
}

export fn kestrel_accel_get_checksum() u64 {
    if (global_accel) |accel| {
        return accel.checksum;
    }
    return 0;
}

export fn kestrel_accel_get_bytes_touched() usize {
    if (global_accel) |accel| {
        return accel.bytes_touched;
    }
    return 0;
}

export fn kestrel_accel_destroy() void {
    const allocator = std.heap.c_allocator;
    if (global_accel) |accel| {
        accel.deinit();
        allocator.destroy(accel);
        global_accel = null;
    }
}
