const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;
const SDL = @import("sdl2");
const Ppu = @import("devices/gpu.zig").Ppu;

const WINDOW_HEIGTH = 144;
const WINDOW_WIDTH = 160;

const TILE_SCALE = 10;

const DEBUG_WINDOW_HEIGTH = WINDOW_HEIGTH * TILE_SCALE;
const DEBUG_WINDOW_WIDTH = WINDOW_WIDTH * TILE_SCALE;

pub const Gameboy = struct {
    cpu: Cpu,
    window: SDL.Window,
    renderer: SDL.Renderer,
    y: u8,
    x: u8,
    pixels: u16,

    const Self = @This();

    pub fn default(rom: []u8) Self {
        SDL.init(.{
            .video = true,
            .events = true,
            .audio = true,
        }) catch |err| {
            std.debug.print("Error {}\n", .{err});
            @panic("SDL error");
        };

        const window = SDL.createWindow(
            "SDL2 Wrapper Demo",
            .{ .centered = {} },
            .{ .centered = {} },
            DEBUG_WINDOW_WIDTH,
            DEBUG_WINDOW_HEIGTH,
            .{ .vis = .shown },
        ) catch |err| {
            std.debug.print("Error {}\n", .{err});
            @panic("SDL create window error");
        };

        const renderer = SDL.createRenderer(window, null, .{ .accelerated = true }) catch |err| {
            std.debug.print("Error {}\n", .{err});
            @panic("SDL create renderer error");
        };

        return Self{
            .cpu = Cpu.default(rom, false),
            .window = window,
            .renderer = renderer,
            .x = 0,
            .y = 0,
            .pixels = 0,
        };
    }

    pub fn run(self: *Self) !void {
        while (true) {
            try self.tick();
        }
    }

    pub fn tick(self: *Self) !void {
        self.cpu.tick();

        var next = self.cpu.memory.ppu.pop_pixel();

        while (next != null) {
            std.debug.assert(self.cpu.memory.ppu.y == self.y);

            // if (self.x == 0 and self.y == 0)
            //     std.debug.print("START\n", .{});

            // std.debug.print("pop -- {x}\n", .{next.?});

            const color = Ppu.ColorArray[next.?];
            const rect =
                SDL.Rectangle{
                    .x = @intCast(@as(u16, self.x) * TILE_SCALE),
                    .y = @intCast(@as(u16, self.y) * TILE_SCALE),
                    .width = TILE_SCALE,
                    .height = TILE_SCALE,
                };

            try self.renderer.setColor(color);
            try self.renderer.fillRect(rect);

            self.x += 1;

            if (self.x == WINDOW_WIDTH) {
                self.y = (self.y + 1) % WINDOW_HEIGTH;
                self.x = 0;
            }

            self.pixels += 1;

            if (self.pixels == (WINDOW_HEIGTH * WINDOW_WIDTH)) {
                self.renderer.present();
                self.pixels = 0;

                // for (0..32) |i| {
                //     std.debug.print("{x}: ", .{i});
                //
                //     for (0..32) |j| {
                //         std.debug.print("{x} ", .{self.cpu.memory.ppu.read(0x9800 + @as(u16, @truncate(j)) + @as(u16, @truncate(i)) * 32)});
                //     }
                //
                //     std.debug.print("\n", .{});
                // }
                // std.debug.print("\n", .{});
                // std.debug.print("tiles\n", .{});
                //
                // for (0..50) |i| {
                //     std.debug.print("{x}: {{", .{i});
                //     for (0..16) |j| {
                //         std.debug.print("0x{x}, ", .{self.cpu.memory.ppu.read(0x8000 + @as(u16, @truncate(j)) + @as(u16, @truncate(i)) * 16)});
                //     }
                //     std.debug.print("}}\n", .{});
                // }
            }

            next = self.cpu.memory.ppu.pop_pixel();
        }

        std.debug.assert(self.cpu.memory.ppu.x == self.x);
    }

    pub fn deinit(self: *Self) void {
        SDL.quit();
        self.window.destroy();
        self.renderer.destroy();
    }
};
