const std = @import("std");

/// Cache-blocked (tiled) matmul with FMA
/// Blocks of 64x64 fit in L1 cache (32KB), 256x256 in L2 (1MB)
const BLOCK = 64;

export fn zig_matmul_blocked(
    y: [*]f32,
    x: [*]const f32,
    W: [*]const f32,
    S: usize,
    I: usize,
    O: usize,
) void {
    const vec_size = 8;
    
    // Cache-blocked: process O in blocks
    var o_block: usize = 0;
    while (o_block < O) : (o_block += BLOCK) {
        const o_end = @min(o_block + BLOCK, O);
        
        for (0..S) |s| {
            const x_row = x[s * I .. (s + 1) * I];
            
            for (o_block..o_end) |o| {
                const w_row = W[o * I .. (o + 1) * I];
                var acc: f32 = 0.0;
                
                var i: usize = 0;
                while (i + vec_size <= I) : (i += vec_size) {
                    const w_vec: @Vector(vec_size, f32) = w_row[i..][0..vec_size].*;
                    const x_vec: @Vector(vec_size, f32) = x_row[i..][0..vec_size].*;
                    // FMA happens automatically with @mulAdd
                    acc += @reduce(.Add, @mulAdd(@Vector(vec_size, f32), w_vec, x_vec, @as(@Vector(vec_size, f32), @splat(0))));
                }
                
                while (i < I) : (i += 1) {
                    acc += x_row[i] * w_row[i];
                }
                
                y[s * O + o] = acc;
            }
        }
    }
}

/// FMA-only version (no blocking)
export fn zig_matmul_fma(
    y: [*]f32,
    x: [*]const f32,
    W: [*]const f32,
    S: usize,
    I: usize,
    O: usize,
) void {
    const vec_size = 8;
    
    for (0..O) |o| {
        const w_row = W[o * I .. (o + 1) * I];
        
        for (0..S) |s| {
            const x_row = x[s * I .. (s + 1) * I];
            var acc: f32 = 0.0;
            
            var i: usize = 0;
            while (i + vec_size <= I) : (i += vec_size) {
                const w_vec: @Vector(vec_size, f32) = w_row[i..][0..vec_size].*;
                const x_vec: @Vector(vec_size, f32) = x_row[i..][0..vec_size].*;
                const prod = w_vec * x_vec;
                acc += @reduce(.Add, prod);
            }
            
            while (i < I) : (i += 1) {
                acc += x_row[i] * w_row[i];
            }
            
            y[s * O + o] = acc;
        }
    }
}
