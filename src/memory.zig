const std = @import("std");
const Timer = @import("devices/timer.zig").Timer;
const Ppu = @import("devices/gpu.zig").Ppu;
const Serial = @import("devices/serial.zig").Serial;

const ROM_SIZE = 0x8000;
const ROM_BASE = 0x0;

const INTERNAL_RAM_BASE = 0xFF80;
const INTERNAL_RAM_SIZE = 0xFFFF - 0xFF80;

const INTERNAL_RAM8K_BASE = 0xA000;
const INTERNAL_RAM8K_SIZE = 0x4000;

const VIDEO_RAM_BASE = 0x8000;
const VIDEO_RAM_SIZE = 0x2000;

const TIMER_BASE = 0xFF04;
const TIMER_SIZE = 4;

const SOUND_BASE = 0xFF10;
const SOUND_SIZE = 32;

// Interrupt enable flag
const IE_REG = 0xFFFF;

// Interrupt flag
const IF_REG = 0xFF0F;

// LCD registers
const LCD_BASE = 0xFF40;
const LCD_SIZE = 8;

// Serial registers
const SERIAL_BEGIN = 0xFF01;
const SERIAL_SIZE = 2;

pub const Memory = struct {
    rom: [ROM_SIZE]u8,
    ram: [INTERNAL_RAM_SIZE]u8,
    ram8k: [INTERNAL_RAM8K_SIZE]u8,
    timer: Timer,
    ppu: Ppu,
    serial: Serial,
    ie: u8,
    iff: u8,

    const Self = @This();

    pub const IrqSource = enum(u8) {
        VBlank = 0,
        LCD = 1,
        Timer = 2,
        Serial = 3,
        Joypad = 4,
    };

    pub fn is_irq_enabled(self: *Self, source: IrqSource) bool {
        return self.ie & (1 << @intFromEnum(source)) != 0;
    }

    pub fn is_irq_requesed(self: *Self, source: IrqSource) bool {
        return self.iff & (1 << @intFromEnum(source)) != 0;
    }

    pub fn default() Self {
        return Self{
            .rom = [_]u8{0} ** (ROM_SIZE),
            .ram = [_]u8{0} ** (INTERNAL_RAM_SIZE),
            .ram8k = [_]u8{0} ** (INTERNAL_RAM8K_SIZE),
            .timer = Timer.default(),
            .ppu = Ppu.default(),
            .ie = 0,
            .iff = 0,
            .serial = Serial.default(),
        };
    }

    pub fn tick(self: *Self, mcycles: u8) void {
        if (self.timer.tick(mcycles)) {
            self.iff |= (1 << @intFromEnum(IrqSource.Timer));
        }

        self.ppu.tick(mcycles);
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

                @memcpy(self.ram[idx .. idx + type_size], std.mem.asBytes(&val));
            },
            INTERNAL_RAM8K_BASE...INTERNAL_RAM8K_BASE + INTERNAL_RAM8K_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM8K_BASE;

                @memcpy(self.ram8k[idx .. idx + type_size], std.mem.asBytes(&val));
            },
            VIDEO_RAM_BASE...VIDEO_RAM_BASE + VIDEO_RAM_SIZE - 1, 0xFF68, 0xFF69, 0xFF4F => {
                self.ppu.write(addr, @truncate(val));
            },
            TIMER_BASE...TIMER_BASE + TIMER_SIZE - 1 => {
                self.timer.write(addr, @truncate(val));
            },
            LCD_BASE...LCD_BASE + LCD_SIZE => self.ppu.write(addr, @truncate(val)),
            IE_REG => self.ie = @truncate(val),
            IF_REG => self.iff = @truncate(val),
            SOUND_BASE...SOUND_BASE + SOUND_SIZE => {},
            SERIAL_BEGIN...SERIAL_BEGIN + SERIAL_SIZE => self.serial.write(addr, @truncate(val)),
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
            VIDEO_RAM_BASE...VIDEO_RAM_BASE + VIDEO_RAM_SIZE - 1 => {
                res = self.ppu.read(addr);
            },
            IE_REG => res = self.ie,
            IF_REG => res = self.iff | 0b11100000,
            SOUND_BASE...SOUND_BASE + SOUND_SIZE => {
                res = 0;
            },
            LCD_BASE...LCD_BASE + LCD_SIZE => res = self.ppu.read(addr),
            else => {
                std.debug.print("Address {x}\n", .{addr});
                @panic("Read of unknown memory");
            },
        }

        return res;
    }
};
