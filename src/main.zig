const std = @import("std");
const SDL = @import("sdl2"); // Created in build.zig by using ;
const Gameboy = @import("gameboy.zig").Gameboy;

pub fn main() !void {
    //  Get an allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // var file = try std.fs.cwd().openFile("test-roms/cpu_instrs/individual/02-interrupts.gb", .{});
    // var file = try std.fs.cwd().openFile("/home/paskripkin/Downloads/Tetris (World) (Rev A).gb", .{});
    var file = try std.fs.cwd().openFile("/home/paskripkin/Downloads/Super Mario Land (World) (Rev 1).gb", .{});
    defer file.close();

    const code = try file.readToEndAlloc(allocator, 0x10000);
    defer allocator.free(code);

    var gb = Gameboy.default(code);
    defer gb.deinit();

    try gb.run();
}

test {
    std.testing.refAllDecls(@This());
}
