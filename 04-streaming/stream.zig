const std = @import("std");

/// Cache-line aligned ring buffer for zero-copy streaming
pub const RingBuffer = struct {
    buffer: []align(64) u8,
    capacity: usize,
    head: std.atomic.Value(usize) align(64),
    tail: std.atomic.Value(usize) align(64),
    write_lock: std.atomic.Value(bool) align(64),
    read_lock: std.atomic.Value(bool) align(64),
    
    pub fn init(
        allocator: std.mem.Allocator,
        capacity: usize
    ) !RingBuffer {
        // Round capacity to cache line
        const aligned_capacity = (capacity + 63) & ~@as(usize, 63);
        
        const buffer = try allocator.alignedAlloc(
            u8,
            64,
            aligned_capacity
        );
        
        return .{
            .buffer = buffer,
            .capacity = aligned_capacity,
            .head = std.atomic.Value(usize).init(0),
            .tail = std.atomic.Value(usize).init(0),
            .write_lock = std.atomic.Value(bool).init(false),
            .read_lock = std.atomic.Value(bool).init(false),
        };
    }
    
    pub fn deinit(self: *RingBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }
    
    /// Lock-free push for single producer
    pub fn push(self: *RingBuffer, data: []const u8) !usize {
        const head = self.head.load(.acquire);
        const tail = self.tail.load(.acquire);
        
        const free_space = self.freeSpace(head, tail);
        if (free_space < data.len) {
            return error.BufferFull;
        }
        
        const write_pos = head % self.capacity;
        const first_chunk = @min(data.len, self.capacity - write_pos);
        
        // Write first chunk
        @memcpy(
            self.buffer[write_pos..][0..first_chunk],
            data[0..first_chunk]
        );
        
        // Write wrap-around chunk if needed
        if (first_chunk < data.len) {
            @memcpy(
                self.buffer[0..][0..(data.len - first_chunk)],
                data[first_chunk..]
            );
        }
        
        // Memory barrier before updating head
        @fence(.release);
        self.head.store(head + data.len, .release);
        
        return data.len;
    }
    
    /// Lock-free pop for single consumer
    pub fn pop(self: *RingBuffer, out: []u8) !usize {
        const head = self.head.load(.acquire);
        const tail = self.tail.load(.acquire);
        
        const available = head - tail;
        if (available == 0) {
            return 0; // Empty
        }
        
        const read_len = @min(out.len, available);
        const read_pos = tail % self.capacity;
        const first_chunk = @min(read_len, self.capacity - read_pos);
        
        // Read first chunk
        @memcpy(
            out[0..first_chunk],
            self.buffer[read_pos..][0..first_chunk]
        );
        
        // Read wrap-around chunk if needed
        if (first_chunk < read_len) {
            @memcpy(
                out[first_chunk..read_len],
                self.buffer[0..][0..(read_len - first_chunk)]
            );
        }
        
        // Memory barrier before updating tail
        @fence(.acquire);
        self.tail.store(tail + read_len, .release);
        
        return read_len;
    }
    
    fn freeSpace(self: *RingBuffer, head: usize, tail: usize) usize {
        const used = head - tail;
        return self.capacity - used - 1; // Leave one slot for full/empty detection
    }
    
    pub fn available(self: *RingBuffer) usize {
        const head = self.head.load(.acquire);
        const tail = self.tail.load(.acquire);
        return head - tail;
    }
    
    pub fn clear(self: *RingBuffer) void {
        self.head.store(0, .release);
        self.tail.store(0, .release);
    }
};

/// Multi-producer/multi-consumer ring buffer with spin locks
pub const MPMCRingBuffer = struct {
    inner: RingBuffer,
    write_spin: std.atomic.Value(bool) align(64),
    read_spin: std.atomic.Value(bool) align(64),
    
    pub fn init(
        allocator: std.mem.Allocator,
        capacity: usize
    ) !MPMCRingBuffer {
        return .{
            .inner = try RingBuffer.init(allocator, capacity),
            .write_spin = std.atomic.Value(bool).init(false),
            .read_spin = std.atomic.Value(bool).init(false),
        };
    }
    
    pub fn push(self: *MPMCRingBuffer, data: []const u8) !usize {
        // Acquire write lock
        while (self.write_spin.swap(true, .acquire)) {
            std.atomic.spinLoopHint();
        }
        defer self.write_spin.store(false, .release);
        
        return self.inner.push(data);
    }
    
    pub fn pop(self: *MPMCRingBuffer, out: []u8) !usize {
        // Acquire read lock
        while (self.read_spin.swap(true, .acquire)) {
            std.atomic.spinLoopHint();
        }
        defer self.read_spin.store(false, .release);
        
        return self.inner.pop(out);
    }
};

/// Expert weight streaming buffer
pub const ExpertStream = struct {
    buffer: RingBuffer,
    current_expert: u32,
    bytes_loaded: usize,
    total_bytes: usize,
    
    pub fn init(
        allocator: std.mem.Allocator,
        expert_id: u32,
        total_size: usize
    ) !ExpertStream {
        const stream_buffer_size = 16 * 1024 * 1024; // 16MB chunks
        
        return .{
            .buffer = try RingBuffer.init(allocator, stream_buffer_size),
            .current_expert = expert_id,
            .bytes_loaded = 0,
            .total_bytes = total_size,
        };
    }
    
    pub fn streamChunk(
        self: *ExpertStream,
        chunk: []const u8
    ) !void {
        _ = try self.buffer.push(chunk);
        self.bytes_loaded += chunk.len;
    }
    
    pub fn readChunk(
        self: *ExpertStream,
        output: []u8
    ) !usize {
        return self.buffer.pop(output);
    }
    
    pub fn progress(self: *ExpertStream) f32 {
        if (self.total_bytes == 0) return 1.0;
        return @as(f32, @floatFromInt(self.bytes_loaded)) / 
               @as(f32, @floatFromInt(self.total_bytes));
    }
};

test "ring buffer basic operations" {
    const allocator = std.testing.allocator;
    var buffer = try RingBuffer.init(allocator, 1024);
    defer buffer.deinit(allocator);
    
    // Test push/pop
    const test_data = "Hello, Kestrel!";
    const written = try buffer.push(test_data);
    try std.testing.expectEqual(written, test_data.len);
    
    var output: [64]u8 = undefined;
    const read = try buffer.pop(&output);
    try std.testing.expectEqual(read, test_data.len);
    try std.testing.expectEqualSlices(
        u8,
        test_data,
        output[0..read]
    );
}

test "ring buffer wrap-around" {
    const allocator = std.testing.allocator;
    var buffer = try RingBuffer.init(allocator, 64);
    defer buffer.deinit(allocator);
    
    // Fill buffer to force wrap-around
    var data: [48]u8 = undefined;
    for (&data, 0..) |*byte, i| {
        byte.* = @intCast(i);
    }
    
    _ = try buffer.push(&data);
    
    var output: [64]u8 = undefined;
    const read = try buffer.pop(&output);
    try std.testing.expectEqual(read, data.len);
    try std.testing.expectEqualSlices(
        u8,
        &data,
        output[0..read]
    );
    
    // Test wrap-around with second write
    const more_data = "wrap";
    _ = try buffer.push(more_data);
    
    const read2 = try buffer.pop(&output);
    try std.testing.expectEqual(read2, more_data.len);
    try std.testing.expectEqualSlices(
        u8,
        more_data,
        output[0..read2]
    );
}
