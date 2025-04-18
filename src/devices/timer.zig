const std = @import("std");
const asBytes = std.mem.asBytes;

pub const Timer = struct {
    div: u8,
    counter: u8,
    modulo: u8,
    stop: u1,
    freq: u2,

    const Self = @This();

    pub fn default() Self {
        return Self{
            .div = 0,
            .counter = 0,
            .modulo = 0,
            .stop = 0,
            .freq = 0,
        };
    }

    pub fn write_control(self: *Self, val: u3) void {
        self.freq = @truncate(val & 0b11);
        self.stop = @truncate((val & 0b100) >> 2);
    }
};
