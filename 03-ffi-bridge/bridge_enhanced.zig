const std = @import("std");
const RingBuffer = @import("../04-streaming/ring_buffer.zig").RingBuffer;

/// Enhanced C ABI exports with ring buffer support

// Extern structs for C ABI compatibility
pub const KestrelContext = extern struct {
    total_memory: usize,
    used_memory: usize,
    initialized: bool,
    ring_buffer: ?*RingBuffer,
};

pub const ExpertHandle = extern struct {
    expert_id: u32,
    size: usize,
    hot: bool,
    last_access: i64,
    access_count: u64,
};

pub const StreamHandle = extern struct {
    buffer_size: usize,
    bytes_processed: usize,
    ring_buffer: ?*RingBuffer,
};

// Initialize context with ring buffer
export fn kestrel_init_enhanced(
    total_memory: usize,
    ring_buffer_size: usize
) ?*KestrelContext {
    const allocator = std.heap.c_allocator;
    const ctx = allocator.create(KestrelContext) catch return null;
    
    // Create ring buffer
    const rb = allocator.create(RingBuffer) catch {
        allocator.destroy(ctx);
        return null;
    };
    
    rb.* = RingBuffer.init(allocator, ring_buffer_size) catch {
        allocator.destroy(rb);
        allocator.destroy(ctx);
        return null;
    };
    
    ctx.* = .{
        .total_memory = total_memory,
        .used_memory = 0,
        .initialized = true,
        .ring_buffer = rb,
    };
    
    return ctx;
}

// Stream expert weights through ring buffer
export fn kestrel_stream_expert(
    ctx: *KestrelContext,
    expert_id: u32,
    data: [*]const u8,
    len: usize
) i32 {
    _ = expert_id; // Reserved for future use
    
    if (ctx.ring_buffer) |rb| {
        const written = rb.push(data[0..len]) catch return -1;
        return @intCast(written);
    }
    return -1;
}

// Read streamed expert weights
export fn kestrel_read_stream(
    ctx: *KestrelContext,
    output: [*]u8,
    max_len: usize
) i32 {
    if (ctx.ring_buffer) |rb| {
        const read = rb.pop(output[0..max_len]) catch return -1;
        return @intCast(read);
    }
    return -1;
}

// Get ring buffer stats
export fn kestrel_get_buffer_stats(ctx: *KestrelContext) usize {
    if (ctx.ring_buffer) |rb| {
        return rb.getAvailable();
    }
    return 0;
}
