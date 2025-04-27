const RegisterFile = @import("register.zig").RegisterFile;
const Register = @import("register.zig").Register;
const RegisterKind = @import("register.zig").RegisterKind;
const SingleRegister = @import("register.zig").SingleRegister;
const PairRegister = @import("register.zig").PairRegister;
const FlagRegister = @import("register.zig").FlagRegister;
const std = @import("std");
const ArrayList = std.ArrayList;
const Memory = @import("memory.zig").Memory;

const single_cycles = [_]u8{
    1, 3, 2, 2, 1, 1, 2, 1, 5, 2, 2, 2, 1, 1, 2, 1,
    1, 3, 2, 2, 1, 1, 2, 1, 3, 2, 2, 2, 1, 1, 2, 1,
    2, 3, 2, 2, 1, 1, 2, 1, 2, 2, 2, 2, 1, 1, 2, 1,
    2, 3, 2, 2, 3, 3, 3, 1, 2, 2, 2, 2, 1, 1, 2, 1,
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1,
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1,
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1,
    2, 2, 2, 2, 2, 2, 1, 2, 1, 1, 1, 1, 1, 1, 2, 1,
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1,
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1,
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1,
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1,
    2, 3, 3, 4, 3, 4, 2, 4, 2, 4, 3, 0, 3, 6, 2, 4,
    2, 3, 3, 0, 3, 4, 2, 4, 2, 4, 3, 0, 3, 0, 2, 4,
    3, 3, 2, 0, 0, 4, 2, 4, 4, 1, 4, 0, 0, 0, 2, 4,
    3, 3, 2, 1, 0, 4, 2, 4, 3, 2, 4, 1, 0, 0, 2, 4,
};
const double_cycles = [_]u8{
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
    2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 3, 2,
    2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 3, 2,
    2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 3, 2,
    2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 3, 2,
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2,
};
const condition = [_]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    3, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0,
    3, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    5, 0, 4, 0, 6, 0, 0, 0, 5, 0, 4, 0, 6, 0, 0, 0,
    5, 0, 4, 0, 6, 0, 0, 0, 5, 0, 4, 0, 6, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

pub const Cpu = struct {
    registers: RegisterFile,
    memory: Memory,
    off: u16, // Hack to make add_pc work as function pointer
    cond: bool,
    debug: bool,
    ei: bool,
    halted: bool,

    const Self = @This();

    pub fn default(rom: []u8, debug: bool) Self {
        return Self{
            .registers = RegisterFile.default(),
            .memory = Memory.new(rom),
            .off = 0,
            .cond = false,
            .debug = debug,
            .ei = true,
            .halted = false,
        };
    }

    fn write_memory_hl(self: *Self, val: u8) void {
        const hl = self.registers.read(Register{ .double = PairRegister.HL });

        self.memory_write_u8(hl, val);
    }

    fn read_memory_hl(self: *Self) u8 {
        const hl = self.registers.read(Register{ .double = PairRegister.HL });

        return self.memory_read_u8(hl);
    }

    fn memory_write_u8(self: *Self, off: u16, val: u8) void {
        self.memory.write(u8, off, val);
    }

    fn memory_write_u16(self: *Self, off: u16, val: u16) void {
        self.memory.write(u16, off, val);
    }

    pub fn memory_read_u8(self: *Self, off: u16) u8 {
        return self.memory.read(u8, off);
    }

    fn memory_read_u16(self: *Self, off: u16) u16 {
        return self.memory.read(u16, off);
    }

    fn alu_add16_imm(self: *Self, val: u16) u16 {
        const imm: i8 = @bitCast(self.advance_pc());
        const im: u16 = @bitCast(@as(i16, imm));

        const flags = FlagRegister.default()
            .set_sub(0)
            .set_zero(0)
            .set_carry(@intFromBool((val & 0xFF) + (im & 0xFF) > 0xFF))
            .set_half_curry(@intFromBool((val & 0xF) + (im & 0xF) > 0xF));

        self.registers.update_flags(flags);
        return val +% im;
    }

    fn alu_add16(self: *Self, val1: u16, val: u16) u16 {
        // res[0] is a result, while res[1] is overflow indicator
        const res = @as(u32, val) + @as(u32, val1);
        const new_flags = self.registers.read_flags()
            .set_carry(@intFromBool(res > 0xffff))
            .set_half_curry(@intFromBool(((val & 0xFFF) + (val1 & 0xFFF)) > 0xFFF))
            .set_sub(0);

        self.registers.update_flags(new_flags);
        return @truncate(res);
    }

    fn alu_add16_hl(self: *Self, from: PairRegister) void {
        const hl_val = self.registers.read_double(PairRegister.HL);
        const reg = self.registers.read_double(from);
        const res = self.alu_add16(reg, hl_val);

        self.registers.assign_double(PairRegister.HL, res);
    }

    fn alu_or(self: *Self, val: u8) void {
        const a = self.registers.read_single(SingleRegister.A);
        const res = val | a;
        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0));

        self.registers.update_flags(new_flags);
        self.registers.assign_single(SingleRegister.A, res);
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
            .set_zero(@intFromBool(res == 0));

        self.registers.update_flags(new_flags);
        self.registers.assign_single(SingleRegister.A, res);
    }

    fn alu_add(self: *Self, val: u8) void {
        const a = self.registers.read_single(SingleRegister.A);

        // res[0] is a result, while res[1] is overflow indicator
        const res = @as(u16, val) + @as(u16, a);
        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool((res & 0xFF) == 0))
            .set_carry(@intFromBool(res > 0xff))
            .set_half_curry(@intFromBool(((a & 0xF) + (val & 0xF)) > 0xF));

        self.registers.update_flags(new_flags);
        self.registers.assign_single(SingleRegister.A, @truncate(res));
    }

    fn alu_addc(self: *Self, val: u8) void {
        const a = self.registers.read_single(SingleRegister.A);
        const carry = self.registers.read_flags().carry;

        // res[0] is a result, while res[1] is overflow indicator
        const res = @as(u16, val) + @as(u16, a) + @as(u16, carry);
        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool((res & 0xFF) == 0))
            .set_carry(@intFromBool(res > 0xff))
            .set_half_curry(@intFromBool(((a & 0xF) + (val & 0xF) + carry) > 0xF));

        self.registers.update_flags(new_flags);
        self.registers.assign_single(SingleRegister.A, @truncate(res));
    }

    fn alu_sub(self: *Self, val: u8) void {
        const a = self.registers.read_single(SingleRegister.A);

        // res[0] is a result, while res[1] is overflow indicator
        const res = a -% val;
        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0))
            .set_carry(@intFromBool(a < val))
            .set_half_curry(@intFromBool((a & 0xF) < (val & 0xF)))
            .set_sub(1);

        self.registers.update_flags(new_flags);
        self.registers.assign_single(SingleRegister.A, res);
    }

    fn alu_subc(self: *Self, val: u8) void {
        const a = self.registers.read_single(SingleRegister.A);
        const carry = self.registers.read_flags().carry;

        // res[0] is a result, while res[1] is overflow indicator
        const res = a -% val -% carry;
        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0))
            .set_carry(@intFromBool(a < @as(u16, val) + @as(u16, carry)))
            .set_half_curry(@intFromBool((a & 0xF) < (val & 0xF) + carry))
            .set_sub(1);

        self.registers.update_flags(new_flags);
        self.registers.assign_single(SingleRegister.A, res);
    }

    fn alu_inc(self: *Self, val: u8) u8 {
        const res = val +% 1;

        const new_flags = self.registers.read_flags()
            .set_zero(@intFromBool(res == 0))
            .set_half_curry(@intFromBool((val & 0xf) + 1 > 0xf))
            .set_sub(0);

        self.registers.update_flags(new_flags);
        return res;
    }

    fn alu_inc_reg(self: *Self, reg: SingleRegister) void {
        const val = self.registers.read_single(reg);
        const res = self.alu_inc(val);

        self.registers.assign_single(reg, res);
    }

    fn alu_inc_memory_hl(self: *Self) void {
        const mem = self.read_memory_hl();
        const res = self.alu_inc(mem);

        self.write_memory_hl(res);
    }

    fn alu_dec(self: *Self, val: u8) u8 {
        const res = val -% 1;

        const new_flags = self.registers.read_flags()
            .set_zero(@intFromBool(res == 0))
            .set_sub(1)
            .set_half_curry(@intFromBool((val & 0xF) == 0x0));

        self.registers.update_flags(new_flags);
        return res;
    }

    fn alu_dec_reg(self: *Self, reg: SingleRegister) void {
        const val = self.registers.read_single(reg);
        const res = self.alu_dec(val);

        self.registers.assign_single(reg, res);
    }

    fn alu_dec_memory_hl(self: *Self) void {
        const mem = self.read_memory_hl();
        const res = self.alu_dec(mem);

        self.write_memory_hl(res);
    }

    // No flags affected!
    fn alu_inc16(self: *Self, reg: PairRegister) void {
        var val = self.registers.read_double(reg);

        val +%= 1;
        self.registers.assign_double(reg, val);
    }

    // No flags affected!
    fn alu_dec16(self: *Self, reg: PairRegister) void {
        var val = self.registers.read_double(reg);

        val -%= 1;
        self.registers.assign_double(reg, val);
    }

    fn alu_swap_nibble(self: *Self, val: u8) u8 {
        const high = (val & 0xF) << @as(u8, 4);
        const res = high | (val >> 4);
        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0));

        self.registers.update_flags(new_flags);
        return @truncate(res);
    }

    fn alu_swap_nibble_reg(self: *Self, reg: SingleRegister) void {
        const val = self.registers.read_single(reg);
        const res = self.alu_swap_nibble(val);

        self.registers.assign_single(reg, res);
    }

    fn alu_swap_nibble_hl(self: *Self) void {
        const val = self.read_memory_hl();
        const res = self.alu_swap_nibble(val);

        self.write_memory_hl(res);
    }

    fn alu_daa(self: *Self) void {
        var val = self.registers.read_single(SingleRegister.A);
        var flags = self.registers.read_flags();
        var offset: u8 = 0;

        if (flags.carry != 0)
            offset = 0x60;

        if (flags.half_carry != 0)
            offset |= 0x06;

        if (flags.sub == 1) {
            val -%= offset;
        } else {
            if (val & 0x0F > 0x09)
                offset |= 0x06;
            if (val > 0x99)
                offset |= 0x60;

            val +%= offset;
        }

        flags = flags.set_zero(@intFromBool(val == 0)).set_half_curry(0).set_carry(@intFromBool(offset >= 0x60));
        self.registers.update_flags(flags);
        self.registers.assign_single(SingleRegister.A, val);
    }

    fn alu_cpl(self: *Self) void {
        const a = self.registers.read_single(SingleRegister.A);
        var flags = self.registers.read_flags();

        flags.sub = 1;
        flags.half_carry = 1;

        self.registers.update_flags(flags);
        self.registers.assign_single(SingleRegister.A, ~a);
    }

    fn alu_rlc(self: *Self, v: u8) u8 {
        var val = v;
        const carry = (val & (1 << 7)) != 0;

        val <<= 1;
        val |= @intFromBool(carry);

        const flags = FlagRegister
            .default()
            .set_zero(@intFromBool(val == 0))
            .set_carry(@intFromBool(carry));

        self.registers.update_flags(flags);
        return val;
    }

    fn alu_rlc_reg(self: *Self, reg: SingleRegister) void {
        const r = self.registers.read_single(reg);
        const res = self.alu_rlc(r);

        self.registers.assign_single(reg, res);
    }

    fn alu_rl(self: *Self, v: u8) u8 {
        var val = v;
        const carry = (val & (1 << 7)) != 0;
        const f_carry = self.registers.read_flags().carry;

        val <<= 1;
        val |= f_carry;

        const flags = FlagRegister
            .default()
            .set_zero(@intFromBool(val == 0))
            .set_carry(@intFromBool(carry));

        self.registers.update_flags(flags);

        return val;
    }

    fn alu_rl_reg(self: *Self, reg: SingleRegister) void {
        const r = self.registers.read_single(reg);
        const res = self.alu_rl(r);

        self.registers.assign_single(reg, res);
    }

    fn alu_rrc(self: *Self, v: u8) u8 {
        var val = v;
        const carry = (val & 0x1) != 0;

        val >>= 1;
        val |= @as(u8, @intFromBool(carry)) << 7;

        const flags = FlagRegister
            .default()
            .set_zero(@intFromBool(val == 0))
            .set_carry(@intFromBool(carry));

        self.registers.update_flags(flags);
        return val;
    }

    fn alu_rrc_reg(self: *Self, reg: SingleRegister) void {
        const r = self.registers.read_single(reg);
        const res = self.alu_rrc(r);

        self.registers.assign_single(reg, res);
    }

    fn alu_rr(self: *Self, v: u8) u8 {
        var val = v;
        const carry = (val & 0x1) != 0;
        const f_carry = self.registers.read_flags().carry;

        val >>= 1;
        val |= @as(u8, f_carry) << 7;

        const flags = FlagRegister
            .default()
            .set_zero(@intFromBool(val == 0))
            .set_carry(@intFromBool(carry));

        self.registers.update_flags(flags);
        return val;
    }

    fn alu_rr_reg(self: *Self, reg: SingleRegister) void {
        const r = self.registers.read_single(reg);
        const res = self.alu_rr(r);

        self.registers.assign_single(reg, res);
    }

    fn alu_sla(self: *Self, v: u8) u8 {
        var val = v;
        const carry = (val & (1 << 7)) != 0;

        val <<= 1;
        const flags = FlagRegister
            .default()
            .set_zero(@intFromBool(val == 0))
            .set_carry(@intFromBool(carry));

        self.registers.update_flags(flags);
        return val;
    }

    fn alu_sla_reg(self: *Self, reg: SingleRegister) void {
        const r = self.registers.read_single(reg);
        const res = self.alu_sla(r);

        self.registers.assign_single(reg, res);
    }

    fn alu_sra(self: *Self, v: u8) u8 {
        var val = v;
        const msb = val & (1 << 7);
        const lsb = val & 0x1;

        val = val >> 1 | msb;
        const flags = FlagRegister
            .default()
            .set_zero(@intFromBool(val == 0))
            .set_carry(@truncate(lsb));

        self.registers.update_flags(flags);
        return val;
    }

    fn alu_sra_reg(self: *Self, reg: SingleRegister) void {
        const r = self.registers.read_single(reg);
        const res = self.alu_sra(r);

        self.registers.assign_single(reg, res);
    }

    fn alu_srl(self: *Self, v: u8) u8 {
        var val = v;
        const lsb = val & 0x1;

        val >>= 1;
        const flags = FlagRegister
            .default()
            .set_zero(@intFromBool(val == 0))
            .set_carry(@truncate(lsb));

        self.registers.update_flags(flags);
        return val;
    }

    fn alu_srl_reg(self: *Self, reg: SingleRegister) void {
        const r = self.registers.read_single(reg);
        const res = self.alu_srl(r);

        self.registers.assign_single(reg, res);
    }

    fn alu_cp(self: *Self, val: u8) void {
        const a = self.registers.read_single(SingleRegister.A);

        const flags = FlagRegister
            .default()
            .set_zero(@intFromBool(val == a))
            .set_sub(1)
            .set_carry(@intFromBool(a < val))
            .set_half_curry(@intFromBool((a & 0xF) < (val & 0xF)));

        self.registers.update_flags(flags);
    }

    fn alu_test_bit(self: *Self, val: u8, bit: u8) void {
        const set = (val & (@as(u8, 1) << @truncate(bit))) != 0;
        const flags = self.registers.read_flags().set_zero(@intFromBool(!set)).set_sub(0).set_half_curry(1);

        self.registers.update_flags(flags);
    }

    fn alu_reset_bit(self: *Self, val: u8, bit: u8) u8 {
        _ = self;
        return val & ~(@as(u8, 1) << @truncate(bit));
    }

    fn alu_set_bit(self: *Self, val: u8, bit: u8) u8 {
        _ = self;
        return val | (@as(u8, 1) << @truncate(bit));
    }

    fn stack_push(self: *Self, val: u16) void {
        self.registers.sp -= 2;
        self.memory.write(u16, self.registers.sp, val);
    }

    fn stack_pop(self: *Self) u16 {
        const val = self.memory_read_u16(self.registers.sp);

        // std.debug.print("POP VAL {x}", .{val});
        self.registers.sp += 2;
        return val;
    }

    fn advance_pc(self: *Self) u8 {
        const i = self.memory_read_u8(self.registers.pc);

        self.registers.pc += 1;
        return i;
    }

    fn advance_pc16(self: *Self) u16 {
        const low = self.advance_pc();
        const high = self.advance_pc();
        const val = low | @as(u16, high) << 8;

        return val;
    }

    fn ret(self: *Self) void {
        const lr = self.stack_pop();

        self.registers.pc = lr;
    }

    fn call(self: *Self) void {
        self.stack_push(self.registers.pc);
        self.registers.pc = self.off;
    }

    fn ld(self: *Self, reg: SingleRegister, val: u8) void {
        self.registers.assign_single(reg, val);
    }

    fn if_carry(self: *Self, do: *const fn (self: *Self) void, val: u1) void {
        const carry = self.registers.read_flags().carry;

        if (carry == val) {
            self.cond = true;
            do(self);
        }
    }

    fn if_zero(self: *Self, do: *const fn (self: *Self) void, val: u1) void {
        const zero = self.registers.read_flags().zero;

        if (zero == val) {
            self.cond = true;
            do(self);
        }
    }

    fn add_pc(self: *Self) void {
        self.registers.pc +%= self.off;
    }

    fn set_pc(self: *Self) void {
        self.registers.pc = self.off;
    }

    fn handle_irq(self: *Self) u8 {
        // It should be possible to handle irq while halted
        if ((self.ei or self.halted) == false)
            return 0;

        const fired = self.memory.iff & self.memory.ie;
        if (fired == 0)
            return 0;

        const isr_base: u16 = 0x0040;
        const irq_num = 7 - @clz(fired);
        std.debug.assert(irq_num < 5);

        // Jump to ISR
        //
        // NOTE: if EI is set to false, then don't jump to ISR, but continue execution
        // from the old pc
        if (self.ei == true) {
            // Push current PC to stack
            const pc = self.registers.pc;
            self.stack_push(pc);

            // Clear IFF
            self.memory.iff &= ~(@as(u8, 1) << @truncate(irq_num));

            // Jump to ISR
            self.registers.pc = isr_base + @as(u16, irq_num) * 8;

            // Disable irqs
            self.ei = false;
        }

        // Reset halted mode
        self.halted = false;
        return 4;
    }

    pub fn tick(self: *Self) void {
        var ticks = self.handle_irq();

        if (ticks == 0 and !self.halted) {
            ticks += self.execute_one();
            if (self.debug)
                std.debug.print("Ticks {x}\n", .{ticks});
        }

        if (self.halted and ticks == 0)
            ticks = 1;

        self.memory.tick(ticks * 4);
    }

    pub fn execute_one(self: *Self) u8 {
        const i = self.advance_pc();
        var next: ?u8 = null;

        self.off = 0;
        self.cond = false;

        if (self.debug)
            std.debug.print("Executing {x}", .{i});

        switch (i) {
            // Add instructions
            0x87 => |_| self.alu_add(self.registers.read_single(SingleRegister.A)),
            0x80 => |_| self.alu_add(self.registers.read_single(SingleRegister.B)),
            0x81 => |_| self.alu_add(self.registers.read_single(SingleRegister.C)),
            0x82 => |_| self.alu_add(self.registers.read_single(SingleRegister.D)),
            0x83 => |_| self.alu_add(self.registers.read_single(SingleRegister.E)),
            0x84 => |_| self.alu_add(self.registers.read_single(SingleRegister.H)),
            0x85 => |_| self.alu_add(self.registers.read_single(SingleRegister.L)),
            0x86 => |_| self.alu_add(self.read_memory_hl()),
            0xC6 => |_| self.alu_add(self.advance_pc()),

            // Adc instructions
            0x8f => |_| self.alu_addc(self.registers.read_single(SingleRegister.A)),
            0x88 => |_| self.alu_addc(self.registers.read_single(SingleRegister.B)),
            0x89 => |_| self.alu_addc(self.registers.read_single(SingleRegister.C)),
            0x8A => |_| self.alu_addc(self.registers.read_single(SingleRegister.D)),
            0x8B => |_| self.alu_addc(self.registers.read_single(SingleRegister.E)),
            0x8C => |_| self.alu_addc(self.registers.read_single(SingleRegister.H)),
            0x8D => |_| self.alu_addc(self.registers.read_single(SingleRegister.L)),
            0x8E => |_| self.alu_addc(self.read_memory_hl()),
            0xCE => |_| self.alu_addc(self.advance_pc()),

            // Sub instructions
            0x97 => |_| self.alu_sub(self.registers.read_single(SingleRegister.A)),
            0x90 => |_| self.alu_sub(self.registers.read_single(SingleRegister.B)),
            0x91 => |_| self.alu_sub(self.registers.read_single(SingleRegister.C)),
            0x92 => |_| self.alu_sub(self.registers.read_single(SingleRegister.D)),
            0x93 => |_| self.alu_sub(self.registers.read_single(SingleRegister.E)),
            0x94 => |_| self.alu_sub(self.registers.read_single(SingleRegister.H)),
            0x95 => |_| self.alu_sub(self.registers.read_single(SingleRegister.L)),
            0x96 => |_| self.alu_sub(self.read_memory_hl()),
            0xD6 => |_| self.alu_sub(self.advance_pc()),

            // Subc instructions
            0x9F => |_| self.alu_subc(self.registers.read_single(SingleRegister.A)),
            0x98 => |_| self.alu_subc(self.registers.read_single(SingleRegister.B)),
            0x99 => |_| self.alu_subc(self.registers.read_single(SingleRegister.C)),
            0x9A => |_| self.alu_subc(self.registers.read_single(SingleRegister.D)),
            0x9B => |_| self.alu_subc(self.registers.read_single(SingleRegister.E)),
            0x9C => |_| self.alu_subc(self.registers.read_single(SingleRegister.H)),
            0x9D => |_| self.alu_subc(self.registers.read_single(SingleRegister.L)),
            0x9E => |_| self.alu_subc(self.read_memory_hl()),
            0xDE => |_| self.alu_subc(self.advance_pc()),

            // And instructions
            0xA7 => |_| self.alu_and(self.registers.read_single(SingleRegister.A)),
            0xA0 => |_| self.alu_and(self.registers.read_single(SingleRegister.B)),
            0xA1 => |_| self.alu_and(self.registers.read_single(SingleRegister.C)),
            0xA2 => |_| self.alu_and(self.registers.read_single(SingleRegister.D)),
            0xA3 => |_| self.alu_and(self.registers.read_single(SingleRegister.E)),
            0xA4 => |_| self.alu_and(self.registers.read_single(SingleRegister.H)),
            0xA5 => |_| self.alu_and(self.registers.read_single(SingleRegister.L)),
            0xA6 => |_| self.alu_and(self.read_memory_hl()),
            0xE6 => |_| self.alu_and(self.advance_pc()),

            // Or instructions
            0xB7 => |_| self.alu_or(self.registers.read_single(SingleRegister.A)),
            0xB0 => |_| self.alu_or(self.registers.read_single(SingleRegister.B)),
            0xB1 => |_| self.alu_or(self.registers.read_single(SingleRegister.C)),
            0xB2 => |_| self.alu_or(self.registers.read_single(SingleRegister.D)),
            0xB3 => |_| self.alu_or(self.registers.read_single(SingleRegister.E)),
            0xB4 => |_| self.alu_or(self.registers.read_single(SingleRegister.H)),
            0xB5 => |_| self.alu_or(self.registers.read_single(SingleRegister.L)),
            0xB6 => |_| self.alu_or(self.read_memory_hl()),
            0xF6 => |_| self.alu_or(self.advance_pc()),

            // Xor instructions
            0xAF => |_| self.alu_xor(self.registers.read_single(SingleRegister.A)),
            0xA8 => |_| self.alu_xor(self.registers.read_single(SingleRegister.B)),
            0xA9 => |_| self.alu_xor(self.registers.read_single(SingleRegister.C)),
            0xAA => |_| self.alu_xor(self.registers.read_single(SingleRegister.D)),
            0xAB => |_| self.alu_xor(self.registers.read_single(SingleRegister.E)),
            0xAC => |_| self.alu_xor(self.registers.read_single(SingleRegister.H)),
            0xAD => |_| self.alu_xor(self.registers.read_single(SingleRegister.L)),
            0xAE => |_| self.alu_xor(self.read_memory_hl()),
            0xEE => |_| self.alu_xor(self.advance_pc()),

            // Inc instructions
            0x3C => |_| self.alu_inc_reg(SingleRegister.A),
            0x04 => |_| self.alu_inc_reg(SingleRegister.B),
            0x0C => |_| self.alu_inc_reg(SingleRegister.C),
            0x14 => |_| self.alu_inc_reg(SingleRegister.D),
            0x1C => |_| self.alu_inc_reg(SingleRegister.E),
            0x24 => |_| self.alu_inc_reg(SingleRegister.H),
            0x2C => |_| self.alu_inc_reg(SingleRegister.L),
            0x34 => |_| self.alu_inc_memory_hl(),

            // Dec instructions
            0x3D => |_| self.alu_dec_reg(SingleRegister.A),
            0x05 => |_| self.alu_dec_reg(SingleRegister.B),
            0x0D => |_| self.alu_dec_reg(SingleRegister.C),
            0x15 => |_| self.alu_dec_reg(SingleRegister.D),
            0x1D => |_| self.alu_dec_reg(SingleRegister.E),
            0x25 => |_| self.alu_dec_reg(SingleRegister.H),
            0x2D => |_| self.alu_dec_reg(SingleRegister.L),
            0x35 => |_| self.alu_dec_memory_hl(),

            // Add16 instructions
            0x09 => |_| self.alu_add16_hl(PairRegister.BC),
            0x19 => |_| self.alu_add16_hl(PairRegister.DE),
            0x29 => |_| self.alu_add16_hl(PairRegister.HL),
            0x39 => |_| {
                const hl = self.registers.read_double(PairRegister.HL);
                const res = self.alu_add16(hl, self.registers.sp);

                self.registers.assign_double(PairRegister.HL, res);
            },

            // Add to SP
            0xE8 => |_| self.registers.sp = self.alu_add16_imm(self.registers.sp),
            // LDHL SP,n ( hl = sp + n )
            0xF8 => {
                const res = self.alu_add16_imm(self.registers.sp);

                self.registers.assign_double(PairRegister.HL, res);
            },

            // Inc 16bit
            0x03 => |_| self.alu_inc16(PairRegister.BC),
            0x13 => |_| self.alu_inc16(PairRegister.DE),
            0x23 => |_| self.alu_inc16(PairRegister.HL),
            0x33 => |_| self.registers.sp +%= 1,

            // Dec 16bit
            0x0B => |_| self.alu_dec16(PairRegister.BC),
            0x1B => |_| self.alu_dec16(PairRegister.DE),
            0x2B => |_| self.alu_dec16(PairRegister.HL),
            0x3B => |_| self.registers.sp -%= 1,

            // Swap nibble
            0xCB => |_| {
                next = self.advance_pc();

                // std.debug.print("{x}\n", .{next});
                switch (next.?) {
                    0x37 => |_| self.alu_swap_nibble_reg(SingleRegister.A),
                    0x30 => |_| self.alu_swap_nibble_reg(SingleRegister.B),
                    0x31 => |_| self.alu_swap_nibble_reg(SingleRegister.C),
                    0x32 => |_| self.alu_swap_nibble_reg(SingleRegister.D),
                    0x33 => |_| self.alu_swap_nibble_reg(SingleRegister.E),
                    0x34 => |_| self.alu_swap_nibble_reg(SingleRegister.H),
                    0x35 => |_| self.alu_swap_nibble_reg(SingleRegister.L),
                    0x36 => |_| self.alu_swap_nibble_hl(),
                    0x07 => |_| self.alu_rlc_reg(SingleRegister.A),
                    0x00 => |_| self.alu_rlc_reg(SingleRegister.B),
                    0x01 => |_| self.alu_rlc_reg(SingleRegister.C),
                    0x02 => |_| self.alu_rlc_reg(SingleRegister.D),
                    0x03 => |_| self.alu_rlc_reg(SingleRegister.E),
                    0x04 => |_| self.alu_rlc_reg(SingleRegister.H),
                    0x05 => |_| self.alu_rlc_reg(SingleRegister.L),
                    0x06 => |_| {
                        const hl = self.read_memory_hl();
                        const res = self.alu_rlc(hl);

                        self.write_memory_hl(res);
                    },
                    0x17 => |_| self.alu_rl_reg(SingleRegister.A),
                    0x10 => |_| self.alu_rl_reg(SingleRegister.B),
                    0x11 => |_| self.alu_rl_reg(SingleRegister.C),
                    0x12 => |_| self.alu_rl_reg(SingleRegister.D),
                    0x13 => |_| self.alu_rl_reg(SingleRegister.E),
                    0x14 => |_| self.alu_rl_reg(SingleRegister.H),
                    0x15 => |_| self.alu_rl_reg(SingleRegister.L),
                    0x16 => |_| {
                        const hl = self.read_memory_hl();
                        const res = self.alu_rl(hl);

                        self.write_memory_hl(res);
                    },
                    0x0F => |_| self.alu_rrc_reg(SingleRegister.A),
                    0x08 => |_| self.alu_rrc_reg(SingleRegister.B),
                    0x09 => |_| self.alu_rrc_reg(SingleRegister.C),
                    0x0A => |_| self.alu_rrc_reg(SingleRegister.D),
                    0x0B => |_| self.alu_rrc_reg(SingleRegister.E),
                    0x0C => |_| self.alu_rrc_reg(SingleRegister.H),
                    0x0D => |_| self.alu_rrc_reg(SingleRegister.L),
                    0x0E => |_| {
                        const hl = self.read_memory_hl();
                        const res = self.alu_rrc(hl);

                        self.write_memory_hl(res);
                    },
                    0x1F => |_| self.alu_rr_reg(SingleRegister.A),
                    0x18 => |_| self.alu_rr_reg(SingleRegister.B),
                    0x19 => |_| self.alu_rr_reg(SingleRegister.C),
                    0x1A => |_| self.alu_rr_reg(SingleRegister.D),
                    0x1B => |_| self.alu_rr_reg(SingleRegister.E),
                    0x1C => |_| self.alu_rr_reg(SingleRegister.H),
                    0x1D => |_| self.alu_rr_reg(SingleRegister.L),
                    0x1E => |_| {
                        const hl = self.read_memory_hl();
                        const res = self.alu_rr(hl);

                        self.write_memory_hl(res);
                    },
                    0x27 => |_| self.alu_sla_reg(SingleRegister.A),
                    0x20 => |_| self.alu_sla_reg(SingleRegister.B),
                    0x21 => |_| self.alu_sla_reg(SingleRegister.C),
                    0x22 => |_| self.alu_sla_reg(SingleRegister.D),
                    0x23 => |_| self.alu_sla_reg(SingleRegister.E),
                    0x24 => |_| self.alu_sla_reg(SingleRegister.H),
                    0x25 => |_| self.alu_sla_reg(SingleRegister.L),
                    0x26 => |_| {
                        const hl = self.read_memory_hl();
                        const res = self.alu_sla(hl);

                        self.write_memory_hl(res);
                    },
                    0x2F => |_| self.alu_sra_reg(SingleRegister.A),
                    0x28 => |_| self.alu_sra_reg(SingleRegister.B),
                    0x29 => |_| self.alu_sra_reg(SingleRegister.C),
                    0x2A => |_| self.alu_sra_reg(SingleRegister.D),
                    0x2B => |_| self.alu_sra_reg(SingleRegister.E),
                    0x2C => |_| self.alu_sra_reg(SingleRegister.H),
                    0x2D => |_| self.alu_sra_reg(SingleRegister.L),
                    0x2E => |_| {
                        const hl = self.read_memory_hl();
                        const res = self.alu_sra(hl);

                        self.write_memory_hl(res);
                    },
                    0x3F => |_| self.alu_srl_reg(SingleRegister.A),
                    0x38 => |_| self.alu_srl_reg(SingleRegister.B),
                    0x39 => |_| self.alu_srl_reg(SingleRegister.C),
                    0x3A => |_| self.alu_srl_reg(SingleRegister.D),
                    0x3B => |_| self.alu_srl_reg(SingleRegister.E),
                    0x3C => |_| self.alu_srl_reg(SingleRegister.H),
                    0x3D => |_| self.alu_srl_reg(SingleRegister.L),
                    0x3E => |_| {
                        const hl = self.read_memory_hl();
                        const res = self.alu_srl(hl);

                        self.write_memory_hl(res);
                    },

                    // Bit ops

                    // Test
                    0x40 => self.alu_test_bit(self.registers.read_single(SingleRegister.B), 0),
                    0x41 => self.alu_test_bit(self.registers.read_single(SingleRegister.C), 0),
                    0x42 => self.alu_test_bit(self.registers.read_single(SingleRegister.D), 0),
                    0x43 => self.alu_test_bit(self.registers.read_single(SingleRegister.E), 0),
                    0x44 => self.alu_test_bit(self.registers.read_single(SingleRegister.H), 0),
                    0x45 => self.alu_test_bit(self.registers.read_single(SingleRegister.L), 0),
                    0x46 => {
                        const val = self.read_memory_hl();
                        self.alu_test_bit(val, 0);
                    },

                    0x48 => self.alu_test_bit(self.registers.read_single(SingleRegister.B), 1),
                    0x49 => self.alu_test_bit(self.registers.read_single(SingleRegister.C), 1),
                    0x4A => self.alu_test_bit(self.registers.read_single(SingleRegister.D), 1),
                    0x4B => self.alu_test_bit(self.registers.read_single(SingleRegister.E), 1),
                    0x4C => self.alu_test_bit(self.registers.read_single(SingleRegister.H), 1),
                    0x4D => self.alu_test_bit(self.registers.read_single(SingleRegister.L), 1),
                    0x4E => {
                        const val = self.read_memory_hl();
                        self.alu_test_bit(val, 1);
                    },

                    0x50 => self.alu_test_bit(self.registers.read_single(SingleRegister.B), 2),
                    0x51 => self.alu_test_bit(self.registers.read_single(SingleRegister.C), 2),
                    0x52 => self.alu_test_bit(self.registers.read_single(SingleRegister.D), 2),
                    0x53 => self.alu_test_bit(self.registers.read_single(SingleRegister.E), 2),
                    0x54 => self.alu_test_bit(self.registers.read_single(SingleRegister.H), 2),
                    0x55 => self.alu_test_bit(self.registers.read_single(SingleRegister.L), 2),
                    0x56 => {
                        const val = self.read_memory_hl();
                        self.alu_test_bit(val, 2);
                    },

                    0x58 => self.alu_test_bit(self.registers.read_single(SingleRegister.B), 3),
                    0x59 => self.alu_test_bit(self.registers.read_single(SingleRegister.C), 3),
                    0x5A => self.alu_test_bit(self.registers.read_single(SingleRegister.D), 3),
                    0x5B => self.alu_test_bit(self.registers.read_single(SingleRegister.E), 3),
                    0x5C => self.alu_test_bit(self.registers.read_single(SingleRegister.H), 3),
                    0x5D => self.alu_test_bit(self.registers.read_single(SingleRegister.L), 3),
                    0x5E => {
                        const val = self.read_memory_hl();
                        self.alu_test_bit(val, 3);
                    },

                    0x60 => self.alu_test_bit(self.registers.read_single(SingleRegister.B), 4),
                    0x61 => self.alu_test_bit(self.registers.read_single(SingleRegister.C), 4),
                    0x62 => self.alu_test_bit(self.registers.read_single(SingleRegister.D), 4),
                    0x63 => self.alu_test_bit(self.registers.read_single(SingleRegister.E), 4),
                    0x64 => self.alu_test_bit(self.registers.read_single(SingleRegister.H), 4),
                    0x65 => self.alu_test_bit(self.registers.read_single(SingleRegister.L), 4),
                    0x66 => {
                        const val = self.read_memory_hl();
                        self.alu_test_bit(val, 4);
                    },

                    0x68 => self.alu_test_bit(self.registers.read_single(SingleRegister.B), 5),
                    0x69 => self.alu_test_bit(self.registers.read_single(SingleRegister.C), 5),
                    0x6A => self.alu_test_bit(self.registers.read_single(SingleRegister.D), 5),
                    0x6B => self.alu_test_bit(self.registers.read_single(SingleRegister.E), 5),
                    0x6C => self.alu_test_bit(self.registers.read_single(SingleRegister.H), 5),
                    0x6D => self.alu_test_bit(self.registers.read_single(SingleRegister.L), 5),
                    0x6E => {
                        const val = self.read_memory_hl();
                        self.alu_test_bit(val, 5);
                    },

                    0x70 => self.alu_test_bit(self.registers.read_single(SingleRegister.B), 6),
                    0x71 => self.alu_test_bit(self.registers.read_single(SingleRegister.C), 6),
                    0x72 => self.alu_test_bit(self.registers.read_single(SingleRegister.D), 6),
                    0x73 => self.alu_test_bit(self.registers.read_single(SingleRegister.E), 6),
                    0x74 => self.alu_test_bit(self.registers.read_single(SingleRegister.H), 6),
                    0x75 => self.alu_test_bit(self.registers.read_single(SingleRegister.L), 6),
                    0x76 => {
                        const val = self.read_memory_hl();
                        self.alu_test_bit(val, 6);
                    },

                    0x78 => self.alu_test_bit(self.registers.read_single(SingleRegister.B), 7),
                    0x79 => self.alu_test_bit(self.registers.read_single(SingleRegister.C), 7),
                    0x7A => self.alu_test_bit(self.registers.read_single(SingleRegister.D), 7),
                    0x7B => self.alu_test_bit(self.registers.read_single(SingleRegister.E), 7),
                    0x7C => self.alu_test_bit(self.registers.read_single(SingleRegister.H), 7),
                    0x7D => self.alu_test_bit(self.registers.read_single(SingleRegister.L), 7),
                    0x7E => {
                        const val = self.read_memory_hl();
                        self.alu_test_bit(val, 7);
                    },

                    0x47 => self.alu_test_bit(self.registers.read_single(SingleRegister.A), 0),
                    0x4F => self.alu_test_bit(self.registers.read_single(SingleRegister.A), 1),
                    0x57 => self.alu_test_bit(self.registers.read_single(SingleRegister.A), 2),
                    0x5F => self.alu_test_bit(self.registers.read_single(SingleRegister.A), 3),
                    0x67 => self.alu_test_bit(self.registers.read_single(SingleRegister.A), 4),
                    0x6F => self.alu_test_bit(self.registers.read_single(SingleRegister.A), 5),
                    0x77 => self.alu_test_bit(self.registers.read_single(SingleRegister.A), 6),
                    0x7F => self.alu_test_bit(self.registers.read_single(SingleRegister.A), 7),

                    // Reset
                    0x80 => self.registers.assign_single(SingleRegister.B, self.alu_reset_bit(self.registers.read_single(SingleRegister.B), 0)),
                    0x81 => self.registers.assign_single(SingleRegister.C, self.alu_reset_bit(self.registers.read_single(SingleRegister.C), 0)),
                    0x82 => self.registers.assign_single(SingleRegister.D, self.alu_reset_bit(self.registers.read_single(SingleRegister.D), 0)),
                    0x83 => self.registers.assign_single(SingleRegister.E, self.alu_reset_bit(self.registers.read_single(SingleRegister.E), 0)),
                    0x84 => self.registers.assign_single(SingleRegister.H, self.alu_reset_bit(self.registers.read_single(SingleRegister.H), 0)),
                    0x85 => self.registers.assign_single(SingleRegister.L, self.alu_reset_bit(self.registers.read_single(SingleRegister.L), 0)),
                    0x86 => {
                        const val = self.read_memory_hl();
                        const res = self.alu_reset_bit(val, 0);

                        self.write_memory_hl(res);
                    },

                    0x88 => self.registers.assign_single(SingleRegister.B, self.alu_reset_bit(self.registers.read_single(SingleRegister.B), 1)),
                    0x89 => self.registers.assign_single(SingleRegister.C, self.alu_reset_bit(self.registers.read_single(SingleRegister.C), 1)),
                    0x8A => self.registers.assign_single(SingleRegister.D, self.alu_reset_bit(self.registers.read_single(SingleRegister.D), 1)),
                    0x8B => self.registers.assign_single(SingleRegister.E, self.alu_reset_bit(self.registers.read_single(SingleRegister.E), 1)),
                    0x8C => self.registers.assign_single(SingleRegister.H, self.alu_reset_bit(self.registers.read_single(SingleRegister.H), 1)),
                    0x8D => self.registers.assign_single(SingleRegister.L, self.alu_reset_bit(self.registers.read_single(SingleRegister.L), 1)),
                    0x8E => {
                        const val = self.read_memory_hl();
                        const res = self.alu_reset_bit(val, 1);

                        self.write_memory_hl(res);
                    },

                    0x90 => self.registers.assign_single(SingleRegister.B, self.alu_reset_bit(self.registers.read_single(SingleRegister.B), 2)),
                    0x91 => self.registers.assign_single(SingleRegister.C, self.alu_reset_bit(self.registers.read_single(SingleRegister.C), 2)),
                    0x92 => self.registers.assign_single(SingleRegister.D, self.alu_reset_bit(self.registers.read_single(SingleRegister.D), 2)),
                    0x93 => self.registers.assign_single(SingleRegister.E, self.alu_reset_bit(self.registers.read_single(SingleRegister.E), 2)),
                    0x94 => self.registers.assign_single(SingleRegister.H, self.alu_reset_bit(self.registers.read_single(SingleRegister.H), 2)),
                    0x95 => self.registers.assign_single(SingleRegister.L, self.alu_reset_bit(self.registers.read_single(SingleRegister.L), 2)),
                    0x96 => {
                        const val = self.read_memory_hl();
                        const res = self.alu_reset_bit(val, 2);

                        self.write_memory_hl(res);
                    },

                    0x98 => self.registers.assign_single(SingleRegister.B, self.alu_reset_bit(self.registers.read_single(SingleRegister.B), 3)),
                    0x99 => self.registers.assign_single(SingleRegister.C, self.alu_reset_bit(self.registers.read_single(SingleRegister.C), 3)),
                    0x9A => self.registers.assign_single(SingleRegister.D, self.alu_reset_bit(self.registers.read_single(SingleRegister.D), 3)),
                    0x9B => self.registers.assign_single(SingleRegister.E, self.alu_reset_bit(self.registers.read_single(SingleRegister.E), 3)),
                    0x9C => self.registers.assign_single(SingleRegister.H, self.alu_reset_bit(self.registers.read_single(SingleRegister.H), 3)),
                    0x9D => self.registers.assign_single(SingleRegister.L, self.alu_reset_bit(self.registers.read_single(SingleRegister.L), 3)),
                    0x9E => {
                        const val = self.read_memory_hl();
                        const res = self.alu_reset_bit(val, 3);

                        self.write_memory_hl(res);
                    },

                    0xA0 => self.registers.assign_single(SingleRegister.B, self.alu_reset_bit(self.registers.read_single(SingleRegister.B), 4)),
                    0xA1 => self.registers.assign_single(SingleRegister.C, self.alu_reset_bit(self.registers.read_single(SingleRegister.C), 4)),
                    0xA2 => self.registers.assign_single(SingleRegister.D, self.alu_reset_bit(self.registers.read_single(SingleRegister.D), 4)),
                    0xA3 => self.registers.assign_single(SingleRegister.E, self.alu_reset_bit(self.registers.read_single(SingleRegister.E), 4)),
                    0xA4 => self.registers.assign_single(SingleRegister.H, self.alu_reset_bit(self.registers.read_single(SingleRegister.H), 4)),
                    0xA5 => self.registers.assign_single(SingleRegister.L, self.alu_reset_bit(self.registers.read_single(SingleRegister.L), 4)),
                    0xA6 => {
                        const val = self.read_memory_hl();
                        const res = self.alu_reset_bit(val, 4);

                        self.write_memory_hl(res);
                    },

                    0xA8 => self.registers.assign_single(SingleRegister.B, self.alu_reset_bit(self.registers.read_single(SingleRegister.B), 5)),
                    0xA9 => self.registers.assign_single(SingleRegister.C, self.alu_reset_bit(self.registers.read_single(SingleRegister.C), 5)),
                    0xAA => self.registers.assign_single(SingleRegister.D, self.alu_reset_bit(self.registers.read_single(SingleRegister.D), 5)),
                    0xAB => self.registers.assign_single(SingleRegister.E, self.alu_reset_bit(self.registers.read_single(SingleRegister.E), 5)),
                    0xAC => self.registers.assign_single(SingleRegister.H, self.alu_reset_bit(self.registers.read_single(SingleRegister.H), 5)),
                    0xAD => self.registers.assign_single(SingleRegister.L, self.alu_reset_bit(self.registers.read_single(SingleRegister.L), 5)),
                    0xAE => {
                        const val = self.read_memory_hl();
                        const res = self.alu_reset_bit(val, 5);

                        self.write_memory_hl(res);
                    },

                    0xB0 => self.registers.assign_single(SingleRegister.B, self.alu_reset_bit(self.registers.read_single(SingleRegister.B), 6)),
                    0xB1 => self.registers.assign_single(SingleRegister.C, self.alu_reset_bit(self.registers.read_single(SingleRegister.C), 6)),
                    0xB2 => self.registers.assign_single(SingleRegister.D, self.alu_reset_bit(self.registers.read_single(SingleRegister.D), 6)),
                    0xB3 => self.registers.assign_single(SingleRegister.E, self.alu_reset_bit(self.registers.read_single(SingleRegister.E), 6)),
                    0xB4 => self.registers.assign_single(SingleRegister.H, self.alu_reset_bit(self.registers.read_single(SingleRegister.H), 6)),
                    0xB5 => self.registers.assign_single(SingleRegister.L, self.alu_reset_bit(self.registers.read_single(SingleRegister.L), 6)),
                    0xB6 => {
                        const val = self.read_memory_hl();
                        const res = self.alu_reset_bit(val, 6);

                        self.write_memory_hl(res);
                    },

                    0xB8 => self.registers.assign_single(SingleRegister.B, self.alu_reset_bit(self.registers.read_single(SingleRegister.B), 7)),
                    0xB9 => self.registers.assign_single(SingleRegister.C, self.alu_reset_bit(self.registers.read_single(SingleRegister.C), 7)),
                    0xBA => self.registers.assign_single(SingleRegister.D, self.alu_reset_bit(self.registers.read_single(SingleRegister.D), 7)),
                    0xBB => self.registers.assign_single(SingleRegister.E, self.alu_reset_bit(self.registers.read_single(SingleRegister.E), 7)),
                    0xBC => self.registers.assign_single(SingleRegister.H, self.alu_reset_bit(self.registers.read_single(SingleRegister.H), 7)),
                    0xBD => self.registers.assign_single(SingleRegister.L, self.alu_reset_bit(self.registers.read_single(SingleRegister.L), 7)),
                    0xBE => {
                        const val = self.read_memory_hl();
                        const res = self.alu_reset_bit(val, 5);

                        self.write_memory_hl(res);
                    },

                    0x87 => self.registers.assign_single(SingleRegister.A, self.alu_reset_bit(self.registers.read_single(SingleRegister.A), 0)),
                    0x8F => self.registers.assign_single(SingleRegister.A, self.alu_reset_bit(self.registers.read_single(SingleRegister.A), 1)),
                    0x97 => self.registers.assign_single(SingleRegister.A, self.alu_reset_bit(self.registers.read_single(SingleRegister.A), 2)),
                    0x9F => self.registers.assign_single(SingleRegister.A, self.alu_reset_bit(self.registers.read_single(SingleRegister.A), 3)),
                    0xA7 => self.registers.assign_single(SingleRegister.A, self.alu_reset_bit(self.registers.read_single(SingleRegister.A), 4)),
                    0xAF => self.registers.assign_single(SingleRegister.A, self.alu_reset_bit(self.registers.read_single(SingleRegister.A), 5)),
                    0xB7 => self.registers.assign_single(SingleRegister.A, self.alu_reset_bit(self.registers.read_single(SingleRegister.A), 6)),
                    0xBF => self.registers.assign_single(SingleRegister.A, self.alu_reset_bit(self.registers.read_single(SingleRegister.A), 7)),

                    // Set
                    0xC0 => self.registers.assign_single(SingleRegister.B, self.alu_set_bit(self.registers.read_single(SingleRegister.B), 0)),
                    0xC1 => self.registers.assign_single(SingleRegister.C, self.alu_set_bit(self.registers.read_single(SingleRegister.C), 0)),
                    0xC2 => self.registers.assign_single(SingleRegister.D, self.alu_set_bit(self.registers.read_single(SingleRegister.D), 0)),
                    0xC3 => self.registers.assign_single(SingleRegister.E, self.alu_set_bit(self.registers.read_single(SingleRegister.E), 0)),
                    0xC4 => self.registers.assign_single(SingleRegister.H, self.alu_set_bit(self.registers.read_single(SingleRegister.H), 0)),
                    0xC5 => self.registers.assign_single(SingleRegister.L, self.alu_set_bit(self.registers.read_single(SingleRegister.L), 0)),
                    0xC6 => {
                        const val = self.read_memory_hl();
                        const res = self.alu_set_bit(val, 0);

                        self.write_memory_hl(res);
                    },

                    0xC8 => self.registers.assign_single(SingleRegister.B, self.alu_set_bit(self.registers.read_single(SingleRegister.B), 1)),
                    0xC9 => self.registers.assign_single(SingleRegister.C, self.alu_set_bit(self.registers.read_single(SingleRegister.C), 1)),
                    0xCA => self.registers.assign_single(SingleRegister.D, self.alu_set_bit(self.registers.read_single(SingleRegister.D), 1)),
                    0xCB => self.registers.assign_single(SingleRegister.E, self.alu_set_bit(self.registers.read_single(SingleRegister.E), 1)),
                    0xCC => self.registers.assign_single(SingleRegister.H, self.alu_set_bit(self.registers.read_single(SingleRegister.H), 1)),
                    0xCD => self.registers.assign_single(SingleRegister.L, self.alu_set_bit(self.registers.read_single(SingleRegister.L), 1)),
                    0xCE => {
                        const val = self.read_memory_hl();
                        const res = self.alu_set_bit(val, 1);

                        self.write_memory_hl(res);
                    },

                    0xD0 => self.registers.assign_single(SingleRegister.B, self.alu_set_bit(self.registers.read_single(SingleRegister.B), 2)),
                    0xD1 => self.registers.assign_single(SingleRegister.C, self.alu_set_bit(self.registers.read_single(SingleRegister.C), 2)),
                    0xD2 => self.registers.assign_single(SingleRegister.D, self.alu_set_bit(self.registers.read_single(SingleRegister.D), 2)),
                    0xD3 => self.registers.assign_single(SingleRegister.E, self.alu_set_bit(self.registers.read_single(SingleRegister.E), 2)),
                    0xD4 => self.registers.assign_single(SingleRegister.H, self.alu_set_bit(self.registers.read_single(SingleRegister.H), 2)),
                    0xD5 => self.registers.assign_single(SingleRegister.L, self.alu_set_bit(self.registers.read_single(SingleRegister.L), 2)),
                    0xD6 => {
                        const val = self.read_memory_hl();
                        const res = self.alu_set_bit(val, 2);

                        self.write_memory_hl(res);
                    },

                    0xD8 => self.registers.assign_single(SingleRegister.B, self.alu_set_bit(self.registers.read_single(SingleRegister.B), 3)),
                    0xD9 => self.registers.assign_single(SingleRegister.C, self.alu_set_bit(self.registers.read_single(SingleRegister.C), 3)),
                    0xDA => self.registers.assign_single(SingleRegister.D, self.alu_set_bit(self.registers.read_single(SingleRegister.D), 3)),
                    0xDB => self.registers.assign_single(SingleRegister.E, self.alu_set_bit(self.registers.read_single(SingleRegister.E), 3)),
                    0xDC => self.registers.assign_single(SingleRegister.H, self.alu_set_bit(self.registers.read_single(SingleRegister.H), 3)),
                    0xDD => self.registers.assign_single(SingleRegister.L, self.alu_set_bit(self.registers.read_single(SingleRegister.L), 3)),
                    0xDE => {
                        const val = self.read_memory_hl();
                        const res = self.alu_set_bit(val, 3);

                        self.write_memory_hl(res);
                    },

                    0xE0 => self.registers.assign_single(SingleRegister.B, self.alu_set_bit(self.registers.read_single(SingleRegister.B), 4)),
                    0xE1 => self.registers.assign_single(SingleRegister.C, self.alu_set_bit(self.registers.read_single(SingleRegister.C), 4)),
                    0xE2 => self.registers.assign_single(SingleRegister.D, self.alu_set_bit(self.registers.read_single(SingleRegister.D), 4)),
                    0xE3 => self.registers.assign_single(SingleRegister.E, self.alu_set_bit(self.registers.read_single(SingleRegister.E), 4)),
                    0xE4 => self.registers.assign_single(SingleRegister.H, self.alu_set_bit(self.registers.read_single(SingleRegister.H), 4)),
                    0xE5 => self.registers.assign_single(SingleRegister.L, self.alu_set_bit(self.registers.read_single(SingleRegister.L), 4)),
                    0xE6 => {
                        const val = self.read_memory_hl();
                        const res = self.alu_set_bit(val, 4);

                        self.write_memory_hl(res);
                    },

                    0xE8 => self.registers.assign_single(SingleRegister.B, self.alu_set_bit(self.registers.read_single(SingleRegister.B), 5)),
                    0xE9 => self.registers.assign_single(SingleRegister.C, self.alu_set_bit(self.registers.read_single(SingleRegister.C), 5)),
                    0xEA => self.registers.assign_single(SingleRegister.D, self.alu_set_bit(self.registers.read_single(SingleRegister.D), 5)),
                    0xEB => self.registers.assign_single(SingleRegister.E, self.alu_set_bit(self.registers.read_single(SingleRegister.E), 5)),
                    0xEC => self.registers.assign_single(SingleRegister.H, self.alu_set_bit(self.registers.read_single(SingleRegister.H), 5)),
                    0xED => self.registers.assign_single(SingleRegister.L, self.alu_set_bit(self.registers.read_single(SingleRegister.L), 5)),
                    0xEE => {
                        const val = self.read_memory_hl();
                        const res = self.alu_set_bit(val, 5);

                        self.write_memory_hl(res);
                    },

                    0xF0 => self.registers.assign_single(SingleRegister.B, self.alu_set_bit(self.registers.read_single(SingleRegister.B), 6)),
                    0xF1 => self.registers.assign_single(SingleRegister.C, self.alu_set_bit(self.registers.read_single(SingleRegister.C), 6)),
                    0xF2 => self.registers.assign_single(SingleRegister.D, self.alu_set_bit(self.registers.read_single(SingleRegister.D), 6)),
                    0xF3 => self.registers.assign_single(SingleRegister.E, self.alu_set_bit(self.registers.read_single(SingleRegister.E), 6)),
                    0xF4 => self.registers.assign_single(SingleRegister.H, self.alu_set_bit(self.registers.read_single(SingleRegister.H), 6)),
                    0xF5 => self.registers.assign_single(SingleRegister.L, self.alu_set_bit(self.registers.read_single(SingleRegister.L), 6)),
                    0xF6 => {
                        const val = self.read_memory_hl();
                        const res = self.alu_set_bit(val, 6);

                        self.write_memory_hl(res);
                    },

                    0xF8 => self.registers.assign_single(SingleRegister.B, self.alu_set_bit(self.registers.read_single(SingleRegister.B), 7)),
                    0xF9 => self.registers.assign_single(SingleRegister.C, self.alu_set_bit(self.registers.read_single(SingleRegister.C), 7)),
                    0xFA => self.registers.assign_single(SingleRegister.D, self.alu_set_bit(self.registers.read_single(SingleRegister.D), 7)),
                    0xFB => self.registers.assign_single(SingleRegister.E, self.alu_set_bit(self.registers.read_single(SingleRegister.E), 7)),
                    0xFC => self.registers.assign_single(SingleRegister.H, self.alu_set_bit(self.registers.read_single(SingleRegister.H), 7)),
                    0xFD => self.registers.assign_single(SingleRegister.L, self.alu_set_bit(self.registers.read_single(SingleRegister.L), 7)),
                    0xFE => {
                        const val = self.read_memory_hl();
                        const res = self.alu_set_bit(val, 7);

                        self.write_memory_hl(res);
                    },

                    0xC7 => self.registers.assign_single(SingleRegister.A, self.alu_set_bit(self.registers.read_single(SingleRegister.A), 0)),
                    0xCF => self.registers.assign_single(SingleRegister.A, self.alu_set_bit(self.registers.read_single(SingleRegister.A), 1)),
                    0xD7 => self.registers.assign_single(SingleRegister.A, self.alu_set_bit(self.registers.read_single(SingleRegister.A), 2)),
                    0xDF => self.registers.assign_single(SingleRegister.A, self.alu_set_bit(self.registers.read_single(SingleRegister.A), 3)),
                    0xE7 => self.registers.assign_single(SingleRegister.A, self.alu_set_bit(self.registers.read_single(SingleRegister.A), 4)),
                    0xEF => self.registers.assign_single(SingleRegister.A, self.alu_set_bit(self.registers.read_single(SingleRegister.A), 5)),
                    0xF7 => self.registers.assign_single(SingleRegister.A, self.alu_set_bit(self.registers.read_single(SingleRegister.A), 6)),
                    0xFF => self.registers.assign_single(SingleRegister.A, self.alu_set_bit(self.registers.read_single(SingleRegister.A), 7)),
                }
            },
            0x27 => self.alu_daa(),
            0x2F => self.alu_cpl(),
            0x3F => {
                var flags = self.registers.read_flags();

                flags = flags.set_carry(flags.carry ^ 1).set_sub(0).set_half_curry(0);
                self.registers.update_flags(flags);
            },
            0x37 => {
                const flags = self.registers.read_flags()
                    .set_carry(1)
                    .set_sub(0)
                    .set_half_curry(0);

                self.registers.update_flags(flags);
            },

            // Nop
            0x00 => {},
            // Halt
            0x76 => self.halted = true,

            // RLCA
            0x07 => {
                self.alu_rlc_reg(SingleRegister.A);

                const flags = self.registers.read_flags();
                self.registers.update_flags(flags.set_zero(0).set_half_curry(0));
            },
            // RLA
            0x17 => {
                self.alu_rl_reg(SingleRegister.A);

                const flags = self.registers.read_flags();
                self.registers.update_flags(flags.set_zero(0).set_half_curry(0));
            },
            // RRCA
            0x0F => {
                self.alu_rrc_reg(SingleRegister.A);

                const flags = self.registers.read_flags();
                self.registers.update_flags(flags.set_zero(0).set_half_curry(0));
            },
            // RRA
            0x1F => {
                self.alu_rr_reg(SingleRegister.A);

                const flags = self.registers.read_flags();
                self.registers.update_flags(flags.set_zero(0));
            },
            // LD imm8
            0x06, 0x0E, 0x16, 0x1E, 0x26, 0x2E => {
                const imm = self.advance_pc();

                switch (i) {
                    0x06 => self.registers.assign_single(SingleRegister.B, imm),
                    0x0E => self.registers.assign_single(SingleRegister.C, imm),
                    0x16 => self.registers.assign_single(SingleRegister.D, imm),
                    0x1E => self.registers.assign_single(SingleRegister.E, imm),
                    0x26 => self.registers.assign_single(SingleRegister.H, imm),
                    0x2E => self.registers.assign_single(SingleRegister.L, imm),
                    else => unreachable,
                }
            },
            // LR reg,reg
            0x7F => self.ld(SingleRegister.A, self.registers.read_single(SingleRegister.A)),
            0x78 => self.ld(SingleRegister.A, self.registers.read_single(SingleRegister.B)),
            0x79 => self.ld(SingleRegister.A, self.registers.read_single(SingleRegister.C)),
            0x7A => self.ld(SingleRegister.A, self.registers.read_single(SingleRegister.D)),
            0x7B => self.ld(SingleRegister.A, self.registers.read_single(SingleRegister.E)),
            0x7C => self.ld(SingleRegister.A, self.registers.read_single(SingleRegister.H)),
            0x7D => self.ld(SingleRegister.A, self.registers.read_single(SingleRegister.L)),
            0x7E => self.ld(SingleRegister.A, self.read_memory_hl()),
            0x47 => self.ld(SingleRegister.B, self.registers.read_single(SingleRegister.A)),
            0x40 => self.ld(SingleRegister.B, self.registers.read_single(SingleRegister.B)),
            0x41 => self.ld(SingleRegister.B, self.registers.read_single(SingleRegister.C)),
            0x42 => self.ld(SingleRegister.B, self.registers.read_single(SingleRegister.D)),
            0x43 => self.ld(SingleRegister.B, self.registers.read_single(SingleRegister.E)),
            0x44 => self.ld(SingleRegister.B, self.registers.read_single(SingleRegister.H)),
            0x45 => self.ld(SingleRegister.B, self.registers.read_single(SingleRegister.L)),
            0x46 => self.ld(SingleRegister.B, self.read_memory_hl()),
            0x4F => self.ld(SingleRegister.C, self.registers.read_single(SingleRegister.A)),
            0x48 => self.ld(SingleRegister.C, self.registers.read_single(SingleRegister.B)),
            0x49 => self.ld(SingleRegister.C, self.registers.read_single(SingleRegister.C)),
            0x4A => self.ld(SingleRegister.C, self.registers.read_single(SingleRegister.D)),
            0x4B => self.ld(SingleRegister.C, self.registers.read_single(SingleRegister.E)),
            0x4C => self.ld(SingleRegister.C, self.registers.read_single(SingleRegister.H)),
            0x4D => self.ld(SingleRegister.C, self.registers.read_single(SingleRegister.L)),
            0x4E => self.ld(SingleRegister.C, self.read_memory_hl()),
            0x57 => self.ld(SingleRegister.D, self.registers.read_single(SingleRegister.A)),
            0x50 => self.ld(SingleRegister.D, self.registers.read_single(SingleRegister.B)),
            0x51 => self.ld(SingleRegister.D, self.registers.read_single(SingleRegister.C)),
            0x52 => self.ld(SingleRegister.D, self.registers.read_single(SingleRegister.D)),
            0x53 => self.ld(SingleRegister.D, self.registers.read_single(SingleRegister.E)),
            0x54 => self.ld(SingleRegister.D, self.registers.read_single(SingleRegister.H)),
            0x55 => self.ld(SingleRegister.D, self.registers.read_single(SingleRegister.L)),
            0x56 => self.ld(SingleRegister.D, self.read_memory_hl()),
            0x5F => self.ld(SingleRegister.E, self.registers.read_single(SingleRegister.A)),
            0x58 => self.ld(SingleRegister.E, self.registers.read_single(SingleRegister.B)),
            0x59 => self.ld(SingleRegister.E, self.registers.read_single(SingleRegister.C)),
            0x5A => self.ld(SingleRegister.E, self.registers.read_single(SingleRegister.D)),
            0x5B => self.ld(SingleRegister.E, self.registers.read_single(SingleRegister.E)),
            0x5C => self.ld(SingleRegister.E, self.registers.read_single(SingleRegister.H)),
            0x5D => self.ld(SingleRegister.E, self.registers.read_single(SingleRegister.L)),
            0x5E => self.ld(SingleRegister.E, self.read_memory_hl()),
            0x67 => self.ld(SingleRegister.H, self.registers.read_single(SingleRegister.A)),
            0x60 => self.ld(SingleRegister.H, self.registers.read_single(SingleRegister.B)),
            0x61 => self.ld(SingleRegister.H, self.registers.read_single(SingleRegister.C)),
            0x62 => self.ld(SingleRegister.H, self.registers.read_single(SingleRegister.D)),
            0x63 => self.ld(SingleRegister.H, self.registers.read_single(SingleRegister.E)),
            0x64 => self.ld(SingleRegister.H, self.registers.read_single(SingleRegister.H)),
            0x65 => self.ld(SingleRegister.H, self.registers.read_single(SingleRegister.L)),
            0x66 => self.ld(SingleRegister.H, self.read_memory_hl()),
            0x6F => self.ld(SingleRegister.L, self.registers.read_single(SingleRegister.A)),
            0x68 => self.ld(SingleRegister.L, self.registers.read_single(SingleRegister.B)),
            0x69 => self.ld(SingleRegister.L, self.registers.read_single(SingleRegister.C)),
            0x6A => self.ld(SingleRegister.L, self.registers.read_single(SingleRegister.D)),
            0x6B => self.ld(SingleRegister.L, self.registers.read_single(SingleRegister.E)),
            0x6C => self.ld(SingleRegister.L, self.registers.read_single(SingleRegister.H)),
            0x6D => self.ld(SingleRegister.L, self.registers.read_single(SingleRegister.L)),
            0x6E => self.ld(SingleRegister.L, self.read_memory_hl()),
            0x70 => self.write_memory_hl(self.registers.read_single(SingleRegister.B)),
            0x71 => self.write_memory_hl(self.registers.read_single(SingleRegister.C)),
            0x72 => self.write_memory_hl(self.registers.read_single(SingleRegister.D)),
            0x73 => self.write_memory_hl(self.registers.read_single(SingleRegister.E)),
            0x74 => self.write_memory_hl(self.registers.read_single(SingleRegister.H)),
            0x75 => self.write_memory_hl(self.registers.read_single(SingleRegister.L)),
            0x36 => {
                const imm = self.memory_read_u8(self.registers.pc);
                self.registers.pc += 1;

                self.write_memory_hl(imm);
            },

            // LD A, n
            0x0A => {
                self.registers.assign_single(SingleRegister.A, self.memory_read_u8(self.registers.read_double(PairRegister.BC)));
            },
            0x1A => {
                self.registers.assign_single(SingleRegister.A, self.memory_read_u8(self.registers.read_double(PairRegister.DE)));
            },
            0xFA => {
                const addr = self.advance_pc16();
                self.registers.assign_single(SingleRegister.A, self.memory_read_u8(addr));
            },
            0x3E => {
                const imm = self.advance_pc();

                self.registers.assign_single(SingleRegister.A, imm);
            },

            // LD, a, A
            0x02 => {
                const val = self.registers.read_double(PairRegister.BC);
                self.memory_write_u8(val, self.registers.read_single(SingleRegister.A));
            },
            0x12 => {
                const val = self.registers.read_double(PairRegister.DE);

                self.memory_write_u8(val, self.registers.read_single(SingleRegister.A));
            },
            0x77 => {
                const val = self.registers.read_double(PairRegister.HL);
                self.memory_write_u8(val, self.registers.read_single(SingleRegister.A));
            },
            0xEA => {
                const val = self.advance_pc16();

                self.memory_write_u8(val, self.registers.read_single(SingleRegister.A));
            },
            0xF2 => {
                const c = self.registers.read_single(SingleRegister.C);
                const val = self.memory_read_u8(@as(u16, c) + 0xFF00);

                self.registers.assign_single(SingleRegister.A, val);
            },
            0xE2 => {
                const c = self.registers.read_single(SingleRegister.C);

                self.memory_write_u8(0xFF00 + @as(u16, c), self.registers.read_single(SingleRegister.A));
            },
            0x3A => {
                const c = self.read_memory_hl();

                self.alu_dec16(PairRegister.HL);
                self.registers.assign_single(SingleRegister.A, c);
            },
            0x32 => {
                const a = self.registers.read_single(SingleRegister.A);

                self.write_memory_hl(a);
                self.alu_dec16(PairRegister.HL);
            },
            0x2A => {
                const c = self.read_memory_hl();

                self.alu_inc16(PairRegister.HL);
                self.registers.assign_single(SingleRegister.A, c);
            },
            0x22 => {
                const a = self.registers.read_single(SingleRegister.A);

                self.write_memory_hl(a);
                self.alu_inc16(PairRegister.HL);
            },
            0xE0 => {
                const a = self.registers.read_single(SingleRegister.A);
                const nn = self.advance_pc();

                // std.debug.print(" {x} ", .{nn});
                self.memory_write_u8(0xFF00 | @as(u16, nn), a);
            },
            0xF0 => {
                const nn = self.advance_pc();
                const val = self.memory_read_u8(0xFF00 | @as(u16, nn));

                // std.debug.print(" {x} ", .{nn});
                self.registers.assign_single(SingleRegister.A, val);
            },
            0x01 => {
                const val = self.advance_pc16();

                self.registers.assign_double(PairRegister.BC, val);
            },
            0x11 => {
                const val = self.advance_pc16();

                self.registers.assign_double(PairRegister.DE, val);
            },
            0x21 => {
                const val = self.advance_pc16();

                self.registers.assign_double(PairRegister.HL, val);
            },
            0x31 => {
                const val = self.advance_pc16();

                self.registers.sp = val;
            },
            0xF9 => {
                self.registers.sp = self.registers.read_double(PairRegister.HL);
            },
            0x08 => {
                const val = self.advance_pc16();

                self.memory_write_u16(val, self.registers.sp);
            },

            // Push
            0xF5 => self.stack_push(self.registers.read_double(PairRegister.AF)),
            0xC5 => self.stack_push(self.registers.read_double(PairRegister.BC)),
            0xD5 => self.stack_push(self.registers.read_double(PairRegister.DE)),
            0xE5 => self.stack_push(self.registers.read_double(PairRegister.HL)),

            // Pop
            0xF1 => {
                var val = self.stack_pop();

                // NOTE: failed test. Need to zero the lower byte of F
                val &= 0xFFF0;
                self.registers.assign_double(PairRegister.AF, val);
            },
            0xC1 => self.registers.assign_double(PairRegister.BC, self.stack_pop()),
            0xD1 => self.registers.assign_double(PairRegister.DE, self.stack_pop()),
            0xE1 => self.registers.assign_double(PairRegister.HL, self.stack_pop()),

            // Jump
            0xC3 => {
                const val = self.advance_pc16();

                self.registers.pc = val;
            },

            // JP
            0xC2 => {
                self.off = self.advance_pc16();
                self.if_zero(Self.set_pc, 0);
            },
            0xCA => {
                self.off = self.advance_pc16();
                self.if_zero(Self.set_pc, 1);
            },
            0xD2 => {
                self.off = self.advance_pc16();
                self.if_carry(Self.set_pc, 0);
            },
            0xDA => {
                self.off = self.advance_pc16();
                self.if_carry(Self.set_pc, 1);
            },

            // JR
            0x18 => {
                const offset: i8 = @bitCast(self.advance_pc());
                self.registers.pc +%= @as(u16, @bitCast(@as(i16, @intCast(offset))));
            },

            // JR NZ
            0x20 => {
                const offset: i8 = @bitCast(self.advance_pc());

                self.off = @bitCast(@as(i16, @intCast(offset)));
                self.if_zero(Self.add_pc, 0);
            },
            // JR Z
            0x28 => {
                const offset: i8 = @bitCast(self.advance_pc());

                self.off = @bitCast(@as(i16, @intCast(offset)));
                self.if_zero(Self.add_pc, 1);
            },
            // JR NC
            0x30 => {
                const offset: i8 = @bitCast(self.advance_pc());

                self.off = @bitCast(@as(i16, @intCast(offset)));
                self.if_carry(Self.add_pc, 0);
            },
            // JR C
            0x38 => {
                const offset: i8 = @bitCast(self.advance_pc());

                self.off = @bitCast(@as(i16, @intCast(offset)));
                self.if_carry(Self.add_pc, 1);
            },
            // JP (HL)
            0xE9 => {
                const val = self.registers.read_double(PairRegister.HL);
                self.registers.pc = val;
            },

            // DI
            0xF3 => self.ei = false,
            0xFB => self.ei = true,

            // Reti
            0xD9 => {
                self.ret();
                self.ei = true;
            },
            // Ret
            0xC9 => self.ret(),
            0xC0 => {
                self.if_zero(Self.ret, 0);
            },
            0xC8 => {
                self.if_zero(Self.ret, 1);
            },
            0xD0 => {
                self.if_carry(Self.ret, 0);
            },
            0xD8 => {
                self.if_carry(Self.ret, 1);
            },

            // CALL
            0xCD => {
                const val = self.advance_pc16();

                self.off = val;
                self.call();
            },
            0xC4 => {
                const val = self.advance_pc16();

                self.off = val;
                self.if_zero(Self.call, 0);
            },
            0xCC => {
                const val = self.advance_pc16();

                self.off = val;
                self.if_zero(Self.call, 1);
            },
            0xD4 => {
                const val = self.advance_pc16();

                self.off = val;
                self.if_carry(Self.call, 0);
            },
            0xDC => {
                const val = self.advance_pc16();

                self.off = val;
                self.if_carry(Self.call, 1);
            },

            // CP
            0xBF => self.alu_cp(self.registers.read_single(SingleRegister.A)),
            0xB8 => self.alu_cp(self.registers.read_single(SingleRegister.B)),
            0xB9 => self.alu_cp(self.registers.read_single(SingleRegister.C)),
            0xBA => self.alu_cp(self.registers.read_single(SingleRegister.D)),
            0xBB => self.alu_cp(self.registers.read_single(SingleRegister.E)),
            0xBC => self.alu_cp(self.registers.read_single(SingleRegister.H)),
            0xBD => self.alu_cp(self.registers.read_single(SingleRegister.L)),
            0xBE => self.alu_cp(self.read_memory_hl()),
            0xFE => self.alu_cp(self.advance_pc()),

            // Rst
            0xC7 => {
                self.stack_push(self.registers.pc);
                self.registers.pc = 0;
            },
            0xCF => {
                self.stack_push(self.registers.pc);
                self.registers.pc = 0x8;
            },
            0xD7 => {
                self.stack_push(self.registers.pc);
                self.registers.pc = 0x10;
            },
            0xDF => {
                self.stack_push(self.registers.pc);
                self.registers.pc = 0x18;
            },
            0xE7 => {
                self.stack_push(self.registers.pc);
                self.registers.pc = 0x20;
            },
            0xEF => {
                self.stack_push(self.registers.pc);
                self.registers.pc = 0x28;
            },
            0xF7 => {
                self.stack_push(self.registers.pc);
                self.registers.pc = 0x30;
            },
            0xFF => {
                self.stack_push(self.registers.pc);
                self.registers.pc = 0x38;
            },

            else => {
                std.debug.print("Unknown opcode {x}\n", .{i});
                @panic("");
            },
        }

        if (self.debug) {
            std.debug.print("\n", .{});
            self.dump_state(std.debug);
        }

        if (i != 0xCB) {
            if (!self.cond) {
                return single_cycles[i];
            } else {
                return condition[i];
            }
        } else {
            return double_cycles[next.?];
        }
    }

    pub fn dump_state(self: *Self, writer: anytype) void {
        self.registers.dump_state(writer);
        writer.print(" {}\n", .{self.ei});
    }
};

test "Test execute add" {
    const expectEqual = std.testing.expectEqual;
    const test_allocator = std.testing.allocator;

    const b = SingleRegister.B;
    const a = SingleRegister.A;
    var memory = ArrayList(u8).init(test_allocator);
    defer memory.deinit();

    try memory.appendSlice(&[_]u8{ 0x80, 0x80, 0x80, 0x80 });

    var cpu = Cpu.default(memory.items);

    // For testing purpose
    cpu.registers.pc = 0;
    cpu.registers.regs = [_]u8{0} ** (8);

    cpu.registers.assign_single(b, 1);

    _ = cpu.execute_one();
    try expectEqual(cpu.registers.read_single(a), 1);
    try expectEqual(0, @as(u8, @bitCast(cpu.registers.read_flags())));

    _ = cpu.execute_one();
    try expectEqual(cpu.registers.read_single(a), 2);
    try expectEqual(0, @as(u8, @bitCast(cpu.registers.read_flags())));

    // Test half curry
    cpu.registers.assign_single(b, 143);

    _ = cpu.execute_one();
    try expectEqual(cpu.registers.read_single(a), 145);
    try expectEqual(0b100000, @as(u8, @bitCast(cpu.registers.read_flags())));

    // Test curry
    cpu.registers.assign_single(b, 143);

    _ = cpu.execute_one();
    try expectEqual(cpu.registers.read_single(a), (143 + 145) & 0xff);
    try expectEqual(0b110000, @as(u8, @bitCast(cpu.registers.read_flags())));
}

test "Test and" {
    const expectEqual = std.testing.expectEqual;
    const test_allocator = std.testing.allocator;

    var memory = ArrayList(u8).init(test_allocator);
    try memory.append(0xA0);

    defer memory.deinit();

    const b = SingleRegister.B;
    const a = SingleRegister.A;

    var cpu = Cpu.default(memory.items);

    // For testing purpose
    cpu.registers.pc = 0;
    cpu.registers.regs = [_]u8{0} ** (8);

    cpu.registers.assign_single(b, 1);
    _ = cpu.execute_one();

    // Manual say that half carry should be set
    try expectEqual(0b10100000, @as(u8, @bitCast(cpu.registers.read_flags())));
    try expectEqual(cpu.registers.read_single(a), 0);
}
