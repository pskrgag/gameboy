const std = @import("std");
const SDL = @import("sdl2");
const Color = @import("sdl2").Color;
const LinearFifo = std.fifo.LinearFifo;

const VRAM_BASE = 0x8000;
const VRAM_SIZE = 0x2000;

const OAM_BASE = 0xFE00;
const OAM_SIZE = 40 * 4;

const OAMEntry = packed struct {
    // Y position
    y: u8,
    // X position
    x: u8,
    // The tile index
    tile: u8,
    attrs: packed struct {
        _unused: u3,

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

    pub fn get(self: *Palette, color: u2) u2 {
        return switch (color) {
            0 => self.bit01,
            1 => self.bit23,
            2 => self.bit45,
            3 => self.bit67,
        };
    }
};

const Fifo = struct {
    buffer: [16]u8,
    len: usize,
    in: usize,
    out: usize,

    const Self = @This();

    pub const FifoError = error{
        Full,
        Empty,
    };

    pub fn default() Self {
        return .{
            .buffer = [_]u8{0} ** 16,
            .len = 0,
            .in = 0,
            .out = 0,
        };
    }

    pub fn push(self: *Self, data: u8) !void {
        if (self.len < 16) {
            self.buffer[self.in] = data;
            self.in = (self.in + 1) % 16;

            self.len += 1;
        } else {
            return FifoError.Full;
        }
    }

    pub fn pop(self: *Self) !u8 {
        if (self.len != 0) {
            const res = self.buffer[self.out];

            self.out = (self.out + 1) % 16;
            self.len -= 1;
            return res;
        } else {
            return FifoError.Empty;
        }
    }
};

const Fetcher = struct {
    ticks: u8,
    state: FetcherState,
    ppu: ?*Ppu,
    tile_id: u8,
    tile_line: u8,
    fifo: Fifo,
    pixels: [8]u8,

    const FetcherState = enum {
        ReadID,
        ReadData0,
        ReadData1,
        Push,
    };

    const Self = @This();

    pub fn default() Self {
        return Self{
            .ticks = 0,
            .state = FetcherState.ReadID,
            .ppu = null,
            .tile_id = 0,
            .tile_line = 0,
            .fifo = Fifo.default(),
            .pixels = [_]u8{0} ** 8,
        };
    }

    pub fn start(self: *Self, ppu: *Ppu) void {
        self.ppu = ppu;

        self.tile_line = ppu.y % 8;
        self.state = FetcherState.ReadID;
        self.fifo = Fifo.default();
    }

    fn read_data(self: *Self, low: bool) void {
        const ppu = self.ppu orelse @panic("");
        const data = ppu.get_tile_byte(self.tile_id, self.tile_line, low);

        for (0..8) |bit| {
            const cur_bit = data & (@as(u8, 1) << @truncate(bit));

            if (low) {
                self.pixels[bit] = @intFromBool(cur_bit != 0);
            } else {
                self.pixels[bit] |= @as(u8, @intFromBool(cur_bit != 0)) << 1;
            }

            std.debug.assert(self.pixels[bit] < 4);
        }
    }

    pub fn tick(self: *Self) void {
        const ppu = self.ppu orelse @panic("");

        self.ticks += 1;

        if (self.ticks != 2)
            return;

        self.ticks -= 2;

        switch (self.state) {
            FetcherState.ReadID => {
                self.tile_id = ppu.get_tileid();
                self.state = FetcherState.ReadData0;
            },
            FetcherState.ReadData0 => {
                self.read_data(true);
                self.state = FetcherState.ReadData1;
            },
            FetcherState.ReadData1 => {
                self.read_data(false);
                self.state = FetcherState.Push;
            },
            FetcherState.Push => {
                if (self.fifo.len <= 16) {
                    for (0..8) |i| {
                        self.fifo.push(self.pixels[7 - i]) catch |err| {
                            std.debug.print("Failed to push to fifo {any}", .{err});
                            @panic("");
                        };
                    }

                    self.state = FetcherState.ReadID;
                }
            },
        }
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
    // Pixel fetcher
    fetcher: Fetcher,
    // Read to print pixels
    next_pixel: LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = 32 }),
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

    pub const PpuStateEnum = enum(u8) {
        OAMScan = 2,
        PixelTransfer = 3,
        HBlank = 0,
        VBlank = 1,
    };

    pub const PpuState = union(PpuStateEnum) {
        OAMScan: void,
        PixelTransfer: [10]OAMEntry,
        HBlank: void,
        VBlank: void,
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
            .fetcher = Fetcher.default(),
            .next_pixel = LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = 32 }).init(),
            .lyc = 0,
            .lyc_irq = 0,
            .hblank_irq = 0,
            .vblank_irq = 0,
            .oamscan_irq = 0,
            .bg_palette = @bitCast(@as(u8, 0b11100100)),
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

    pub fn get_tileid(self: *Self) u8 {
        switch (self.state) {
            PpuState.PixelTransfer => |array| {
                for (array) |entry| {
                    if (entry.x == 0)
                        break;

                    if (entry.x >= self.x and entry.x + 8 < self.x)
                        return entry.tile;
                }
            },
            else => @panic("Invalid state"),
        }

        const base = self.tile_fetch_addr();
        return self.read(base);
    }

    fn tile_fetch_addr(self: *Self) u16 {
        const is_window = (self.control & (1 << 5)) != 0;
        var base: u16 = 0;

        std.debug.assert(!is_window);

        if (is_window and self.wy == self.y and self.x == self.wx - 7) {
            const window_map = (self.control & (1 << 6)) != 0;

            base = if (window_map) 0x9C00 else 0x9800;
        } else {
            const bg_map = (self.control & (1 << 3)) != 0;
            // Reading background
            base = if (!bg_map) 0x9800 else 0x9C00;

            const y = self.y +% self.scy;
            base += (@as(u16, y) / 8) * 32 + @as(u16, self.x) / 8;
        }

        return base;
    }

    fn scan_oam(self: *Self) [10]OAMEntry {
        var arr = std.mem.zeroes([10]OAMEntry);
        var idx: usize = 0;

        for (self.oam) |entry| {
            if (entry.x > 0 and self.y + 16 >= entry.y and self.y + 16 < entry.y + 8) {
                arr[idx] = entry;
                idx += 1;

                if (idx >= 10)
                    break;
                @panic("hello");
            }
        }

        return arr;
    }

    fn render_background(self: *Self) void {
        const bg_map = (self.control & (1 << 3)) != 0;
        var base: u16 = if (!bg_map) 0x9800 else 0x9C00;

        const y = self.y +% self.scy;

        // Base address for reading tilenum
        base += (@as(u16, y) / 8) * 32;

        for (0..20) |i| {
            const tile_num = self.read(base + @as(u16, @truncate(i)));

            const byte1 = self.get_tile_byte(tile_num, self.y % 8, true);
            const byte2 = self.get_tile_byte(tile_num, self.y % 8, false);

            for (0..8) |byte| {
                const bit1: u1 = @intFromBool((byte1 & (@as(u8, 1) << @truncate(byte))) != 0);
                const bit2: u1 = @intFromBool((byte2 & (@as(u8, 1) << @truncate(byte))) != 0);
                const color = @as(u2, bit1) | (@as(u2, bit2) << 1);

                self.scanline[i * 8 + (7 - byte)] = Self.ColorArray[self.bg_palette.get(color)];
            }
        }
    }

    fn render_window(self: *Self) void {
        const is_window = (self.control & (1 << 5)) != 0;

        if (!is_window)
            return;

        @panic("");
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
                        self.state = PpuState{
                            .PixelTransfer = self.scan_oam(),
                        };
                        self.x = 0;
                        self.fetcher.start(self);
                    }
                },
                PpuState.PixelTransfer => {
                    if (self.ticks == 80 + 172) {
                        // Render current scan line
                        self.render_background();
                        self.render_window();
                        self.scanline_read = true;
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
                            if (self.vblank_irq == 1)
                                res |= (1 << 0);
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
                        self.state = PpuState.OAMScan;
                        std.debug.assert(self.next_pixel.count == 0);
                    }
                },
            }
        }

        return res;
    }

    fn get_tile_byte(self: *Self, idx: u8, line: u8, low: bool) u8 {
        const is_set = (self.control & (1 << 4)) != 0;

        std.debug.assert(line < 8);

        // Tile is 16 byte long, each 2 bytes represent one line.
        // tile_id * 2 gives offset to start of the tile, while self.tile_line * 2 gives
        // offset to corresponding line within tile
        //
        // In 8000 method idx is used as positive integer, however in 0x8800 method it's used
        // as signed idx.
        if (is_set) {
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
        self.state = PpuState.OAMScan;
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
            0xFF43 => self.scx = val,
            0xFF42 => self.scy = val,
            0xFF44 => self.y = 0,
            0xFF45 => self.lyc = val,
            0xFF46 => {},
            0xFF47 => self.bg_palette = @bitCast(val),
            // OBJ palettes
            0xFF48, 0xFF49 => {},
            0xFF68 => {},
            0xFF69 => {},
            0xFF4F => {},
            VRAM_BASE...VRAM_BASE + VRAM_SIZE => {
                self.vram[addr - VRAM_BASE] = val;
            },
            OAM_BASE...OAM_BASE + OAM_SIZE => {
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

                return res;
            },
            0xFF43 => return self.scx,
            0xFF42 => return self.scy,
            0xFF44 => return self.y,
            0xFF45 => return self.lyc,
            0xFF47 => return @bitCast(self.bg_palette),
            VRAM_BASE...VRAM_BASE + VRAM_SIZE => return self.vram[addr - VRAM_BASE],
            else => {
                std.debug.print("addr - {x}\n", .{addr});
                @panic("");
            },
        }
    }
};
