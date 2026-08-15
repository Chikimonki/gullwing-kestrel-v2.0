const std = @import("std");
const ExpertWeights = @import("expert_weights.zig").ExpertWeights;

/// Kestrel v2.0 Bridge with Real Expert Weights

pub const KestrelContext = extern struct {
    total_memory: usize,
    used_memory: usize,
    initialized: bool,
    num_experts: u32,
};

pub const ExpertHandle = extern struct {
    expert_id: u32,
    input_dim: usize,
    output_dim: usize,
    hot: bool,
    weights_ptr: ?*ExpertWeights,
};

// Internal state
var expert_registry: ?std.AutoHashMap(u32, *ExpertWeights) = null;
var global_allocator: std.mem.Allocator = undefined;

// Initialize with expert registry
export fn kestrel_init_v2(total_memory: usize) ?*KestrelContext {
    const allocator = std.heap.c_allocator;
    global_allocator = allocator;
    
    const ctx = allocator.create(KestrelContext) catch return null;
    ctx.* = .{
        .total_memory = total_memory,
        .used_memory = 0,
        .initialized = true,
        .num_experts = 0,
    };
    
    // Initialize expert registry
    expert_registry = std.AutoHashMap(u32, *ExpertWeights).init(allocator);
    
    return ctx;
}

// Create expert with real weights
export fn kestrel_create_expert(
    ctx: *KestrelContext,
    expert_id: u32,
    input_dim: usize,
    output_dim: usize,
    hot: bool
) ?*ExpertHandle {
    const allocator = global_allocator;
    
    // Create weights
    const weights = allocator.create(ExpertWeights) catch return null;
    weights.* = ExpertWeights.init(allocator, input_dim, output_dim) catch {
        allocator.destroy(weights);
        return null;
    };
    
    // Create handle
    const handle = allocator.create(ExpertHandle) catch return null;
    handle.* = .{
        .expert_id = expert_id,
        .input_dim = input_dim,
        .output_dim = output_dim,
        .hot = hot,
        .weights_ptr = weights,
    };
    
    // Register in registry
    if (expert_registry) |*registry| {
        registry.put(expert_id, weights) catch {
            allocator.destroy(handle);
            return null;
        };
    }
    
    ctx.num_experts += 1;
    ctx.used_memory += (input_dim * output_dim + output_dim) * @sizeOf(f32);
    
    return handle;
}

// Load expert weights from file
export fn kestrel_load_expert_file(
    handle: *ExpertHandle,
    path: [*:0]const u8
) i32 {
    if (handle.weights_ptr) |weights| {
        const path_slice = std.mem.span(path);
        weights.loadFromFile(path_slice) catch return -1;
        return 0;
    }
    return -1;
}

// Forward pass with real matrix multiplication
export fn kestrel_forward_v2(
    ctx: *KestrelContext,
    handle: *ExpertHandle,
    input: [*]const f32,
    input_len: usize,
    output: [*]f32,
    output_len: usize
) i32 {
    _ = ctx;
    
    if (handle.weights_ptr) |weights| {
        const input_slice = input[0..input_len];
        const output_slice = output[0..output_len];
        
        weights.forward(input_slice, output_slice) catch return -1;
        return 0;
    }
    
    return -1;
}

// Get expert info
export fn kestrel_get_expert_info(
    handle: *ExpertHandle,
    input_dim: *usize,
    output_dim: *usize,
    hot: *bool
) void {
    input_dim.* = handle.input_dim;
    output_dim.* = handle.output_dim;
    hot.* = handle.hot;
}

// Cleanup
export fn kestrel_deinit_v2(ctx: *KestrelContext) void {
    const allocator = global_allocator;
    
    if (expert_registry) |*registry| {
        var it = registry.valueIterator();
        while (it.next()) |weights_ptr| {
            weights_ptr.*.deinit();
            allocator.destroy(weights_ptr.*);
        }
        registry.deinit();
        expert_registry = null;
    }
    
    allocator.destroy(ctx);
}
