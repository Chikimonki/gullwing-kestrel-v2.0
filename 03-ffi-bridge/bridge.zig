const std = @import("std");

/// C ABI exports for LuaJIT FFI
/// Using extern structs for exact C memory layout

// Extern structs match C ABI exactly
pub const KestrelContext = extern struct {
    total_memory: usize,
    used_memory: usize,
    initialized: bool,
};

pub const ExpertHandle = extern struct {
    expert_id: u32,
    size: usize,
    hot: bool,
};

pub const StreamHandle = extern struct {
    buffer_size: usize,
    bytes_processed: usize,
};

// Initialize context
export fn kestrel_init(total_memory: usize) ?*KestrelContext {
    const allocator = std.heap.c_allocator;
    const ctx = allocator.create(KestrelContext) catch return null;
    
    ctx.* = .{
        .total_memory = total_memory,
        .used_memory = 0,
        .initialized = true,
    };
    
    return ctx;
}

// Deinitialize context
export fn kestrel_deinit(ctx: *KestrelContext) void {
    const allocator = std.heap.c_allocator;
    allocator.destroy(ctx);
}

// Load expert
export fn kestrel_load_expert(
    ctx: *KestrelContext,
    expert_id: u32,
    data: [*]const u8,
    len: usize,
    hot: bool
) ?*ExpertHandle {
    _ = data; // Unused for now
    
    const allocator = std.heap.c_allocator;
    const handle = allocator.create(ExpertHandle) catch return null;
    
    handle.* = .{
        .expert_id = expert_id,
        .size = len,
        .hot = hot,
    };
    
    ctx.used_memory += len;
    
    return handle;
}

// Unload expert
export fn kestrel_unload_expert(handle: *ExpertHandle) void {
    const allocator = std.heap.c_allocator;
    allocator.destroy(handle);
}

// Forward pass
export fn kestrel_forward(
    ctx: *KestrelContext,
    expert_id: u32,
    input: [*]const f32,
    input_len: usize,
    output: [*]f32,
    output_len: usize
) i32 {
    _ = expert_id; // Unused for now
    _ = ctx; // Unused for now
    
    if (input_len == 0 or output_len == 0) {
        return -1;
    }
    
    // Simple copy for testing
    const copy_len = @min(input_len, output_len);
    @memcpy(output[0..copy_len], input[0..copy_len]);
    
    // Zero-fill rest
    if (output_len > copy_len) {
        @memset(output[copy_len..output_len], 0.0);
    }
    
    return 0;
}

// Create stream
export fn kestrel_stream_create(
    ctx: *KestrelContext,
    buffer_size: usize
) ?*StreamHandle {
    _ = ctx; // Unused for now
    
    if (buffer_size == 0) return null;
    
    const allocator = std.heap.c_allocator;
    const stream = allocator.create(StreamHandle) catch return null;
    
    stream.* = .{
        .buffer_size = buffer_size,
        .bytes_processed = 0,
    };
    
    return stream;
}

// Push to stream
export fn kestrel_stream_push(
    stream: *StreamHandle,
    data: [*]const u8,
    len: usize
) i32 {
    _ = data; // Unused for now
    
    if (len == 0) return -1;
    
    stream.bytes_processed += len;
    return @intCast(len);
}

// Pop from stream
export fn kestrel_stream_pop(
    stream: *StreamHandle,
    output: [*]u8,
    max_len: usize
) i32 {
    _ = stream; // Unused for now
    _ = output; // Unused for now
    _ = max_len; // Unused for now
    
    return 0; // No data for now
}

// Get memory usage
export fn kestrel_get_memory_usage(ctx: *KestrelContext) usize {
    return ctx.used_memory;
}

// Reset arena
export fn kestrel_reset_arena(ctx: *KestrelContext) void {
    ctx.used_memory = 0;
}

// Debug function to check struct sizes
export fn kestrel_debug_sizes() void {
    std.debug.print("KestrelContext size: {d}\n", .{@sizeOf(KestrelContext)});
    std.debug.print("ExpertHandle size: {d}\n", .{@sizeOf(ExpertHandle)});
    std.debug.print("StreamHandle size: {d}\n", .{@sizeOf(StreamHandle)});
}

// Simple tests
test "context init and deinit" {
    const ctx = kestrel_init(1024 * 1024).?;
    defer kestrel_deinit(ctx);
    
    try std.testing.expect(ctx.initialized);
    try std.testing.expectEqual(ctx.total_memory, 1024 * 1024);
}

test "expert load and forward" {
    const ctx = kestrel_init(1024 * 1024).?;
    defer kestrel_deinit(ctx);
    
    const data = [_]u8{1, 2, 3, 4, 5};
    const handle = kestrel_load_expert(ctx, 1, &data, data.len, true).?;
    defer kestrel_unload_expert(handle);
    
    try std.testing.expectEqual(handle.expert_id, 1);
    try std.testing.expectEqual(handle.size, 5);
    try std.testing.expect(handle.hot);
    
    const input = [_]f32{ 1.0, 2.0, 3.0 };
    var output = [_]f32{0} ** 3;
    
    const result = kestrel_forward(ctx, 1, &input, input.len, &output, output.len);
    try std.testing.expectEqual(result, 0);
    try std.testing.expectEqualSlices(f32, &input, &output);
}
