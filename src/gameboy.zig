const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;
const SDL = @import("sdl2");
const KeyboardEvent = @import("sdl2").KeyboardEvent;
const Keycode = @import("sdl2").Keycode;
const Ppu = @import("devices/gpu.zig").Ppu;
const Key = @import("devices/joystick.zig").Key;

const WINDOW_HEIGTH = 144;
const WINDOW_WIDTH = 160;

pub const Gameboy = struct {
    cpu: Cpu,
    window: SDL.Window,
    renderer: SDL.Renderer,
    pixels: u16,
    stop: bool,

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
            "Gameboy",
            .{ .centered = {} },
            .{ .centered = {} },
            0,
            0,
            .{
                .vis = .shown,
                .resizable = true,
            },
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
            .pixels = 0,
            .stop = false,
        };
    }

    pub fn run(self: *Self) !void {
        while (!self.stop) {
            try self.tick();
        }
    }

    fn sdl_to_gameboy(key: KeyboardEvent) ?Key {
        return switch (key.keycode) {
            .space => Key.Select,
            .@"return" => Key.Start,
            .left => Key.Left,
            .right => Key.Right,
            .down => Key.Down,
            .up => Key.Up,
            .z => Key.A,
            .x => Key.B,
            else => null,
        };
    }

    pub fn tick(self: *Self) !void {
        // Check SDL events
        while (SDL.pollEvent()) |ev| {
            switch (ev) {
                .quit => self.stop = true,
                .key_down => |key| {
                    const mapped = Self.sdl_to_gameboy(key);

                    if (mapped != null)
                        self.cpu.memory.joypad.key_pressed(mapped.?);
                },
                .key_up => |key| {
                    const mapped = Self.sdl_to_gameboy(key);

                    if (mapped != null)
                        self.cpu.memory.joypad.key_released(mapped.?);
                },
                else => {},
            }
        }

        const size = self.window.getSize();
        const height = size.height;
        const width = size.width;

        const x_scale = @as(f32, @floatFromInt(width)) / WINDOW_WIDTH;
        const y_scale = @as(f32, @floatFromInt(height)) / WINDOW_HEIGTH;

        self.cpu.tick();

        const scanline = self.cpu.memory.ppu.pop_scanline();

        if (scanline != null) {
            for (scanline.?, 0..) |color, x| {
                const y = self.cpu.memory.ppu.y;
                const x_f = @as(f32, @floatFromInt(x));
                const y_f = @as(f32, @floatFromInt(y));

                const rect =
                    SDL.Rectangle{
                        .x = @intFromFloat(@floor(x_f * x_scale)),
                        .y = @intFromFloat(@floor(y_f * y_scale)),
                        .width = @intFromFloat(@ceil(x_scale)),
                        .height = @intFromFloat(@ceil(y_scale)),
                    };

                try self.renderer.setColor(color);
                try self.renderer.fillRect(rect);

                self.pixels = (self.pixels + 1) % (WINDOW_HEIGTH * WINDOW_WIDTH);

                if (self.pixels == 0) {
                    self.renderer.present();
                }
            }
        }
    }

    pub fn deinit(self: *Self) void {
        SDL.quit();
        self.window.destroy();
        self.renderer.destroy();
    }
};
