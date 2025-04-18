const std = @import("std");
const Gameboy = @import("gameboy.zig").Gameboy;

pub fn main() !void {
    var fake = [_]u8{ 1, 2, 3 };
    const cpu = Gameboy.default(fake[0..]);

    _ = cpu;
    std.debug.print("All your {d} are belong to us.\n", .{1});
}
