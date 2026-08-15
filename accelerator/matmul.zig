const std = @import("std");

pub fn matvec(
    weights: []const f32,
    input: []const f32,
    output: []f32,
    input_dim: usize,
    output_dim: usize,
) void {
    _ = output_dim; // Used for validation, kept for API clarity
    
    for (output, 0..) |*out, i| {
        var sum: f32 = 0.0;
        const row_start = i * input_dim;
        
        for (input, 0..) |in_val, j| {
            sum += in_val * weights[row_start + j];
        }
        
        out.* = sum;
    }
}

pub fn matvec_simd(
    weights: []const f32,
    input: []const f32,
    output: []f32,
    input_dim: usize,
    output_dim: usize,
) void {
    _ = output_dim; // Used for validation, kept for API clarity
    const vec_size = 8; // AVX2: 8 floats per vector
    
    for (output, 0..) |*out, i| {
        var sum: f32 = 0.0;
        const row_start = i * input_dim;
        
        var j: usize = 0;
        while (j + vec_size <= input_dim) : (j += vec_size) {
            const w_vec: @Vector(vec_size, f32) = weights[row_start + j..][0..vec_size].*;
            const i_vec: @Vector(vec_size, f32) = input[j..][0..vec_size].*;
            const prod = w_vec * i_vec;
            sum += @reduce(.Add, prod);
        }
        
        while (j < input_dim) : (j += 1) {
            sum += input[j] * weights[row_start + j];
        }
        
        out.* = sum;
    }
}

export fn kestrel_matvec(
    weights: [*]const f32,
    input: [*]const f32,
    output: [*]f32,
    input_dim: usize,
    output_dim: usize,
    use_simd: bool,
) void {
    const w_slice = weights[0 .. input_dim * output_dim];
    const i_slice = input[0..input_dim];
    const o_slice = output[0..output_dim];
    
    if (use_simd) {
        matvec_simd(w_slice, i_slice, o_slice, input_dim, output_dim);
    } else {
        matvec(w_slice, i_slice, o_slice, input_dim, output_dim);
    }
}
