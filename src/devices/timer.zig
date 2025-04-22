const std = @import("std");
const math = std.math;
const asBytes = std.mem.asBytes;

pub const Timer = struct {
    div: u16,
    tma: u8,
    tac: u8,
    prev: u1,
    tima: u8,

    const Self = @This();

    pub fn default() Self {
        return Self{
            .div = 0,
            .tma = 0,
            .tac = 0,
            .prev = 0,
            .tima = 0,
        };
    }

    fn tac_to_t_ticks(tima: u2) u16 {
        return switch (tima) {
            0b00 => 1024,
            0b01 => 16,
            0b10 => 64,
            0b11 => 256,
        };
    }

    fn timer_is_enabled(self: *Self) u1 {
        return @intFromBool((self.tac & (1 << 2)) != 0);
    }

    pub fn tick(self: *Self, t_ticks: u8) void {
        std.debug.assert(t_ticks <= 32);

        const ticks = Self.tac_to_t_ticks(@truncate(self.tac));
        const log = math.log2(ticks) - 1;
        const log_mask: u16 = @as(u16, 1) << @truncate(log);

        self.div +%= t_ticks;
        const new = @intFromBool((self.div & log_mask) != 0) & self.timer_is_enabled();

        if ((self.prev == 1) and (new == 0)) {
            self.tima += 1;
            @panic("helo");
        }

        self.prev = new;
    }

    pub fn write(self: *Self, addr: u16, val: u8) void {
        switch (addr) {
            // Write to div register resets it
            0xFF04 => self.div = 0,
            0xFF07 => self.tac = val,
            else => @panic("Wrong address\n"),
        }
    }
};
