# Kestrel v2.0 — Zig/LuaJIT FFI Inference Engine

## Architecture
- **Zig comptime allocators** — arena-based memory, zero fragmentation, deterministic
- **LuaJIT FFI direct calls** — no serialisation, in-process, zero-copy
- **Ring buffers for streaming** — Zig-native, lock-free where possible
- **ICM-structured codebase** — navigable, auditable, agent-friendly

## Target
- Sub-25GB RAM (compile-time memory budgeting)
- Faster inference (LuaJIT JIT-compiled hot paths)
- In-process with Gullwing (native component, not subprocess)

## Building
```bash
./build.sh
./test_kestrel.sh

## Phase 3: Core Zig Implementation

Let's start with the memory manager:

```bash
cat > /mnt/d/moabi/gullwing-kestrel/01-memory-manager/arena.zig << 'EOF'
const std = @import("std");

/// Compile-time memory budget (25GB total)
pub const MEMORY_BUDGET = struct {
    pub const TOTAL_RAM: usize = 25 * 1024 * 1024 * 1024; // 25GB
    
    // Compile-time allocation percentages
    pub const EXPERT_CACHE_PCT = 60;
    pub const ROUTER_ARENA_PCT = 15;
    pub const STREAM_BUFFER_PCT = 10;
    pub const FFI_OVERHEAD_PCT = 5;
    pub const SYSTEM_RESERVE_PCT = 10;
    
    // Computed budgets
    pub const EXPERT_CACHE: usize = TOTAL_RAM * EXPERT_CACHE_PCT / 100;
    pub const ROUTER_ARENA: usize = TOTAL_RAM * ROUTER_ARENA_PCT / 100;
    pub const STREAM_BUFFER: usize = TOTAL_RAM * STREAM_BUFFER_PCT / 100;
    pub const FFI_OVERHEAD: usize = TOTAL_RAM * FFI_OVERHEAD_PCT / 100;
    pub const SYSTEM_RESERVE: usize = TOTAL_RAM * SYSTEM_RESERVE_PCT / 100;
    
    comptime {
        // Verify budget allocation
        const total = EXPERT_CACHE + ROUTER_ARENA + 
                      STREAM_BUFFER + FFI_OVERHEAD + 
                      SYSTEM_RESERVE;
        
        if (total != TOTAL_RAM) {
            @compileError("Memory budget exceeds 25GB limit");
        }
        
        if (EXPERT_CACHE + ROUTER_ARENA + STREAM_BUFFER + 
            FFI_OVERHEAD + SYSTEM_RESERVE > TOTAL_RAM) {
            @compileError("Memory allocation exceeds available RAM");
        }
    }
};

/// Arena allocator with compile-time size constraints
pub const KestrelArena = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    name: []const u8,
    budget: usize,
    used: usize = 0,
    
    pub fn init(
        comptime name: []const u8,
        comptime budget: usize,
        child_allocator: std.mem.Allocator
    ) KestrelArena {
        return .{
            .allocator = undefined,
            .arena = std.heap.ArenaAllocator.init(child_allocator),
            .name = name,
            .budget = budget,
        };
    }
    
    pub fn allocator(self: *KestrelArena) std.mem.Allocator {
        return self.arena.allocator();
    }
    
    pub fn reset(self: *KestrelArena) void {
        self.used = 0;
        _ = self.arena.reset(.retain_capacity);
    }
    
    pub fn deinit(self: *KestrelArena) void {
        self.arena.deinit();
    }
    
    pub fn checkBudget(self: *KestrelArena, requested: usize) !void {
        if (self.used + requested > self.budget) {
            return error.BudgetExceeded;
        }
    }
};

/// Pre-allocated expert cache
pub const ExpertCache = struct {
    arena: KestrelArena,
    experts: std.AutoHashMap(u32, ExpertEntry),
    lru: std.ArrayList(u32),
    
    const ExpertEntry = struct {
        ptr: [*]const u8,
        size: usize,
        last_access: u64,
        hot: bool,
    };
    
    pub fn init(allocator: std.mem.Allocator) !ExpertCache {
        return .{
            .arena = KestrelArena.init(
                "expert_cache",
                MEMORY_BUDGET.EXPERT_CACHE,
                allocator
            ),
            .experts = std.AutoHashMap(u32, ExpertEntry).init(allocator),
            .lru = std.ArrayList(u32).init(allocator),
        };
    }
    
    pub fn loadExpert(
        self: *ExpertCache,
        expert_id: u32,
        data: []const u8,
        hot: bool
    ) !void {
        // Check budget
        try self.arena.checkBudget(data.len);
        
        // Allocate from arena
        const alloc = self.arena.allocator();
        const buffer = try alloc.alloc(u8, data.len);
        @memcpy(buffer, data);
        
        // Store entry
        try self.experts.put(expert_id, .{
            .ptr = buffer.ptr,
            .size = data.len,
            .last_access = std.time.milliTimestamp(),
            .hot = hot,
        });
        
        self.arena.used += data.len;
    }
    
    pub fn getExpert(self: *ExpertCache, expert_id: u32) ?[]const u8 {
        if (self.experts.getPtr(expert_id)) |entry| {
            entry.last_access = std.time.milliTimestamp();
            return entry.ptr[0..entry.size];
        }
        return null;
    }
    
    pub fn evictLRU(self: *ExpertCache, count: usize) !void {
        var evicted: usize = 0;
        var i: usize = 0;
        
        while (i < self.lru.items.len and evicted < count) {
            const expert_id = self.lru.items[i];
            if (self.experts.fetchRemove(expert_id)) |entry| {
                self.arena.used -= entry.value.size;
                evicted += 1;
            }
            i += 1;
        }
    }
};

test "memory budget validation" {
    // Verify compile-time budget
    try std.testing.expectEqual(
        MEMORY_BUDGET.TOTAL_RAM,
        MEMORY_BUDGET.EXPERT_CACHE + 
        MEMORY_BUDGET.ROUTER_ARENA + 
        MEMORY_BUDGET.STREAM_BUFFER + 
        MEMORY_BUDGET.FFI_OVERHEAD + 
        MEMORY_BUDGET.SYSTEM_RESERVE
    );
}

test "arena allocation" {
    var arena = KestrelArena.init(
        "test",
        1024 * 1024, // 1MB
        std.testing.allocator
    );
    
    const alloc = arena.allocator();
    const buffer = try alloc.alloc(u8, 100);
    defer alloc.free(buffer);
    
    try std.testing.expectEqual(buffer.len, 100);
    
    // Test budget check
    try arena.checkBudget(100);
    try std.testing.expectError(
        error.BudgetExceeded,
        arena.checkBudget(1024 * 1024 * 2)
    );
}
