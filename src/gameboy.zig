const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;
const SDL = @import("sdl2");
const Ppu = @import("devices/gpu.zig").Ppu;

const WINDOW_HEIGTH = 160;
const WINDOW_WIDTH = 140;

const TILE_SCALE = 10;

const DEBUG_WINDOW_HEIGTH = WINDOW_HEIGTH * TILE_SCALE;
const DEBUG_WINDOW_WIDTH = WINDOW_WIDTH * TILE_SCALE;

pub const Gameboy = struct {
    cpu: Cpu,
    window: SDL.Window,
    renderer: SDL.Renderer,
    y: u8,
    x: u8,

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
            .x = 0,
            .y = 0,
        };
    }

    pub fn run(self: *Self) !void {
        while (true) {
            try self.tick();
        }
    }

    pub fn tick(self: *Self) !void {
        var next = self.cpu.memory.ppu.pop_pixel();

        while (next != null) {
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
                self.renderer.present();
            }

            next = self.cpu.memory.ppu.pop_pixel();
        }

        self.cpu.tick();
    }

    pub fn deinit(self: *Self) void {
        SDL.quit();
        self.window.destroy();
        self.renderer.destroy();
    }
};
