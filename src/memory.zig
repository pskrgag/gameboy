const std = @import("std");
const Timer = @import("devices/timer.zig").Timer;

const ROM_SIZE = 0x8000;
const ROM_BASE = 0x0;

const INTERNAL_RAM_BASE = 0xFF80;
const INTERNAL_RAM_SIZE = 0xFFFF - 0xFF80;

const INTERNAL_RAM8K_BASE = 0xC000;
const INTERNAL_RAM8K_SIZE = 0x2000;

const VIDEO_RAM_BASE = 0x8000;
const VIDEO_RAM_SIZE = 0x3000;

const IE_REG = 0xFFFF;

// Devices
const LY = 0xFF44;

pub const Memory = struct {
    rom: [ROM_SIZE]u8,
    ram: [INTERNAL_RAM_SIZE]u8,
    ram8k: [INTERNAL_RAM8K_SIZE]u8,
    timer: Timer,

    const Self = @This();

    pub fn default() Self {
        return Self{
            .rom = [_]u8{0} ** (ROM_SIZE),
            .ram = [_]u8{0} ** (INTERNAL_RAM_SIZE),
            .ram8k = [_]u8{0} ** (INTERNAL_RAM8K_SIZE),
            .timer = Timer.default(),
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
            INTERNAL_RAM_BASE...INTERNAL_RAM_BASE + INTERNAL_RAM_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM_BASE;

                self.ram[idx] = val;
            },
            INTERNAL_RAM8K_BASE...INTERNAL_RAM8K_BASE + INTERNAL_RAM8K_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM8K_BASE;

                self.ram8k[idx] = val;
            },
            VIDEO_RAM_BASE...VIDEO_RAM_BASE + VIDEO_RAM_SIZE => {
                // SKIP
            },
            IE_REG => {
                // SKIP
            },
            else => {
                std.debug.print("\n{x}\n", .{addr});
                @panic("Write to unknown memory");
            },
        }
    }

    pub fn write_u16(self: *Self, addr: u16, val: u16) void {
        switch (addr) {
            ROM_BASE...ROM_BASE + ROM_SIZE - 1 => {
                const idx = addr - ROM_BASE;

                self.rom[idx] = @truncate(val & 0xff);
                self.rom[idx + 1] = @truncate((val & 0xff) >> 8);
            },
            INTERNAL_RAM_BASE...INTERNAL_RAM_BASE + INTERNAL_RAM_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM_BASE;

                self.ram[idx] = @truncate(val & 0xff);
                self.ram[idx + 1] = @truncate((val & 0xff00) >> 8);
            },
            INTERNAL_RAM8K_BASE...INTERNAL_RAM8K_BASE + INTERNAL_RAM8K_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM8K_BASE;

                self.ram8k[idx] = @truncate(val & 0xff);
                self.ram8k[idx + 1] = @truncate((val & 0xff00) >> 8);
            },
            VIDEO_RAM_BASE...VIDEO_RAM_BASE + VIDEO_RAM_SIZE => {
                // SKIP
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
            INTERNAL_RAM_BASE...INTERNAL_RAM_BASE + INTERNAL_RAM_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM_BASE;

                return self.ram[idx];
            },
            INTERNAL_RAM8K_BASE...INTERNAL_RAM8K_BASE + INTERNAL_RAM8K_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM8K_BASE;

                return self.ram8k[idx];
            },
            LY => return 0,
            else => {
                std.debug.print("Address {x}\n", .{addr});
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
            INTERNAL_RAM_BASE...INTERNAL_RAM_BASE + INTERNAL_RAM_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM_BASE;

                return self.ram[idx] | (@as(u16, self.ram[idx + 1]) << 8);
            },
            INTERNAL_RAM8K_BASE...INTERNAL_RAM8K_BASE + INTERNAL_RAM8K_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM8K_BASE;

                return self.ram8k[idx] | (@as(u16, self.ram8k[idx + 1]) << 8);
            },
            else => @panic("Write to unknown memory"),
        }
    }
};
