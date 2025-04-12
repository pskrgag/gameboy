const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;

pub fn main() !void {
    const cpu = Cpu.default();

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {d} are belong to us.\n", .{cpu.registers.regs[0]});
}
