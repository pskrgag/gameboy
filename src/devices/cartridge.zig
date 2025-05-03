const std = @import("std");

const RomType = enum(u8) {
    RomOnly = 0,
    MBC1Rom = 1,
};

const RomOnly = struct {
    data: []const u8,

    pub fn read(self: *const RomOnly, addr: u16) u8 {
        return self.data[addr];
    }

    pub fn write(self: *const RomOnly, addr: u16, val: u8) void {
        _ = self;
        _ = addr;
        _ = val;
    }
};

const Mbc1 = struct {
    rom: []const u8,
    ram: []const u8,
    active_rom: u8,
    active_ram: u8,
    ram_on: bool,
    // true == 16/8, false == 4/32
    mode: bool,

    pub fn read(self: *const Mbc1, addr: u16) u8 {
        switch (addr) {
            // Read of ROM bank 0
            0x0000...0x3FFF => return self.rom[addr],
            0x4000...0x7FFF => {
                // Read of other ram banks
                const offset = addr - 0x4000;
                const res = self.rom[@as(u16, self.active_rom) * 0x4000 + offset];

                return res;
            },
            0xA000...0xBFFF => {
                if (self.ram_on) {
                    const off = addr - 0xA000;

                    return self.ram[0x2000 * @as(u16, self.active_ram) + off];
                } else {
                    return 0xFF;
                }
            },
            else => return 0xff,
        }
    }

    pub fn write(self: *Mbc1, addr: u16, val: u8) void {
        switch (addr) {
            // Enable ram
            0x0000...0x1FFF => self.ram_on = val & 0b1111 == 0b1010,
            0x2000...0x3FFF => {
                const bank = val & 0b11111;

                self.active_rom = self.active_rom & (0b11 << 5) | if (bank == 0) 1 else bank;
            },
            0x6000...0x7FFF => self.mode = (val & 1) != 0,
            0x4000...0x5FFF => {
                if (self.mode) {
                    self.active_ram = val & 0b11;
                } else {
                    self.active_rom = (self.active_rom & 0b11111) | ((val & 0b11) << 5);
                }
            },
            else => {
                // @panic("");
            },
        }
    }
};

const RomKind = union(RomType) {
    RomOnly: RomOnly,
    MBC1Rom: Mbc1,
};

pub const Cartridge = struct {
    tp: RomKind,

    const Self = @This();

    pub fn default() Self {
        return .{ .tp = RomKind{ .RomOnly = .{ .data = &[_]u8{} } } };
    }

    pub fn from_data(data: []const u8) Self {
        // const ram_size = data[0x149];
        const tp = switch (data[0x147]) {
            0 => RomKind{ .RomOnly = .{ .data = data } },
            1 => RomKind{ .MBC1Rom = .{
                .rom = data,
                .ram = &[_]u8{},
                .mode = false,
                .active_ram = 0,
                .active_rom = 1,
                .ram_on = false,
            } },
            else => @panic("Unknown rom type"),
        };

        return .{ .tp = tp };
    }

    pub fn write(self: *Self, addr: u16, val: u8) void {
        switch (self.tp) {
            .RomOnly => |r| r.write(addr, val),
            .MBC1Rom => |*r| r.write(addr, val),
        }
    }

    pub fn read(self: *Self, addr: u16) u8 {
        return switch (self.tp) {
            .RomOnly => |r| r.read(addr),
            .MBC1Rom => |r| r.read(addr),
        };
    }
};
