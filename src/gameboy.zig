const Cpu = @import("cpu.zig").Cpu;

pub const Gameboy = struct {
    cpu: Cpu,
    ticks: u64,

    const Self = @This();

    pub fn default(rom: []u8) Self {
        return Self{
            .cpu = Cpu.default(rom),
            .ticks = 0,
        };
    }

    fn tick(self: *Self) void {
        const ticks = self.cpu.tick();
        self.memory.tick(ticks);
    }
};
