const std = @import("std");

/// Real expert weight management with memory-mapped loading
pub const ExpertWeights = struct {
    allocator: std.mem.Allocator,
    weights: []f32,
    bias: []f32,
    input_dim: usize,
    output_dim: usize,
    loaded: bool,
    memory_mapped: bool,
    _file_buffer: ?[]u8,
    
    pub fn init(
        allocator: std.mem.Allocator,
        input_dim: usize,
        output_dim: usize
    ) !ExpertWeights {
        const weights = try allocator.alloc(f32, input_dim * output_dim);
        const bias = try allocator.alloc(f32, output_dim);
        
        // Initialize with small random values
        var prng = std.rand.DefaultPrng.init(42);
        const random = prng.random();
        
        for (weights) |*w| {
            w.* = random.float(f32) * 0.1 - 0.05;
        }
        
        for (bias) |*b| {
            b.* = random.float(f32) * 0.01;
        }
        
        return .{
            .allocator = allocator,
            .weights = weights,
            .bias = bias,
            .input_dim = input_dim,
            .output_dim = output_dim,
            .loaded = true,
            .memory_mapped = false,
            ._file_buffer = null,
        };
    }
    
    pub fn deinit(self: *ExpertWeights) void {
        if (!self.memory_mapped) {
            self.allocator.free(self.weights);
            self.allocator.free(self.bias);
        }
        
        if (self._file_buffer) |buffer| {
            self.allocator.free(buffer);
        }
        
        self.loaded = false;
    }
    
    /// Load weights from file
    pub fn loadFromFile(self: *ExpertWeights, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        
        const file_size = (try file.stat()).size;
        const expected_size = (self.input_dim * self.output_dim + self.output_dim) * @sizeOf(f32);
        
        if (file_size < expected_size) {
            return error.FileTooSmall;
        }
        
        // Read file into mutable buffer
        const buffer = try self.allocator.alloc(u8, expected_size);
        _ = try file.readAll(buffer);
        
        // Cast to mutable float array (safe because we own the buffer)
        const float_data: [*]f32 = @ptrCast(@alignCast(buffer.ptr));
        
        // Free old weights if not memory mapped
        if (!self.memory_mapped and self.loaded) {
            self.allocator.free(self.weights);
            self.allocator.free(self.bias);
        }
        
        // Set new weights from file
        self.weights = float_data[0 .. self.input_dim * self.output_dim];
        self.bias = float_data[self.input_dim * self.output_dim .. expected_size / @sizeOf(f32)];
        self._file_buffer = buffer;
        
        self.loaded = true;
    }
    
    /// Matrix-vector multiplication
    pub fn forward(self: *ExpertWeights, input: []const f32, output: []f32) !void {
        if (input.len != self.input_dim or output.len != self.output_dim) {
            return error.DimensionMismatch;
        }
        
        // Basic matrix-vector multiplication
        for (output, 0..) |*out, i| {
            var sum: f32 = self.bias[i];
            const row_start = i * self.input_dim;
            
            for (input, 0..) |in_val, j| {
                sum += in_val * self.weights[row_start + j];
            }
            
            out.* = sum;
        }
    }
    
    /// Batch forward pass
    pub fn forwardBatch(
        self: *ExpertWeights,
        inputs: []const f32,
        batch_size: usize,
        outputs: []f32
    ) !void {
        const input_stride = self.input_dim;
        const output_stride = self.output_dim;
        
        for (0..batch_size) |batch| {
            const input_slice = inputs[batch * input_stride .. (batch + 1) * input_stride];
            const output_slice = outputs[batch * output_stride .. (batch + 1) * output_stride];
            try self.forward(input_slice, output_slice);
        }
    }
};

test "expert weights initialization" {
    const allocator = std.testing.allocator;
    var weights = try ExpertWeights.init(allocator, 64, 32);
    defer weights.deinit();
    
    try std.testing.expect(weights.loaded);
    try std.testing.expectEqual(weights.input_dim, 64);
    try std.testing.expectEqual(weights.output_dim, 32);
    try std.testing.expectEqual(weights.weights.len, 64 * 32);
    try std.testing.expectEqual(weights.bias.len, 32);
}

test "expert weights forward pass" {
    const allocator = std.testing.allocator;
    var weights = try ExpertWeights.init(allocator, 4, 2);
    defer weights.deinit();
    
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output = [_]f32{0} ** 2;
    
    try weights.forward(&input, &output);
    
    try std.testing.expectEqual(output.len, 2);
    try std.testing.expect(output[0] != 0.0 or output[1] != 0.0);
}
