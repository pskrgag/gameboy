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

const TIMER_CTRL = 0xFF07;

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

    pub fn tick(self: *Self, tcycles: u8) void {
        _ = self;
        _ = tcycles;
    }

    pub fn new(rom: []u8) Self {
        var def = Self.default();

        @memcpy(def.rom[0..rom.len], rom);
        return def;
    }

    pub fn write(self: *Self, comptime tp: type, addr: u16, val: tp) void {
        const type_size = @sizeOf(tp);

        switch (addr) {
            ROM_BASE...ROM_BASE + ROM_SIZE - 1 => {
                const idx = addr - ROM_BASE;

                @memcpy(self.rom[idx .. idx + type_size], std.mem.asBytes(&val));
            },
            INTERNAL_RAM_BASE...INTERNAL_RAM_BASE + INTERNAL_RAM_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM_BASE;

                @memcpy(self.ram[idx .. idx + 1], std.mem.asBytes(&val));
            },
            INTERNAL_RAM8K_BASE...INTERNAL_RAM8K_BASE + INTERNAL_RAM8K_SIZE => {
                const idx = addr - INTERNAL_RAM8K_BASE;

                @memcpy(self.ram8k[idx .. idx + 1], std.mem.asBytes(&val));
            },
            VIDEO_RAM_BASE...VIDEO_RAM_BASE + VIDEO_RAM_SIZE => {
                // SKIP
            },
            TIMER_CTRL => {
                self.timer.write_control(@truncate(val));
            },
            else => {
                std.debug.print("\nAddr {x}\n", .{addr});
                @panic("Write to unknown memory");
            },
        }
    }

    pub fn read(self: *Self, comptime tp: type, addr: u16) tp {
        var res: tp = 0;
        const type_size = @sizeOf(tp);

        switch (addr) {
            ROM_BASE...ROM_BASE + ROM_SIZE - 1 => {
                const idx = addr - ROM_BASE;

                @memcpy(std.mem.asBytes(&res), self.rom[idx .. idx + type_size]);
            },
            INTERNAL_RAM_BASE...INTERNAL_RAM_BASE + INTERNAL_RAM_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM_BASE;

                @memcpy(std.mem.asBytes(&res), self.ram[idx .. idx + type_size]);
            },
            INTERNAL_RAM8K_BASE...INTERNAL_RAM8K_BASE + INTERNAL_RAM8K_SIZE => {
                const idx = addr - INTERNAL_RAM8K_BASE;

                @memcpy(std.mem.asBytes(&res), self.ram8k[idx .. idx + type_size]);
            },
            LY => return 0,
            else => {
                std.debug.print("Address {x}\n", .{addr});
                @panic("Read of unknown memory");
            },
        }

        return res;
    }
};
