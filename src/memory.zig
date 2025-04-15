const std = @import("std");

const ROM_SIZE = 0x8000;
const ROM_BASE = 0x0;

const RAM_BASE = 0xC000;
const RAM_SIZE = 0x4000;

pub const Memory = struct {
    rom: [ROM_SIZE]u8,
    ram: [RAM_SIZE]u8,

    const Self = @This();

    pub fn default() Self {
        return Self{
            .rom = [_]u8{0} ** (ROM_SIZE),
            .ram = [_]u8{0} ** (RAM_SIZE),
        };
    }

    pub fn new(rom: []u8) Self {
        var def = Self.default();

        @memcpy(def.rom[0..rom.len], rom);
        return def;
    }

    pub fn write_u8(self: *Self, addr: u16, val: u8) void {
        switch (addr) {
            ROM_BASE...ROM_BASE + ROM_SIZE - 1 => {
                const idx = addr - ROM_BASE;

                self.rom[idx] = val;
            },
            RAM_BASE...RAM_BASE + RAM_SIZE - 1 => {
                const idx = addr - RAM_BASE;

                self.ram[idx] = val;
            },
            else => @panic("Write to unknown memory"),
        }
    }

    pub fn write_u16(self: *Self, addr: u16, val: u16) void {
        switch (addr) {
            ROM_BASE...ROM_BASE + ROM_SIZE - 1 => {
                const idx = addr - ROM_BASE;

                self.rom[idx] = @truncate(val & 0xf);
                self.rom[idx + 1] = @truncate((val & 0xf0) >> 8);
            },
            RAM_BASE...RAM_BASE + RAM_SIZE - 1 => {
                const idx = addr - RAM_BASE;

                self.ram[idx] = @truncate(val & 0xf);
                self.ram[idx + 1] = @truncate((val & 0xf0) >> 8);
            },
            else => @panic("Write to unknown memory"),
        }
    }

    pub fn read_u8(self: *Self, addr: u16) u8 {
        switch (addr) {
            ROM_BASE...ROM_BASE + ROM_SIZE - 1 => {
                const idx = addr - ROM_BASE;

                return self.rom[idx];
            },
            RAM_BASE...RAM_BASE + RAM_SIZE - 1 => {
                const idx = addr - RAM_BASE;

                return self.ram[idx];
            },
            else => {
                std.debug.print("Address {d}\n", .{addr});
                @panic("Read of unknown memory");
            },
        }
    }

    pub fn read_u16(self: *Self, addr: u16) u16 {
        switch (addr) {
            ROM_BASE...ROM_BASE + ROM_SIZE - 1 => {
                const idx = addr - ROM_BASE;

                return self.rom[idx] | @as(u16, self.rom[idx + 1]) << 8;
            },
            RAM_BASE...RAM_BASE + RAM_SIZE - 1 => {
                const idx = addr - RAM_BASE;

                return self.ram[idx] | @as(u16, self.ram[idx + 1]) << 8;
            },
            else => @panic("Write to unknown memory"),
        }
    }
};
