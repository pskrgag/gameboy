const std = @import("std");
const SDL = @import("sdl2");
const Color = @import("sdl2").Color;

const VRAM_BASE = 0x8000;
const VRAM_SIZE = 0x2000;

const OAM_BASE = 0xFE00;
const OAM_SIZE = 40 * 4;

const SMTH = 0xFF68;

const PpuState = enum {
    OAMScan,
};

const OAMEntry = packed struct {
    // Y position
    y: u8,
    // X position
    x: u8,
    // The tile index
    tile: u8,
    attrs: packed struct {
        // OBP0-7 palette
        palette: u3,

        // 0 = Vram0, 1 = Vram1
        bank: u1,

        // 0 = OBP0, 1 = OBP1
        dmg_paltte: u1,

        // 0 = No, 1 = Horizontal flip
        xflip: u1,

        // 0 = No, 1 = Vertical flip
        yflip: u1,

        // 0 = No, 1 = BG
        prio: u1,
    },

    const Self = @This();

    pub fn default() Self {
        comptime std.debug.assert(@sizeOf(Self) == 4);
        return std.mem.zeroes(Self);
    }
};

const Palette = packed struct {
    id0: u2,
    id1: u2,
    id2: u2,
    id3: u2,

    const White = 0;
    const LightGray = 1;
    const DarkGray = 2;
    const Black = 3;

    const Self = @This();

    pub fn default() Self {
        comptime std.debug.assert(@sizeOf(Self) == 1);
        return .{ .id0 = 0, .id1 = 0, .id2 = 0, .id3 = 0 };
    }
};

pub const Ppu = struct {
    oam: [40]OAMEntry,
    vram: [VRAM_SIZE]u8,
    state: PpuState,
    y: u8,
    control: u8,
    scx: u8,
    scy: u8,
    palette: u8,
    ticks: usize,
    updated: bool,

    const Self = @This();

    pub fn default() Self {
        return .{
            .vram = [_]u8{0} ** (VRAM_SIZE),
            .state = PpuState.OAMScan,
            .y = 0,
            .control = 0x91,
            .scx = 0,
            .scy = 0,
            .palette = 0,
            .oam = [_]OAMEntry{OAMEntry.default()} ** 40,
            .ticks = 0,
            .updated = false,
        };
    }

    pub fn tile_to_colors(tile: []const u8) [64]Color {
        var i: usize = 0;
        var colors = [_]Color{std.mem.zeroes(Color)} ** 64;
        const White = Color{ .r = 155, .g = 188, .b = 15 };
        const DarkGreen = Color{ .r = 48, .g = 98, .b = 48 };
        const LightGreen = Color{ .r = 139, .g = 172, .b = 15 };
        const Black = Color{ .r = 15, .g = 56, .b = 15 };
        const ColorArray = [_]Color{ White, LightGreen, DarkGreen, Black };

        while (i < tile.len) : (i += 2) {
            const byte1 = tile[i];
            const byte2 = tile[i + 1];

            for (0..8) |byte| {
                const bit1: u1 = @intFromBool((byte1 & (@as(u8, 1) << @truncate(byte))) != 0);
                const bit2: u1 = @intFromBool((byte2 & (@as(u8, 1) << @truncate(byte))) != 0);
                const color = @as(u2, bit1) | (@as(u2, bit2) << 1);
                const line = i / 2;

                colors[line * 8 + 7 - byte] = ColorArray[color];
            }
        }

        return colors;
    }

    pub fn tick(self: *Self, t_tics: u8) void {
        self.ticks +%= t_tics;

        // Each line takes 114 cpu cycles
        if (self.ticks >= 114) {
            self.ticks -= 114;
            self.y = (self.y + 1) % 154;
        }
    }

    pub fn write(self: *Self, addr: u16, val: u8) void {
        switch (addr) {
            0xFF40 => self.control = val,
            0xFF43 => self.scx = val,
            0xFF42 => self.scy = val,
            0xFF47 => self.palette = val,
            0xFF44 => self.y = 0,
            0xFF68 => {},
            0xFF69 => {},
            0xFF4F => {},
            VRAM_BASE...VRAM_BASE + VRAM_SIZE => {
                self.vram[addr - VRAM_BASE] = val;
                self.updated = true;
            },
            OAM_BASE...OAM_BASE + OAM_SIZE => {
                std.mem.bytesAsSlice(u8, &self.oam)[addr - OAM_BASE] = val;
                self.updated = true;
            },
            else => @panic(""),
        }
    }

    pub fn read(self: *Self, addr: u16) u8 {
        switch (addr) {
            0xFF40 => return self.control,
            0xFF43 => return self.scx,
            0xFF42 => return self.scy,
            0xFF47 => return self.palette,
            0xFF44 => return self.y,
            VRAM_BASE...VRAM_BASE + VRAM_SIZE => return self.vram[addr - VRAM_BASE],
            else => @panic(""),
        }
    }
};
