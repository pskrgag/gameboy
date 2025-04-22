pub const Serial = struct {
    val: u8,
    control: u8,

    const Self = @This();

    pub fn default() Self {
        return Self{
            .val = 0,
            .control = 0,
        };
    }

    pub fn write(self: *Self, addr: u16, val: u8) void {
        switch (addr) {
            0xFF01 => self.val = val,
            0xFF02 => self.control = val,
            else => @panic(""),
        }
    }

    pub fn read(self: *Self, addr: u16) u8 {
        switch (addr) {
            0xFF01 => return self.val,
            0xFF02 => return self.control,
            else => @panic(""),
        }
    }
};
