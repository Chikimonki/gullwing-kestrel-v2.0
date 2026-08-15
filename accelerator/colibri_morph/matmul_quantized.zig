const std = @import("std");

/// Colibri's quantized matmul: y[o] = scale[o] * sum_i x[i] * q[o*I+i]
/// q is int8, scale is per-row float

export fn scalar_matmul_q(
    y: [*]f32,
    x: [*]const f32,
    q: [*]const i8,
    scale: [*]const f32,
    I: usize,
    O: usize,
) void {
    for (0..O) |o| {
        var sum: f32 = 0.0;
        const q_row = q[o * I .. (o + 1) * I];
        
        for (0..I) |i| {
            sum += x[i] * @as(f32, @floatFromInt(q_row[i]));
        }
        
        y[o] = scale[o] * sum;
    }
}

export fn zig_matmul_q(
    y: [*]f32,
    x: [*]const f32,
    q: [*]const i8,
    scale: [*]const f32,
    I: usize,
    O: usize,
) void {
    const vec_size = 8;
    
    for (0..O) |o| {
        var sum: f32 = 0.0;
        const q_row = q[o * I .. (o + 1) * I];
        
        var i: usize = 0;
        while (i + vec_size <= I) : (i += vec_size) {
            // Load 8 int8 weights and convert to f32 vector
            const q_vec: @Vector(vec_size, i8) = q_row[i..][0..vec_size].*;
            const q_f32: @Vector(vec_size, f32) = @floatFromInt(q_vec);
            
            const x_vec: @Vector(vec_size, f32) = x[i..][0..vec_size].*;
            const prod = q_f32 * x_vec;
            sum += @reduce(.Add, prod);
        }
        
        while (i < I) : (i += 1) {
            sum += x[i] * @as(f32, @floatFromInt(q_row[i]));
        }
        
        y[o] = scale[o] * sum;
    }
}
