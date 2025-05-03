const std = @import("std");
const Timer = @import("devices/timer.zig").Timer;
const Ppu = @import("devices/gpu.zig").Ppu;
const Serial = @import("devices/serial.zig").Serial;
const Cartridge = @import("devices/cartridge.zig").Cartridge;
const Joypad = @import("devices/joystick.zig").Joypad;

const ROM_SIZE = 0x8000;
const ROM_BASE = 0x0;

const HRAM_BASE = 0xFF80;
const HRAM_SIZE = 0xFFFF - 0xFF80;

const INTERNAL_RAM_BASE = 0xC000;
const INTERNAL_RAM_SIZE = 0x2000;

const EXTERNAL_RAM_BASE = 0xA000;
const EXTERNAL_RAM_SIZE = 0x2000;

const INTERNAL_RAM_ECHO_BASE = 0xE000;
const INTERNAL_RAM_ECHO_SIZE = 0x1e00;

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

// Serial registers
const SERIAL_BEGIN = 0xFF01;
const SERIAL_SIZE = 2;

// Joypad
const JOYPAD_BEGIN = 0xFF00;
const JOYPAD_SIZE = 1;

const OAM_START = 0xFE00;
const OAM_SIZE = 40 * 4;

pub const Memory = struct {
    rom: Cartridge,
    ram: [INTERNAL_RAM_SIZE]u8,
    hram: [HRAM_SIZE]u8,
    timer: Timer,
    ppu: Ppu,
    serial: Serial,
    joypad: Joypad,
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
            .rom = Cartridge.default(),
            .ram = [_]u8{0} ** (INTERNAL_RAM_SIZE),
            .hram = [_]u8{0} ** (HRAM_SIZE),
            .timer = Timer.default(),
            .ppu = Ppu.default(),
            .ie = 0,
            .iff = 0,
            .serial = Serial.default(),
            .joypad = Joypad.default(),
        };
    }

    pub fn tick(self: *Self, mcycles: u8) void {
        if (self.timer.tick(mcycles)) {
            self.iff |= (1 << @intFromEnum(IrqSource.Timer));
        }

        self.iff |= self.ppu.tick(mcycles);

        if (self.joypad.irq) {
            self.iff |= (1 << @intFromEnum(IrqSource.Joypad));
            self.joypad.irq = false;
        }
    }

    pub fn new(rom: []u8) Self {
        var def = Self.default();

        def.rom = Cartridge.from_data(rom);
        return def;
    }

    pub fn write(self: *Self, comptime tp: type, addr: u16, val: tp) void {
        const type_size = @sizeOf(tp);

        switch (addr) {
            ROM_BASE...ROM_BASE + ROM_SIZE - 1 => {
                self.rom.write(addr, @truncate(val));
            },
            INTERNAL_RAM_BASE...INTERNAL_RAM_BASE + INTERNAL_RAM_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM_BASE;

                @memcpy(self.ram[idx .. idx + type_size], std.mem.asBytes(&val));
            },
            EXTERNAL_RAM_BASE...EXTERNAL_RAM_BASE + EXTERNAL_RAM_SIZE - 1 => {
                self.rom.write(addr, @truncate(val));
            },
            INTERNAL_RAM_ECHO_BASE...INTERNAL_RAM_ECHO_BASE + INTERNAL_RAM_ECHO_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM_ECHO_BASE;

                @memcpy(self.ram[idx .. idx + type_size], std.mem.asBytes(&val));
            },
            VIDEO_RAM_BASE...VIDEO_RAM_BASE + VIDEO_RAM_SIZE - 1, 0xFF68, 0xFF69, 0xFF4F => {
                self.ppu.write(addr, @truncate(val));
            },
            OAM_START...OAM_START + OAM_SIZE - 1 => {
                self.ppu.write(addr, @truncate(val));
            },
            TIMER_BASE...TIMER_BASE + TIMER_SIZE - 1 => {
                self.timer.write(addr, @truncate(val));
            },
            0xFF40, 0xFF41, 0xFF42, 0xFF43, 0xFF44, 0xFF45, 0xFF47, 0xFF48, 0xFF49, 0xFF4A, 0xFF4B => self.ppu.write(addr, @truncate(val)),
            IE_REG => self.ie = @truncate(val),
            IF_REG => self.iff = @truncate(val),
            SOUND_BASE...SOUND_BASE + SOUND_SIZE - 1 => {},
            JOYPAD_BEGIN...JOYPAD_BEGIN + JOYPAD_SIZE - 1 => self.joypad.write(addr, @truncate(val)),
            SERIAL_BEGIN...SERIAL_BEGIN + SERIAL_SIZE - 1 => self.serial.write(addr, @truncate(val)),
            0xFF46 => {
                // Starts a DMA transfer (val << 8) is a base address, while 0xFE00 is destination
                // This transfer should copy 0xA0 (160) bytes of memory
                const source: u16 = @as(u16, val) << 8;
                const dst: u16 = 0xFE00;

                for (0..160) |i| {
                    const data = self.read(u8, source + @as(u16, @truncate(i)));

                    self.write(u8, dst + @as(u16, @truncate(i)), data);
                }
            },
            HRAM_BASE...HRAM_BASE + HRAM_SIZE - 1 => {
                const idx = addr - HRAM_BASE;

                @memcpy(self.hram[idx .. idx + type_size], std.mem.asBytes(&val));
            },
            else => {
                // std.debug.print("Write to unknown memory: Addr {x}\n", .{addr});
                // @panic("Write to unknown memory");
            },
        }
    }

    pub fn read(self: *Self, comptime tp: type, addr: u16) tp {
        var res: tp = 0;
        const type_size = @sizeOf(tp);

        switch (addr) {
            ROM_BASE...ROM_BASE + ROM_SIZE - 1 => {
                return self.rom.read(addr);
            },
            INTERNAL_RAM_BASE...INTERNAL_RAM_BASE + INTERNAL_RAM_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM_BASE;

                @memcpy(std.mem.asBytes(&res), self.ram[idx .. idx + type_size]);
            },
            EXTERNAL_RAM_BASE...EXTERNAL_RAM_BASE + EXTERNAL_RAM_SIZE - 1 => {
                res = self.rom.read(addr);
            },
            INTERNAL_RAM_ECHO_BASE...INTERNAL_RAM_ECHO_BASE + INTERNAL_RAM_ECHO_SIZE - 1 => {
                const idx = addr - INTERNAL_RAM_ECHO_BASE;

                @memcpy(std.mem.asBytes(&res), self.ram[idx .. idx + type_size]);
            },
            VIDEO_RAM_BASE...VIDEO_RAM_BASE + VIDEO_RAM_SIZE - 1 => {
                res = self.ppu.read(addr);
            },
            TIMER_BASE...TIMER_BASE + TIMER_SIZE - 1 => {
                res = self.timer.read(addr);
            },
            IE_REG => res = self.ie,
            IF_REG => res = self.iff | 0b11100000,
            SOUND_BASE...SOUND_BASE + SOUND_SIZE => {
                res = 0;
            },
            0xFF40, 0xFF41, 0xFF42, 0xFF43, 0xFF44, 0xFF45, 0xFF47, 0xFF48, 0xFF49, 0xFF4A, 0xFF4B => res = self.ppu.read(addr),
            JOYPAD_BEGIN...JOYPAD_BEGIN + JOYPAD_SIZE - 1 => {
                res = self.joypad.read(addr);
            },
            SERIAL_BEGIN...SERIAL_BEGIN + SERIAL_SIZE - 1 => res = self.serial.read(addr),
            HRAM_BASE...HRAM_BASE + HRAM_SIZE - 1 => {
                const idx = addr - HRAM_BASE;

                @memcpy(std.mem.asBytes(&res), self.hram[idx .. idx + type_size]);
            },
            else => {
                // std.debug.print("Read of unknown memory {x}\n", .{addr});
                res = 0xFF;
            },
        }

        return res;
    }
};
