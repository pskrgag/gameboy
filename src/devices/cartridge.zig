pub const Type = enum(u8) {
    RomOnly = 0,
    RomMbc1 = 1,
    RomMbc1Ram = 2,
    RomMbc2 = 5,
    RomRam = 8,
};

pub const Rom = struct {
    tp: Type,

    const Self = @This();

    pub fn from_data(data: []const u8) Self {
        const tp: Type = @enumFromInt(data[147]);

        return .{ .tp = tp };
    }

    pub fn read(tp: type, self: *Self, addr: u16) tp {
        _ = self;
        _ = addr;
        const res: tp = 0;
        return res;
    }
};
