const std = @import("std");
const math = std.math;
const asBytes = std.mem.asBytes;

pub const Timer = struct {
    div: u16,
    tma: u8,
    tac: u8,
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

    fn tac_to_t_ticks(tima: u2) u16 {
        return switch (tima) {
            0b00 => 1024,
            0b01 => 16,
            0b10 => 64,
            0b11 => 256,
        };
    }

    fn is_enabled(self: *Self) bool {
        return (self.tac & (1 << 2)) != 0;
    }

    pub fn tick(self: *Self, ticks: u8) bool {
        var res = false;
        std.debug.assert(ticks <= 32);

        const step = Self.tac_to_t_ticks(@truncate(self.tac));

        self.div +%= ticks;

        if (self.is_enabled()) {
            self.tima_counter += ticks;

            if (self.tima_counter >= step) {
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

    pub fn write(self: *Self, addr: u16, val: u8) void {
        switch (addr) {
            // Write to div register resets it
            0xFF04 => self.div = 0,
            0xFF07 => self.tac = val,
            0xFF05 => self.tima = val,
            else => {
                std.debug.print("{x}\n", .{addr});
                @panic("Wrong address\n");
            },
        }
    }
};
