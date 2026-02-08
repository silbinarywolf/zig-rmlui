const crml = @import("crml");
const maxInt = @import("std").math.maxInt;

/// FamilyId is a unique identifier used to register a type in RmlUi's DataTypeRegister
pub const FamilyId = enum(crml.RmlFamilyId) {
    _,

    /// Handle counting ourselves within Zig code, lets start from {N} instead of 0 so that if C/C++ code
    /// adds its own types, we won't clash.
    var global_type_id_counter: crml.RmlFamilyId = 8192;

    inline fn toOptional(id: FamilyId) OptionalFamilyId {
        return @enumFromInt(@intFromEnum(id));
    }

    /// Same behaviour as RmlUi/Core/Traits.cpp
    ///   static int id = 0;
    ///   return id++;
    pub inline fn getNewId() FamilyId {
        const id = global_type_id_counter;
        global_type_id_counter += 1;
        return @enumFromInt(id);
    }

    /// Get a unique ID for a given type.
    /// Note: An ID for a given type may not match across DLL-boundaries.
    ///
    /// Same behaviour as Family<T>::Id() from RmlUi/Core/Traits.h
    ///   static FamilyId Id() {
    ///   static int id = GetNewId();
    ///   return static_cast<FamilyId>(id);
    /// }
    pub inline fn getTypeId(comptime T: type) FamilyId {
        const TypeId = struct {
            /// Set Type constant on this struct so that Zig creates a
            /// new static/global variable that is unique to each type.
            const Type = T;

            var id: OptionalFamilyId = .none;
        };
        if (TypeId.id.unwrap()) |r| return r;
        const r = FamilyId.getNewId();
        TypeId.id = r.toOptional();
        return r;
    }

    /// cast to C-API type
    pub fn c(id: FamilyId) crml.RmlFamilyId {
        return @intFromEnum(id);
    }
};

/// OptionalFamilyId is a unique identifier
const OptionalFamilyId = enum(crml.RmlFamilyId) {
    none = maxInt(crml.RmlFamilyId),
    _,

    inline fn unwrap(id: OptionalFamilyId) ?FamilyId {
        if (id == .none) return null;
        return @enumFromInt(@intFromEnum(id));
    }
};

const testing = @import("std").testing;

test {
    testing.refAllDecls(@This());
}

test "test that getTypeId generates a unique id per type" {
    const getTypeId = FamilyId.getTypeId;
    try testing.expectEqual(getTypeId(u8), getTypeId(u8));
    try testing.expect(getTypeId(u8) != getTypeId(u16)); // Fail if struct is not unique / has const to Type
}
