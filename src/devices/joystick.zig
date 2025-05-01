const std = @import("std");

// Bit 0 -- Input right / Button A
// Bit 1 -- Input left  / Button B
// Bit 2 -- Input up    / Select
// Bit 3 -- Input down  / Start
// Bit 4 -- Select directional keys
// Bit 5 -- Select button keys

// Bit 0 -- pressed
// Bit 1 -- released

const ModeType = enum(u8) { Directional, Buttons };

const Directional = packed struct {
    right: u1,
    left: u1,
    up: u1,
    down: u1,
};

const Buttons = packed struct {
    a: u1,
    b: u1,
    select: u1,
    start: u1,
};

pub const Key = enum {
    Right,
    Left,
    Up,
    Down,
    A,
    B,
    Select,
    Start,
};

pub const Joypad = struct {
    dir: Directional,
    buttons: Buttons,
    raw: u8,
    irq: bool,

    const Self = @This();

    pub fn default() Self {
        return .{ .dir = @bitCast(@as(u4, 0b1111)), .buttons = @bitCast(@as(u4, 0b1111)), .raw = 0xFF, .irq = false };
    }

    fn get_mode(self: *Self) ModeType {
        switch ((self.raw >> 4) & 0b11) {
            0b10 => return ModeType.Directional,
            0b01 => return ModeType.Buttons,
            else => {
                // Am i stupid or it's bug?
                return ModeType.Directional;
            },
        }
    }

    pub fn read(self: *Self, addr: u16) u8 {
        std.debug.assert(addr == 0xFF00);
        return self.raw | 0b11 << 6;
    }

    fn key_update(self: *Self, key: Key, action: u1) void {
        switch (key) {
            .Right => self.dir.right = action,
            .Left => self.dir.left = action,
            .Down => self.dir.down = action,
            .Up => self.dir.up = action,
            .A => self.buttons.a = action,
            .B => self.buttons.b = action,
            .Select => self.buttons.select = action,
            .Start => self.buttons.start = action,
        }

        self.event();
        std.debug.print("{any} {any}\n", .{ self, action });
    }

    fn event(self: *Self) void {
        const current = self.raw & 0b1111;
        const new: u4 = switch (self.get_mode()) {
            ModeType.Buttons => @bitCast(self.buttons),
            ModeType.Directional => @bitCast(self.dir),
        };

        if (current == 0xF and new != 0xF)
            self.irq = true;

        self.raw = (self.raw & 0xF0) | new;
    }

    pub fn key_pressed(self: *Self, key: Key) void {
        self.key_update(key, 0);
    }

    pub fn key_released(self: *Self, key: Key) void {
        self.key_update(key, 1);
    }

    pub fn write(self: *Self, addr: u16, val: u8) void {
        std.debug.assert(addr == 0xFF00);

        self.raw = val & (0b11 << 4) | (self.raw & 0xCF);
        self.event();
    }
};
