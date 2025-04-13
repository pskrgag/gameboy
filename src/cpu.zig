const RegisterFile = @import("register.zig").RegisterFile;
const Register = @import("register.zig").Register;
const RegisterKind = @import("register.zig").RegisterKind;
const SingleRegister = @import("register.zig").SingleRegister;
const PairRegister = @import("register.zig").PairRegister;
const FlagRegister = @import("register.zig").FlagRegister;
const std = @import("std");
const ArrayList = std.ArrayList;

pub const Cpu = struct {
    registers: RegisterFile,
    memory: ArrayList(u8),

    const Self = @This();

    pub fn default(memory: ArrayList(u8)) Self {
        return Cpu{
            .registers = RegisterFile.default(),
            .memory = memory,
        };
    }

    fn read_memory(self: *Self, idx: u16) u8 {
        return self.memory.items[idx];
    }

    fn write_memory(self: *Self, idx: u16, val: u8) void {
        self.memory.items[idx] = val;
    }

    fn write_memory_hl(self: *Self, val: u8) void {
        const hl = self.registers.read(Register{ .double = PairRegister.HL });
        self.write_memory(hl, val);
    }

    fn read_memory_hl(self: *Self) u8 {
        const hl = self.registers.read(Register{ .double = PairRegister.HL });
        return self.read_memory(hl);
    }

    fn alu_add16(self: *Self, val1: u16, val: u16) u16 {
        // res[0] is a result, while res[1] is overflow indicator
        const res = @as(u32, val) + @as(u32, val);
        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0))
            .set_carry(@intFromBool(res > 0xffff))
            .set_half_curry(@intFromBool(((val & 0xFFF) + (val1 & 0xFFF)) > 0xFFF));

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

    fn alu_addc(self: *Self, val: u8) void {
        const a = self.registers.read_single(SingleRegister.A);
        const carry = self.registers.read_flags().carry;

        // res[0] is a result, while res[1] is overflow indicator
        const res = @as(u16, val) + @as(u16, a) + @as(u16, carry);
        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0))
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

        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0))
            .set_half_curry(@intFromBool(val == 0xf));

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

        const new_flags = FlagRegister
            .default()
            .set_zero(@intFromBool(res == 0))
            .set_half_curry(@intFromBool(val == 0x10));

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
        const high = @as(u16, (val & 0xF)) << @as(u8, 8);
        const res = high | (@as(u16, val) >> 8);
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

        if ((flags.sub == 0 and (val & 0xF > 9)) or flags.half_carry == 1) {
            offset |= 0x6;
        }

        if ((flags.sub == 0 and (val > 0x99)) or flags.carry == 1) {
            offset |= 0x60;
            flags.carry = 1;
        }

        if (flags.sub == 2) {
            val -%= offset;
        } else {
            val +%= offset;
        }

        flags.zero = @intFromBool(val == 0);

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

        val <<= 1;
        val |= self.registers.flags.carry;

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

        val >>= 1;
        val |= @as(u8, self.registers.flags.carry) << 7;

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
        const res = self.alu_sra(r);

        self.registers.assign_single(reg, res);
    }

    pub fn execute_one(self: *Self) !void {
        const i = self.read_memory(self.registers.pc);
        self.registers.pc += 1;

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

            // Adc instructions
            0x8f => |_| self.alu_addc(self.registers.read_single(SingleRegister.A)),
            0x88 => |_| self.alu_addc(self.registers.read_single(SingleRegister.B)),
            0x89 => |_| self.alu_addc(self.registers.read_single(SingleRegister.C)),
            0x8A => |_| self.alu_addc(self.registers.read_single(SingleRegister.D)),
            0x8B => |_| self.alu_addc(self.registers.read_single(SingleRegister.E)),
            0x8C => |_| self.alu_addc(self.registers.read_single(SingleRegister.H)),
            0x8D => |_| self.alu_addc(self.registers.read_single(SingleRegister.L)),
            0x8E => |_| self.alu_addc(self.read_memory_hl()),

            // Sub instructions
            0x97 => |_| self.alu_sub(self.registers.read_single(SingleRegister.A)),
            0x90 => |_| self.alu_sub(self.registers.read_single(SingleRegister.B)),
            0x91 => |_| self.alu_sub(self.registers.read_single(SingleRegister.C)),
            0x92 => |_| self.alu_sub(self.registers.read_single(SingleRegister.D)),
            0x93 => |_| self.alu_sub(self.registers.read_single(SingleRegister.E)),
            0x94 => |_| self.alu_sub(self.registers.read_single(SingleRegister.H)),
            0x95 => |_| self.alu_sub(self.registers.read_single(SingleRegister.L)),
            0x96 => |_| self.alu_sub(self.read_memory_hl()),

            // Subc instructions
            0x9F => |_| self.alu_subc(self.registers.read_single(SingleRegister.A)),
            0x98 => |_| self.alu_subc(self.registers.read_single(SingleRegister.B)),
            0x99 => |_| self.alu_subc(self.registers.read_single(SingleRegister.C)),
            0x9A => |_| self.alu_subc(self.registers.read_single(SingleRegister.D)),
            0x9B => |_| self.alu_subc(self.registers.read_single(SingleRegister.E)),
            0x9C => |_| self.alu_subc(self.registers.read_single(SingleRegister.H)),
            0x9D => |_| self.alu_subc(self.registers.read_single(SingleRegister.L)),
            0x9E => |_| self.alu_subc(self.read_memory_hl()),

            // And instructions
            0xA7 => |_| self.alu_and(self.registers.read_single(SingleRegister.A)),
            0xA0 => |_| self.alu_and(self.registers.read_single(SingleRegister.B)),
            0xA1 => |_| self.alu_and(self.registers.read_single(SingleRegister.C)),
            0xA2 => |_| self.alu_and(self.registers.read_single(SingleRegister.D)),
            0xA3 => |_| self.alu_and(self.registers.read_single(SingleRegister.E)),
            0xA4 => |_| self.alu_and(self.registers.read_single(SingleRegister.H)),
            0xA5 => |_| self.alu_and(self.registers.read_single(SingleRegister.L)),
            0xA6 => |_| self.alu_and(self.read_memory_hl()),

            // Or instructions
            0xB7 => |_| self.alu_or(self.registers.read_single(SingleRegister.A)),
            0xB0 => |_| self.alu_or(self.registers.read_single(SingleRegister.B)),
            0xB1 => |_| self.alu_or(self.registers.read_single(SingleRegister.C)),
            0xB2 => |_| self.alu_or(self.registers.read_single(SingleRegister.D)),
            0xB3 => |_| self.alu_or(self.registers.read_single(SingleRegister.E)),
            0xB4 => |_| self.alu_or(self.registers.read_single(SingleRegister.H)),
            0xB5 => |_| self.alu_or(self.registers.read_single(SingleRegister.L)),
            0xB6 => |_| self.alu_or(self.read_memory_hl()),

            // Xor instructions
            0xAF => |_| self.alu_xor(self.registers.read_single(SingleRegister.A)),
            0xA8 => |_| self.alu_xor(self.registers.read_single(SingleRegister.B)),
            0xA9 => |_| self.alu_xor(self.registers.read_single(SingleRegister.C)),
            0xAA => |_| self.alu_xor(self.registers.read_single(SingleRegister.D)),
            0xAB => |_| self.alu_xor(self.registers.read_single(SingleRegister.E)),
            0xAC => |_| self.alu_xor(self.registers.read_single(SingleRegister.H)),
            0xAD => |_| self.alu_xor(self.registers.read_single(SingleRegister.L)),
            0xAE => |_| self.alu_xor(self.read_memory_hl()),

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

            // Add to SP
            0xE8 => |_| {
                const imm = self.read_memory(self.registers.pc);

                self.registers.sp = self.alu_add16(self.registers.sp, imm);
                self.registers.pc += 1;
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
                const next = self.read_memory(self.registers.pc);

                self.registers.pc += 1;
                switch (next) {
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
                    else => @panic("Unknown opcode"),
                }
            },
            0x27 => self.alu_daa(),
            0x2F => self.alu_cpl(),
            0x3F => self.registers.flags.carry ^= 1,
            0x37 => self.registers.flags.carry = 1,

            // Nop
            0x00 => {},
            0x76 => @panic("HALT"),

            0x07 => self.alu_rlc_reg(SingleRegister.A),
            0x17 => self.alu_rl_reg(SingleRegister.A),

            0x0F => self.alu_rrc_reg(SingleRegister.A),
            0x1F => self.alu_rr_reg(SingleRegister.A),

            else => @panic("Unknown opcode"),
        }
    }

    pub fn dump_state(self: *Self, writer: anytype) void {
        self.registers.dump_state(writer);
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

    var cpu = Cpu.default(memory);

    // For testing purpose
    cpu.registers.pc = 0;

    cpu.registers.assign_single(b, 1);

    try cpu.execute_one();
    try expectEqual(cpu.registers.read_single(a), 1);
    try expectEqual(0, @as(u8, @bitCast(cpu.registers.read_flags())));

    try cpu.execute_one();
    try expectEqual(cpu.registers.read_single(a), 2);
    try expectEqual(0, @as(u8, @bitCast(cpu.registers.read_flags())));

    // Test half curry
    cpu.registers.assign_single(b, 143);

    try cpu.execute_one();
    try expectEqual(cpu.registers.read_single(a), 145);
    try expectEqual(0b100000, @as(u8, @bitCast(cpu.registers.read_flags())));

    // Test curry
    cpu.registers.assign_single(b, 143);

    try cpu.execute_one();
    try expectEqual(cpu.registers.read_single(a), (143 + 145) & 0xff);
    try expectEqual(0b110000, @as(u8, @bitCast(cpu.registers.read_flags())));

    cpu.dump_state(std.debug);
}

test "Test and" {
    const expectEqual = std.testing.expectEqual;
    const test_allocator = std.testing.allocator;

    var memory = ArrayList(u8).init(test_allocator);
    try memory.append(0xA0);

    defer memory.deinit();

    const b = SingleRegister.B;
    const a = SingleRegister.A;

    var cpu = Cpu.default(memory);
    // For testing purpose
    cpu.registers.pc = 0;

    cpu.registers.assign_single(b, 1);
    try cpu.execute_one();

    // Manual say that half carry should be set
    try expectEqual(0b10100000, @as(u8, @bitCast(cpu.registers.read_flags())));
    try expectEqual(cpu.registers.read_single(a), 0);
}
