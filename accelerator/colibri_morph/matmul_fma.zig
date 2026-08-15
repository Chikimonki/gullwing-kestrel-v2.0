const std = @import("std");

/// Zig matmul with FMA optimisation for Whiskey Lake (i5-8265U)
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
                // FMA: multiply + accumulate in one instruction
                acc += @reduce(.Add, w_vec * x_vec);
            }
            
            while (i < I) : (i += 1) {
                acc += x_row[i] * w_row[i];
            }
            
            y[s * O + o] = acc;
        }
    }
}
