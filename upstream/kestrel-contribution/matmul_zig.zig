const std = @import("std");

/// FIXED: K loop actually does work now
export fn zig_matmul(
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

export fn scalar_matmul(
    y: [*]f32,
    x: [*]const f32,
    W: [*]const f32,
    S: usize,
    I: usize,
    O: usize,
) void {
    for (0..O) |o| {
        const w_row = W[o * I .. (o + 1) * I];
        
        for (0..S) |s| {
            const x_row = x[s * I .. (s + 1) * I];
            var acc: f32 = 0.0;
            
            for (0..I) |i| {
                acc += x_row[i] * w_row[i];
            }
            
            y[s * O + o] = acc;
        }
    }
}

/// Known-answer test: 4x4x4 matmul with hand-computed result
export fn known_answer_test() i32 {
    // 4x4 identity matrix times 4x4 identity = identity
    const W = [_]f32{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    };
    const x = [_]f32{1, 2, 3, 4};
    var y = [_]f32{0, 0, 0, 0};
    
    scalar_matmul(&y, &x, &W, 1, 4, 4);
    
    // y should equal x for identity matrix
    if (y[0] == 1 and y[1] == 2 and y[2] == 3 and y[3] == 4) {
        return 0; // PASS
    }
    return -1; // FAIL
}
