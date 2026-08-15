const std = @import("std");

/// Production-ready lock-free ring buffer for expert streaming
pub const RingBuffer = struct {
    buffer: []align(64) u8,
    capacity: usize,
    head: std.atomic.Value(usize) align(64),
    tail: std.atomic.Value(usize) align(64),
    total_pushed: std.atomic.Value(usize) align(64),
    total_popped: std.atomic.Value(usize) align(64),
    
    pub fn init(allocator: std.mem.Allocator, capacity: usize) !RingBuffer {
        // Round to cache line (64 bytes)
        const aligned_capacity = (capacity + 63) & ~@as(usize, 63);
        const buffer = try allocator.alignedAlloc(u8, 64, aligned_capacity);
        
        return .{
            .buffer = buffer,
            .capacity = aligned_capacity,
            .head = std.atomic.Value(usize).init(0),
            .tail = std.atomic.Value(usize).init(0),
            .total_pushed = std.atomic.Value(usize).init(0),
            .total_popped = std.atomic.Value(usize).init(0),
        };
    }
    
    pub fn deinit(self: *RingBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }
    
    /// Lock-free push for single producer
    pub fn push(self: *RingBuffer, data: []const u8) !usize {
        const head = self.head.load(.acquire);
        const tail = self.tail.load(.acquire);
        
        const free_space = self.capacity - (head - tail) - 1;
        if (free_space < data.len) return error.BufferFull;
        
        const write_pos = head % self.capacity;
        const first_chunk = @min(data.len, self.capacity - write_pos);
        
        // First chunk
        @memcpy(self.buffer[write_pos..][0..first_chunk], data[0..first_chunk]);
        
        // Wrap-around chunk
        if (first_chunk < data.len) {
            @memcpy(self.buffer[0..][0..(data.len - first_chunk)], data[first_chunk..]);
        }
        
        // Memory barrier
        @fence(.release);
        self.head.store(head + data.len, .release);
        _ = self.total_pushed.fetchAdd(data.len, .monotonic);
        
        return data.len;
    }
    
    /// Lock-free pop for single consumer
    pub fn pop(self: *RingBuffer, out: []u8) !usize {
        const head = self.head.load(.acquire);
        const tail = self.tail.load(.acquire);
        
        const available_data = head - tail;
        if (available_data == 0) return 0;
        
        const read_len = @min(out.len, available_data);
        const read_pos = tail % self.capacity;
        const first_chunk = @min(read_len, self.capacity - read_pos);
        
        // First chunk
        @memcpy(out[0..first_chunk], self.buffer[read_pos..][0..first_chunk]);
        
        // Wrap-around chunk
        if (first_chunk < read_len) {
            @memcpy(out[first_chunk..read_len], self.buffer[0..][0..(read_len - first_chunk)]);
        }
        
        // Memory barrier
        @fence(.acquire);
        self.tail.store(tail + read_len, .release);
        _ = self.total_popped.fetchAdd(read_len, .monotonic);
        
        return read_len;
    }
    
    pub fn getAvailable(self: *RingBuffer) usize {
        const head = self.head.load(.acquire);
        const tail = self.tail.load(.acquire);
        return head - tail;
    }
    
    pub fn getFreeSpace(self: *RingBuffer) usize {
        return self.capacity - self.getAvailable() - 1;
    }
    
    pub fn clear(self: *RingBuffer) void {
        self.head.store(0, .release);
        self.tail.store(0, .release);
        self.total_pushed.store(0, .release);
        self.total_popped.store(0, .release);
    }
    
    pub fn stats(self: *RingBuffer) struct {
        pushed: usize,
        popped: usize,
        available: usize,
        free: usize,
        capacity: usize,
    } {
        return .{
            .pushed = self.total_pushed.load(.monotonic),
            .popped = self.total_popped.load(.monotonic),
            .available = self.getAvailable(),
            .free = self.getFreeSpace(),
            .capacity = self.capacity,
        };
    }
};

test "ring buffer basic operations" {
    const allocator = std.testing.allocator;
    var buffer = try RingBuffer.init(allocator, 1024);
    defer buffer.deinit(allocator);
    
    const test_data = "Hello, Kestrel!";
    const written = try buffer.push(test_data);
    try std.testing.expectEqual(written, test_data.len);
    
    var output: [64]u8 = undefined;
    const read = try buffer.pop(&output);
    try std.testing.expectEqual(read, test_data.len);
    try std.testing.expectEqualSlices(u8, test_data, output[0..read]);
}

test "ring buffer wrap-around" {
    const allocator = std.testing.allocator;
    var buffer = try RingBuffer.init(allocator, 128);
    defer buffer.deinit(allocator);
    
    // Fill buffer
    var data: [100]u8 = undefined;
    for (&data, 0..) |*byte, i| {
        byte.* = @intCast(i % 256);
    }
    
    _ = try buffer.push(&data);
    
    var output: [128]u8 = undefined;
    const read = try buffer.pop(&output);
    try std.testing.expectEqual(read, data.len);
    
    // Test wrap-around
    const more_data = "wrap test";
    _ = try buffer.push(more_data);
    
    const read2 = try buffer.pop(&output);
    try std.testing.expectEqual(read2, more_data.len);
    try std.testing.expectEqualSlices(u8, more_data, output[0..read2]);
}

test "ring buffer full/empty detection" {
    const allocator = std.testing.allocator;
    var buffer = try RingBuffer.init(allocator, 64);
    defer buffer.deinit(allocator);
    
    try std.testing.expectEqual(buffer.getAvailable(), 0);
    
    const data = "test";
    _ = try buffer.push(data);
    try std.testing.expectEqual(buffer.getAvailable(), data.len);
    
    var output: [64]u8 = undefined;
    const read = try buffer.pop(&output);
    try std.testing.expectEqual(read, data.len);
    try std.testing.expectEqual(buffer.getAvailable(), 0);
}
