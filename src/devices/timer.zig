const std = @import("std");
const math = std.math;
const asBytes = std.mem.asBytes;

pub const Timer = struct {
    div: u16,
    tma: u8,
    tac: u3,
    tima: u8,
    tima_counter: u16,

    const Self = @This();

    pub fn default() Self {
        return Self{
            .div = 0,
            .tma = 0,
            .tac = 0,
            .tima = 0,
            .tima_counter = 0,
        };
    }

    fn tac_to_t_ticks(tac: u3) u16 {
        return switch (@as(u2, @truncate(tac))) {
            0b00 => 1024,
            0b01 => 16,
            0b10 => 64,
            0b11 => 256,
        };
    }

    fn is_enabled(self: *Self) bool {
        return (self.tac & (1 << 2)) != 0;
    }

    pub fn tick(self: *Self, mcycles: u8) bool {
        var res = false;
        const ticks = mcycles;

        self.div +%= ticks;

        if (self.is_enabled()) {
            const step = Self.tac_to_t_ticks(self.tac);

            self.tima_counter += ticks;

            while (self.tima_counter >= step) {
                self.tima_counter -= step;
                self.tima +%= 1;

                if (self.tima == 0) {
                    self.tima = self.tma;
                    res = true;
                }
            }
        }

        return res;
    }

    pub fn read(self: *Self, addr: u16) u8 {
        switch (addr) {
            // Only high 8 bits are mapped to to MMIO
            0xFF04 => return @truncate(self.div >> 8),
            0xFF05 => return self.tima,
            0xFF07 => return self.tac,
            0xFF06 => return self.tma,
            else => {
                std.debug.print("{x}\n", .{addr});
                @panic("Wrong address\n");
            },
        }
    }

    pub fn write(self: *Self, addr: u16, val: u8) void {
        switch (addr) {
            // Write to div register resets it
            0xFF04 => self.div = 0,
            0xFF05 => self.tima = val,
            0xFF07 => self.tac = @truncate(val),
            0xFF06 => self.tma = val,
            else => {
                std.debug.print("{x}\n", .{addr});
                @panic("Wrong address\n");
            },
        }
    }
};
