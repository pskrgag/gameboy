const std = @import("std");
const SDL = @import("sdl2");
const Color = @import("sdl2").Color;
const LinearFifo = std.fifo.LinearFifo;

const VRAM_BASE = 0x8000;
const VRAM_SIZE = 0x2000;

const OAM_BASE = 0xFE00;
const OAM_SIZE = 40 * @sizeOf(OAMEntry);

const OAMEntry = packed struct {
    // Y position
    y: u8,
    // X position
    x: u8,
    // The tile index
    tile: u8,
    attrs: packed struct {
        _unused: u4,

        // 0 = OBP0, 1 = OBP1
        palette: u1,

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
    bit01: u2,
    bit23: u2,
    bit45: u2,
    bit67: u2,

    pub fn get(self: *const Palette, color: u2) ?u2 {
        return switch (color) {
            0 => self.bit01,
            1 => self.bit23,
            2 => self.bit45,
            3 => self.bit67,
        };
    }
};

const Obj0Pal = packed struct {
    pal: Palette,

    pub fn get(self: *const Obj0Pal, color: u2) ?u2 {
        return switch (color) {
            0 => null,
            else => self.pal.get(color),
        };
    }
};

pub const Ppu = struct {
    oam: [40]OAMEntry,
    vram: [VRAM_SIZE]u8,
    // State
    state: PpuState,
    // LY
    y: u8,
    // Internal x position
    x: u8,
    // LCD control register
    control: u8,
    scx: u8,
    scy: u8,
    // Tick counter
    ticks: usize,
    // LY compare register
    lyc: u8,
    // IRQ on LY == LYC
    lyc_irq: u1,
    // Irq on HBlank
    hblank_irq: u1,
    // Irq on VBlank
    vblank_irq: u1,
    // Irq on OAMScan
    oamscan_irq: u1,
    // Palette for background
    bg_palette: Palette,
    // Obj0 palette
    obj0_palatte: Obj0Pal,
    // Obj1 palette
    obj1_palatte: Palette,
    // window y
    wy: u8,
    // window x
    wx: u8,
    // Rendered scanline
    scanline: [160]Color,
    // Indicates that scanline is ready
    scanline_read: bool,

    const Self = @This();
    pub const White = Color{ .r = 155, .g = 188, .b = 15 };
    pub const DarkGreen = Color{ .r = 48, .g = 98, .b = 48 };
    pub const LightGreen = Color{ .r = 139, .g = 172, .b = 15 };
    pub const Black = Color{ .r = 15, .g = 56, .b = 15 };
    pub const ColorArray = [_]Color{ White, LightGreen, DarkGreen, Black };

    pub const PpuState = enum(u8) {
        OAMScan = 2,
        PixelTransfer = 3,
        HBlank = 0,
        VBlank = 1,
    };

    const BACKGROUND_START = 0x9800 - VRAM_BASE;
    const BACKGROUND_SIZE = 0x9bff - 0x9800 + 1;

    pub fn default() Self {
        return .{
            .vram = [_]u8{0} ** (VRAM_SIZE),
            .state = PpuState.OAMScan,
            .y = 0,
            .x = 0,
            .control = 0x91,
            .scx = 0,
            .scy = 0,
            .oam = [_]OAMEntry{OAMEntry.default()} ** 40,
            .ticks = 4,
            .lyc = 0,
            .lyc_irq = 0,
            .hblank_irq = 0,
            .vblank_irq = 0,
            .oamscan_irq = 0,
            .bg_palette = @bitCast(@as(u8, 0b11100100)),
            .obj1_palatte = @bitCast(@as(u8, 0b11100100)),
            .obj0_palatte = @bitCast(@as(u8, 0b11100100)),
            .wy = 0,
            .wx = 0,
            .scanline = [_]Color{Self.White} ** (160),
            .scanline_read = false,
        };
    }

    pub fn pop_scanline(self: *Self) ?[160]Color {
        if (self.scanline_read) {
            self.scanline_read = false;
            return self.scanline;
        }

        return null;
    }

    fn increment_y(self: *Self) u8 {
        self.y = (self.y + 1) % 154;

        if (self.lyc_irq == 1 and self.y == self.lyc)
            return 1 << 1;

        return 0;
    }

    fn tile_to_raw_colors(self: *Self, tile_num: u8, line: u8, rev: bool, palette: anytype, force8000: bool) [8]?Color {
        var res = [_]?Color{null} ** 8;

        const byte1 = self.get_tile_byte(tile_num, line, true, force8000);
        const byte2 = self.get_tile_byte(tile_num, line, false, force8000);

        for (0..8) |byte| {
            const bit1: u1 = @intFromBool((byte1 & (@as(u8, 1) << @truncate(byte))) != 0);
            const bit2: u1 = @intFromBool((byte2 & (@as(u8, 1) << @truncate(byte))) != 0);
            const raw_color = @as(u2, bit1) | (@as(u2, bit2) << 1);
            const color = palette.get(raw_color);

            if (color != null) {
                if (!rev) {
                    res[7 - byte] = Self.ColorArray[color.?];
                } else {
                    res[byte] = Self.ColorArray[color.?];
                }
            }
        }

        return res;
    }

    const OAMEntrySort = struct {
        entry: OAMEntry,
        pos: usize,
    };

    fn sprites_sort(ctx: void, lhs: OAMEntrySort, rhs: OAMEntrySort) bool {
        _ = ctx;
        if (lhs.entry.x != rhs.entry.x)
            return rhs.entry.x < lhs.entry.x;

        return rhs.pos < lhs.pos;
    }

    fn render_sprites(self: *Self) void {
        const is_on = (self.control & 0b10) != 0;
        const current_y: i16 = @intCast(self.y);

        if (!is_on)
            return;

        var arr = std.mem.zeroes([10]OAMEntrySort);
        var idx: usize = 0;
        const long_mode = (self.control & (1 << 2)) != 0;
        const sprite_height: u8 = if (long_mode) 16 else 8;

        for (self.oam) |entry| {
            const sprite_y: i16 = @intCast(entry.y);

            if (entry.x < 0)
                continue;

            const real_y = sprite_y - 16;
            if (current_y >= real_y and current_y < real_y + sprite_height) {
                arr[idx] = .{ .entry = entry, .pos = idx };
                idx += 1;

                std.debug.assert(entry.attrs.prio == 0);
                if (idx >= 10)
                    break;
            }
        }

        std.mem.sort(OAMEntrySort, arr[0..idx], {}, Self.sprites_sort);

        for (0..idx) |i| {
            const sprite = arr[i].entry;

            const sprite_y: i16 = @intCast(sprite.y);
            const sprite_x: i16 = @intCast(sprite.x);

            const real_y = sprite_y - 16;
            const real_x = sprite_x - 8;

            // Flip y
            const line = if (sprite.attrs.yflip == 0) self.y - real_y else sprite_height - (self.y - real_y);
            // Choose tilenum
            const tile = if (long_mode) sprite.tile ^ 1 else sprite.tile;
            // Xflip
            const xflip = sprite.attrs.xflip == 1;

            // Obj0 palette defined 0 as transparent. Since i don't wanna mess with interfaces
            // and i cannot save pal to separate variable (because of distinct types) i have to
            // call tile_to_raw_colors 2 times (which looks ugly but works)
            const colors = if (sprite.attrs.palette == 1) self.tile_to_raw_colors(tile, @intCast(line), xflip, self.obj1_palatte, true) else self.tile_to_raw_colors(tile, @intCast(line), xflip, self.obj0_palatte, true);

            for (colors, 0..) |color, byte| {
                if (color != null) {
                    const b: u8 = @intCast(byte);
                    const x = real_x + b;

                    if (x > 0 and x < 160) {
                        const cur_color = self.scanline[@intCast(x)];
                        const zero_color = Self.ColorArray[self.bg_palette.get(0).?];

                        // If priority is set and current color is non-zero -- don't render
                        if (sprite.attrs.prio == 1 and !std.meta.eql(cur_color, zero_color)) {
                            continue;
                        }

                        self.scanline[@intCast(x)] = color.?;
                    }
                }
            }
        }
    }

    fn render_background(self: *Self) void {
        const is_on = (self.control & 0b1) != 0;

        if (!is_on)
            return;

        const bg_map = (self.control & (1 << 3)) != 0;
        const base: u16 = if (!bg_map) 0x9800 else 0x9C00;

        const y = self.y +% self.scy;

        // Base address of the current row
        const row_addres = base + (@as(u16, y) / 8) * 32;

        // There are 20 tiles in a line, however because of per-pixel scroll of
        // scx, we have to fetch more in case of scx scroll in between tile
        for (0..21) |i| {
            // If tile get oob if current row, then wrap around
            const row_offset = (self.scx / 8 + i) & 31;
            const tile_num = self.read(@truncate(row_addres + row_offset));

            for (self.tile_to_raw_colors(tile_num, self.y % 8, false, self.bg_palette, false), 0..) |color, byte| {
                const pixel = (i * 8 + byte -% self.scx % 8);

                if (pixel < 160) {
                    self.scanline[pixel] = color.?;
                }
            }
        }
    }

    fn render_window(self: *Self) void {
        const is_window = (self.control & (1 << 5)) != 0;

        if (!is_window)
            return;

        // Window is not visible
        if (self.wy > self.y)
            return;

        const window_map = (self.control & (1 << 6)) != 0;
        const base: u16 = if (!window_map) 0x9800 else 0x9C00;

        // Line in the window buffer
        const y = self.y - self.wy;

        // Base address of the current row
        const row_addres = base + (@as(u16, y) / 8) * 32;

        // X position of the window
        const x = self.wx -% 7;

        // There are 20 tiles in a line, however because of per-pixel scroll of
        // wx, we have to fetch more in case of wx scroll in between tile
        for (0..21) |i| {
            const tile_num = self.read(@truncate(row_addres + i));

            // NOTE: use y rather than self.y to determine line, since widow offset may be placed within tile bounds
            for (self.tile_to_raw_colors(tile_num, y % 8, false, self.bg_palette, false), 0..) |color, byte| {
                const pixel = i * 8 + byte + x;

                if (pixel < 160) {
                    self.scanline[pixel] = color.?;
                }
            }
        }
    }

    pub fn tick(self: *Self, ticks: u8) u8 {
        if (!self.is_enabled()) {
            return 0;
        }

        var res: u8 = 0;

        for (0..ticks) |_| {
            self.ticks +%= 1;

            switch (self.state) {
                PpuState.OAMScan => {
                    if (self.ticks == 80) {
                        self.state = PpuState.PixelTransfer;
                        self.x = 0;
                    }
                },
                PpuState.PixelTransfer => {
                    if (self.ticks == 80 + 172) {
                        // Render current scan line
                        self.render_background();
                        self.render_window();
                        self.render_sprites();
                        self.scanline_read = true;

                        if (self.hblank_irq == 1)
                            res |= 1 << 1;

                        self.state = PpuState.HBlank;
                    }
                },
                PpuState.HBlank => {
                    if (self.ticks == 456) {
                        self.ticks -= 456;
                        res |= self.increment_y();

                        // Goto VBlank mode
                        if (self.y == 144) {
                            self.state = PpuState.VBlank;

                            // VBlank IRQ
                            res |= 1 << 0;

                            // Stat IRQ
                            if (self.vblank_irq == 1)
                                res |= 1 << 1;
                        } else {
                            self.state = PpuState.OAMScan;
                        }
                    }
                },
                PpuState.VBlank => {
                    // Each line takes 114 cpu cycles. V-Blank takes 10 lines
                    if (self.ticks == 456) {
                        res |= self.increment_y();
                        self.ticks -= 456;
                    }

                    if (self.y == 0) {
                        if (self.oamscan_irq == 1)
                            res |= 1 << 1;

                        self.state = PpuState.OAMScan;
                    }
                },
            }
        }

        return res;
    }

    fn get_tile_byte(self: *Self, idx: u8, line: u8, low: bool, force8000: bool) u8 {
        const is_set = (self.control & (1 << 4)) != 0;

        // Tile is 16 byte long, each 2 bytes represent one line.
        // tile_id * 2 gives offset to start of the tile, while self.tile_line * 2 gives
        // offset to corresponding line within tile
        //
        // In 8000 method idx is used as positive integer, however in 0x8800 method it's used
        // as signed idx.
        if (is_set or force8000) {
            const off = (0x8000 - VRAM_BASE) + @as(usize, idx) * 16 + line * 2 + @intFromBool(!low);

            return self.vram[off];
        } else {
            const off = (0x9000 - VRAM_BASE) + @as(i16, @as(i8, @bitCast(idx))) * 16 + line * 2 + @intFromBool(!low);

            return self.vram[@intCast(off)];
        }
    }

    fn is_enabled(self: *Self) bool {
        return (self.control & (1 << 7)) != 0;
    }

    fn ppu_off(self: *Self) void {
        self.ticks = 0;
        self.state = PpuState.OAMScan;
        self.y = 0;
    }

    fn ppu_on(self: *Self) void {
        self.ticks = 4;
        self.y = 0;
        self.state = PpuState.HBlank;
    }

    pub fn write(self: *Self, addr: u16, val: u8) void {
        switch (addr) {
            0xFF40 => {
                const request = val & (1 << 7) != 0;

                if (request and !self.is_enabled()) {
                    // Turn on
                    self.ppu_on();
                } else if (!request and self.is_enabled()) {
                    // Turn off
                    self.ppu_off();
                }

                self.control = val;
            },
            0xFF41 => {
                self.lyc_irq = @intFromBool((val & (1 << 6)) != 0);
                self.hblank_irq = @intFromBool((val & (1 << 3)) != 0);
                self.vblank_irq = @intFromBool((val & (1 << 4)) != 0);
                self.oamscan_irq = @intFromBool((val & (1 << 5)) != 0);
            },
            0xFF43 => {
                self.scx = val;
            },
            0xFF42 => {
                self.scy = val;
            },
            0xFF44 => self.y = 0,
            0xFF45 => self.lyc = val,
            0xFF47 => self.bg_palette = @bitCast(val),
            0xFF48 => self.obj0_palatte = @bitCast(val),
            0xFF49 => self.obj1_palatte = @bitCast(val),
            0xFF4A => self.wy = val,
            0xFF4B => self.wx = val,
            0xFF68 => {},
            0xFF69 => {},
            0xFF4F => {},
            VRAM_BASE...VRAM_BASE + VRAM_SIZE - 1 => {
                self.vram[addr - VRAM_BASE] = val;
            },
            OAM_BASE...OAM_BASE + OAM_SIZE - 1 => {
                std.mem.sliceAsBytes(&self.oam)[addr - OAM_BASE] = val;
            },
            else => {
                std.debug.print("\naddr{x}\n", .{addr});
                @panic("");
            },
        }
    }

    pub fn read(self: *Self, addr: u16) u8 {
        switch (addr) {
            0xFF40 => return self.control,
            0xFF41 => {
                var res: u8 = 0;

                // Mode
                res |= @intFromEnum(self.state);
                res |= @as(u8, @intFromBool(self.lyc == self.y)) << 2;
                res |= @as(u8, self.hblank_irq) << 3;
                res |= @as(u8, self.vblank_irq) << 4;
                res |= @as(u8, self.oamscan_irq) << 5;
                res |= @as(u8, self.lyc_irq) << 6;
                res |= 1 << 7;

                return res;
            },
            0xFF43 => return self.scx,
            0xFF42 => return self.scy,
            0xFF44 => return self.y,
            0xFF4A => return self.wy,
            0xFF4B => return self.wx,
            0xFF45 => return self.lyc,
            0xFF47 => return @bitCast(self.bg_palette),
            VRAM_BASE...VRAM_BASE + VRAM_SIZE - 1 => return self.vram[addr - VRAM_BASE],
            else => {
                std.debug.print("addr - {x}\n", .{addr});
                @panic("");
            },
        }
    }
};
