const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;
const SDL = @import("sdl2");
const Ppu = @import("devices/gpu.zig").Ppu;

const WINDOW_HEIGTH = 160;
const WINDOW_WIDTH = 140;

const TILE_SCALE = 10;

// DEBUG window
// 16x24 tiles. Each tile takes 32x32 (which means 4x scale)
// 16 * 32 = 512 * 8
// 24 * 32 = 768 * 8
const DEBUG_WINDOW_HEIGTH = 16 * 8 * TILE_SCALE;
const DEBUG_WINDOW_WIDTH = 24 * 8 * TILE_SCALE;

pub const Gameboy = struct {
    cpu: Cpu,
    window: SDL.Window,
    renderer: SDL.Renderer,

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
            .cpu = Cpu.default(rom),
            .window = window,
            .renderer = renderer,
        };
    }

    pub fn run(self: *Self) !void {
        while (true) {
            try self.tick();
            self.renderer.present();
        }
    }

    pub fn tick(self: *Self) !void {
        // Display tiles
        var i: u16 = 0x8000;
        var y_start: usize = 0;
        var x_start: usize = 0;

        if (self.cpu.memory.ppu.updated) {
            self.cpu.memory.ppu.updated = false;

            while (i < 0x9FFF) : (i += 16) {
                var tile = std.mem.zeroes([16]u8);

                for (0..16) |idx| {
                    tile[idx] = self.cpu.memory_read_u8(@truncate(i + idx));
                }

                const colors = Ppu.tile_to_colors(&tile);
                for (colors, 0..) |color, idx| {
                    const rect =
                        SDL.Rectangle{
                            .x = @intCast(x_start + idx % 8 * TILE_SCALE),
                            .y = @intCast(y_start + idx / 8 * TILE_SCALE),
                            .width = TILE_SCALE,
                            .height = TILE_SCALE,
                        };

                    try self.renderer.setColor(color);
                    try self.renderer.fillRect(rect);
                }

                y_start += TILE_SCALE * 8;

                if (y_start == DEBUG_WINDOW_HEIGTH) {
                    y_start = 0;
                    x_start += 8 * TILE_SCALE;
                }
            }
        }

        self.cpu.tick();
    }

    pub fn deinit(self: *Self) void {
        SDL.quit();
        self.window.destroy();
        self.renderer.destroy();
    }
};
