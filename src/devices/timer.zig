const std = @import("std");

pub const Timer = packed struct {
    sbz: u4,
    freq: u2,
    control: u1,

    const Self = @This();

    pub fn default() Self {
        comptime std.debug.assert(@sizeOf(Self) == 1);

        return Self{
            .freq = 0,
            .control = 0,
            .sbz = 0,
        };
    }

    pub fn write(self: *Self, val: u8) void {
        @memcpy(self, &val);
    }
};
