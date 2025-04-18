const std = @import("std");

const NUM_REGS = 8;

const FlagIndex = 1;

pub const SingleRegister = enum(u8) {
    A = 0,
    B = 2,
    C = 3,
    D = 4,
    E = 5,
    H = 6,
    L = 7,
};

pub const PairRegister = enum(u8) {
    AF = 0,
    BC = 2,
    DE = 4,
    HL = 6,
};

pub const RegisterKind = enum {
    single,
    double,
};

pub const Register = union(RegisterKind) {
    single: SingleRegister,
    double: PairRegister,
};

pub const FlagRegister = packed struct {
    low: u4,
    carry: u1,
    half_carry: u1,
    sub: u1,
    zero: u1,

    const Self = @This();

    pub fn default() Self {
        // Flag register should fit into 1 byte.
        comptime std.debug.assert(@sizeOf(FlagRegister) == 1);

        return Self{
            .low = 0,
            .carry = 0,
            .half_carry = 0,
            .sub = 0,
            .zero = 0,
        };
    }

    pub fn set_carry(s: Self, val: u1) Self {
        var self = s;

        self.carry = val;
        return self;
    }

    pub fn set_half_curry(s: Self, val: u1) Self {
        var self = s;

        self.half_carry = val;
        return self;
    }

    pub fn set_sub(s: Self, val: u1) Self {
        var self = s;

        self.sub = val;
        return self;
    }

    pub fn set_zero(s: Self, val: u1) Self {
        var self = s;

        self.zero = val;
        return self;
    }

    pub fn toggle_carry(s: Self) Self {
        var self = s;

        self.carry ^= 1;
        return self;
    }

    pub fn dump_state(self: *const Self, writer: anytype) void {
        _ = self;
        _ = writer;
        // writer.print("Registers {{ a: {x} f: {x}, b: {x}, c: {x}, d: {x}, e: {x}, h: {x}, l: {x}, pc: {x}, sp: {x} }}\n", .{ });
        // writer.print("Flags {{ {}, {}, {}, {} }}\n", .{ self.carry, self.half_carry, self.sub, self.zero });
    }
};

pub const RegisterFile = struct {
    regs: [NUM_REGS]u8,
    pc: u16,
    sp: u16,

    const Self = @This();

    pub fn default() Self {
        return Self{
            .regs = [_]u8{ 0x11, @bitCast(FlagRegister.default().set_zero(1)), 0x0, 0x0, 0xFF, 0x56, 0x00, 0xD },
            .pc = 0x100,
            .sp = 0xFFFE,
        };
    }

    pub fn assign_single(self: *Self, r: SingleRegister, val: u8) void {
        self.assign(Register{ .single = r }, @as(u16, val));
    }

    pub fn assign_double(self: *Self, r: PairRegister, val: u16) void {
        self.assign(Register{ .double = r }, val);
    }

    pub fn assign(self: *Self, r: Register, val: u16) void {
        switch (r) {
            .single => |*reg| self.regs[@intFromEnum(reg.*)] = @truncate(val),
            .double => |*reg| {
                const first = @intFromEnum(reg.*);

                self.regs[first] = @truncate(val >> 8);
                self.regs[first + 1] = @truncate(val);
            },
        }
    }

    pub fn read_single(self: *Self, r: SingleRegister) u8 {
        return @truncate(self.read(Register{ .single = r }));
    }

    pub fn read_double(self: *Self, r: PairRegister) u16 {
        return self.read(Register{ .double = r });
    }

    pub fn read(self: *Self, r: Register) u16 {
        switch (r) {
            .single => |*reg| return @as(u16, self.regs[@intFromEnum(reg.*)]),
            .double => |*reg| {
                const first = @intFromEnum(reg.*);

                return @as(u16, self.regs[first + 1]) | (@as(u16, self.regs[first]) << 8);
            },
        }
    }

    pub fn update_flags(self: *Self, flags: FlagRegister) void {
        self.regs[FlagIndex] = @bitCast(flags);
    }

    pub fn read_flags(self: *Self) FlagRegister {
        return @bitCast(self.regs[FlagIndex]);
    }

    pub fn dump_state(self: *Self, writer: anytype) void {
        writer.print("Registers {{ a: {x}, f: {x}, b: {x}, c: {x}, d: {x}, e: {x}, h: {x}, l: {x}, pc: {x}, sp: {x} }}\n", .{
            self.regs[0],
            self.regs[1],
            self.regs[2],
            self.regs[3],
            self.regs[4],
            self.regs[5],
            self.regs[6],
            self.regs[7],
            self.pc,
            self.sp,
        });
        // writer.print("PC: 0x{x} SP: 0x{x}\n", .{ self.pc, self.sp });
        // writer.print("Registers (A/F/B/C/D/E/H/L) {x}\n", .{self.regs});
        // self.read_flags().dump_state(writer);
    }
};

test "Test register API" {
    const expectEqual = std.testing.expectEqual;

    var regs = RegisterFile.default();
    const af = Register{ .double = PairRegister.BC };

    regs.regs = [_]u8{0} ** (NUM_REGS);

    regs.assign(af, 1 | (2 << 8));

    try expectEqual(regs.regs[3], 1);
    try expectEqual(regs.regs[2], 2);
    try expectEqual(regs.read_single(SingleRegister.B), 2);
    try expectEqual(regs.read_single(SingleRegister.C), 1);
}
