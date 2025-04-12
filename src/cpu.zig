const RegisterFile = @import("register.zig").RegisterFile;
const Register = @import("register.zig").Register;
const RegisterKind = @import("register.zig").RegisterKind;
const SingleRegister = @import("register.zig").SingleRegister;
const FlagRegister = @import("register.zig").FlagRegister;
const std = @import("std");

pub const Cpu = struct {
    registers: RegisterFile,

    const Self = @This();

    pub fn default() Self {
        return Cpu{
            .registers = RegisterFile.default(),
        };
    }

    fn alu_orr(self: *Self, val: u8) u8 {
        const a = self.registers.read_single(SingleRegister.A);
        const res = val | a;
        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0));

        self.registers.update_flags(new_flags);
        return res;
    }

    fn alu_and(self: *Self, val: u8) void {
        const a = self.registers.read_single(SingleRegister.A);
        const res = val & a;

        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0))
            .set_half_curry(1);

        self.registers.update_flags(new_flags);
        self.registers.assign_single(SingleRegister.A, res);
    }

    fn alu_xor(self: *Self, val: u8) void {
        const a = self.registers.read_single(SingleRegister.A);
        const res = val ^ a;

        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0))
            .set_half_curry(1);

        self.registers.update_flags(new_flags);
        self.registers.assign_single(SingleRegister.A, res);
    }

    fn alu_add(self: *Self, val: u8) void {
        const a = self.registers.read_single(SingleRegister.A);

        // res[0] is a result, while res[1] is overflow indicator
        const res = @as(u16, val) + @as(u16, a);
        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0))
            .set_carry(@intFromBool(res > 0xff))
            .set_half_curry(@intFromBool(((a & 0xF) + (val & 0xF)) > 0xF));

        self.registers.update_flags(new_flags);
        self.registers.assign_single(SingleRegister.A, @truncate(res));
    }

    fn sub(self: *Self, val: u8) void {
        const a = self.registers.read_single(SingleRegister.A);

        // res[0] is a result, while res[1] is overflow indicator
        const res = @subWithOverflow(val, a);
        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res[0] == 0))
            .set_carry(res[1])
            .set_half_curry(@intFromBool((a & 0xF) < (val & 0xF)))
            .set_sub(1);

        self.registers.update_flags(new_flags);
        self.registers.assign_single(SingleRegister.A, res);
    }

    pub fn execute(self: *Self, i: u8) !void {
        switch (i) {
            0x80 => |_| self.alu_add(self.registers.read_single(SingleRegister.B)),
            0xA0 => |_| self.alu_and(self.registers.read_single(SingleRegister.B)),
            else => @panic("Unknown opcode"),
        }
    }

    pub fn dump_state(self: *Self, writer: anytype) void {
        self.registers.dump_state(writer);
    }
};

test "Test execute add" {
    const expectEqual = std.testing.expectEqual;

    const b = SingleRegister.B;
    const a = SingleRegister.A;
    var cpu = Cpu.default();

    cpu.registers.assign_single(b, 1);

    try cpu.execute(0x80);
    try expectEqual(cpu.registers.read_single(a), 1);
    try expectEqual(0, @as(u8, @bitCast(cpu.registers.read_flags())));

    try cpu.execute(0x80);
    try expectEqual(cpu.registers.read_single(a), 2);
    try expectEqual(0, @as(u8, @bitCast(cpu.registers.read_flags())));

    // Test half curry
    cpu.registers.assign_single(b, 143);

    try cpu.execute(0x80);
    try expectEqual(cpu.registers.read_single(a), 145);
    try expectEqual(0b100000, @as(u8, @bitCast(cpu.registers.read_flags())));

    // Test curry
    cpu.registers.assign_single(b, 143);

    try cpu.execute(0x80);
    try expectEqual(cpu.registers.read_single(a), (143 + 145) & 0xff);
    try expectEqual(0b110000, @as(u8, @bitCast(cpu.registers.read_flags())));

    cpu.dump_state(std.debug);
}

test "Test and" {
    const expectEqual = std.testing.expectEqual;

    const b = SingleRegister.B;
    const a = SingleRegister.A;

    var cpu = Cpu.default();

    cpu.registers.assign_single(b, 1);
    try cpu.execute(0xA0);

    // Manual say that half carry should be set
    try expectEqual(0b10100000, @as(u8, @bitCast(cpu.registers.read_flags())));
    try expectEqual(cpu.registers.read_single(a), 0);
}
