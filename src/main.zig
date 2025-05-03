const std = @import("std");
const Gameboy = @import("gameboy.zig").Gameboy;

pub fn main() !void {
    //  Get an allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    if (argv.len < 2) {
        std.debug.print("Please pass path to rom\n", .{});
        return;
    }

    const rom_path = argv[1];
    var file = try std.fs.cwd().openFile(rom_path, .{});
    defer file.close();

    const stats = try file.stat();
    const file_size = stats.size;

    const code = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(code);

    var gb = Gameboy.default(code);
    defer gb.deinit();

    try gb.run();
}

test {
    std.testing.refAllDecls(@This());
}
