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
    tile_idx: u8,
    tile_id: u8,
    tile_line: u8,
    addr: u16,
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
            .tile_idx = 0,
            .tile_id = 0,
            .tile_line = 0,
            .fifo = Fifo.default(),
            .addr = 0,
            .pixels = [_]u8{0} ** 8,
        };
    }

    pub fn start(self: *Self, ppu: *Ppu) void {
        self.ppu = ppu;

        self.tile_line = ppu.y % 8;
        self.tile_idx = 0;
        self.state = FetcherState.ReadID;
        self.fifo = Fifo.default();

        const y = ppu.y;

        // Each line in background map consists of 32 bytes (because it's 32x32)
        // ppu.y is line number and each tile is 8 bytes long.
        //
        // self.addr now contains base address for current tile line.
        self.addr = 0x9800 + (@as(u16, y) / 8) * 32;
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

        self.ticks = 0;

        switch (self.state) {
            FetcherState.ReadID => {
                self.tile_id = ppu.read(self.addr + @as(u16, self.tile_idx));
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
                    for (0..7) |i| {
                        self.fifo.push(self.pixels[7 - i]) catch |err| {
                            std.debug.print("Failed to push to fifo {any}", .{err});
                            @panic("");
                        };
                    }

                    self.tile_idx += 1;
                    self.state = FetcherState.ReadID;
                }
            },
        }
    }
};

pub const Ppu = struct {
    oam: [40]OAMEntry,
    vram: [VRAM_SIZE]u8,
    state: PpuState,
    y: u8,
    x: u8,
    control: u8,
    scx: u8,
    scy: u8,
    palette: u8,
    ticks: usize,
    updated: bool,
    fetcher: Fetcher,
    next_pixel: LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = 32 }),

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
            .palette = 0,
            .oam = [_]OAMEntry{OAMEntry.default()} ** 40,
            .ticks = 4,
            .updated = false,
            .fetcher = Fetcher.default(),
            .next_pixel = LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = 32 }).init(),
        };
    }

    pub fn tile_to_colors(tile: []const u8) [64]Color {
        var i: usize = 0;
        var colors = [_]Color{std.mem.zeroes(Color)} ** 64;

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

    pub fn pop_pixel(self: *Self) ?u8 {
        return self.next_pixel.readItem();
    }

    pub fn tick(self: *Self, ticks: u8) void {
        if (!self.is_enabled()) {
            return;
        }
        // std.debug.print("gpu tick {x} {x} {x} {x}\n", .{ ticks, self.y, @intFromEnum(self.state), self.ticks });

        for (0..ticks) |_| {
            self.ticks +%= 1;

            switch (self.state) {
                PpuState.OAMScan => {
                    if (self.ticks == 80) {
                        self.state = PpuState.PixelTransfer;
                        self.x = 0;

                        self.fetcher.start(self);
                    }
                },
                PpuState.PixelTransfer => {
                    self.fetcher.tick();

                    if (self.fetcher.fifo.len == 0) {
                        continue;
                    }

                    // Each tick gpu produces a pixel
                    self.x += 1;

                    const data = self.fetcher.fifo.pop() catch |err| {
                        std.debug.print("{any}", .{err});
                        @panic("");
                    };

                    self.next_pixel.writeItem(data) catch |err| {
                        std.debug.print("{any}", .{err});
                        @panic("");
                    };

                    if (self.x == 160) {
                        self.state = PpuState.HBlank;
                        self.x = 0;
                        continue;
                    }
                },
                PpuState.HBlank => {
                    if (self.ticks == 456) {
                        self.ticks -= 456;
                        self.y = (self.y + 1) % 154;

                        // Goto VBlank mode
                        if (self.y == 144) {
                            self.state = PpuState.VBlank;
                        } else {
                            self.state = PpuState.OAMScan;
                        }
                    }
                },
                PpuState.VBlank => {
                    // Each line takes 114 cpu cycles. V-Blank takes 10 lines
                    if (self.ticks == 456) {
                        self.y = (self.y + 1) % 154;
                        self.ticks -= 456;
                    }

                    if (self.y == 0) {
                        self.state = PpuState.OAMScan;
                        std.debug.assert(self.next_pixel.count == 0);
                    }
                },
            }
        }
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
            else => {
                std.debug.print("\nval{x}\n", .{val});
                @panic("");
            },
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
            else => {
                std.debug.print("{x}\n", .{addr});
                @panic("");
            },
        }
    }
};
