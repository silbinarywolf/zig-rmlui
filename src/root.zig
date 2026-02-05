//! RmlUi Core functions

const mem = @import("std").mem;
const Writer = @import("std").Io.Writer;
const panic = @import("std").debug.panic;
const comptimePrint = @import("std").fmt.comptimePrint;
const log = @import("std").log.scoped(.rmlui);

/// Allow accessing of the C-API
pub const crml = @import("crml");

/// RmlUi Debugger functions
pub const debugger = @import("debugger.zig");

/// SDL Platform/Rendering Backend
pub const sdl = @import("sdl.zig");

pub const ZigFileInterface = @import("ZigFileInterface.zig");
pub const FamilyId = @import("FamilyId.zig").FamilyId;

pub const Error = error{
    RmlInitialiseFailed,
    RmlDebuggerInitialiseFailed,
    RmlSystemInterfaceCreateFailed,
    RmlRenderInterfaceCreateFailed,
    RmlContextCreateFailed,
    RmlLoadFontFaceFailed,
    RmlLoadDocumentFailed,
    RmlCreateDataModelFailed,
} || BindError;

pub const BindError = error{
    RmlBindFailed,
    RmlCreateDefinitionFailed,
    RmlDefinitionAlreadyRegistered,
    RmlTypeNotRegistered,
} || internal.CreateDefinitionError;

// TODO: Write Zig bindings over the C-bindings

/// Initialises RmlUi.
pub inline fn initialise() Error!void {
    if (!crml.rmlInitialise()) return error.RmlInitialiseFailed;
}

/// Shutdown RmlUi.
pub inline fn shutdown() void {
    return crml.rmlShutdown();
}

pub const KeyModifier = enum(u32) {
    none = 0,
    _,
    // TODO: Setup flags for key modifier state
    // if (x11_state & ShiftMask)
    // key_modifier_state |= Rml::Input::KM_SHIFT;
    // if (x11_state & LockMask)
    // key_modifier_state |= Rml::Input::KM_CAPSLOCK;
    // if (x11_state & ControlMask)
    // key_modifier_state |= Rml::Input::KM_CTRL;
    // if (x11_state & Mod5Mask)
    // key_modifier_state |= Rml::Input::KM_ALT;
    // if (x11_state & Mod2Mask)
    // key_modifier_state |= Rml::Input::KM_NUMLOCK;
};

pub const createContext = Context.create;

pub const Context = opaque {
    pub const CreateOptions = struct {
        /// The custom render interface to use, or null to use the default.
        render_interface: ?*RenderInterface,
        /// The custom text input handler to use, or null to use the default.
        text_input_handler: ?*TextInputHandler,

        pub const default: CreateOptions = .{
            .render_interface = null,
            .text_input_handler = null,
        };
    };

    /// Creates a new element context.
    ///
    /// @param[in] name The new name of the context. This must be unique.
    /// @param[in] width The initial width of the new context.
    /// @param[in] width The initial height of the new context.
    /// @param[in] options Additional custom options for the context
    ///
    /// @lifetime If specified, the render interface and the text input handler must be kept alive until after the call to
    ///           Rml::Shutdown. Alternatively, the render interface can be destroyed after all contexts it belongs to have been
    ///           destroyed, and a subsequent call has been made to Rml::ReleaseRenderManagers.
    pub inline fn create(unique_name: []const u8, width: i32, height: i32, options: CreateOptions) error{RmlContextCreateFailed}!*Context {
        const r = crml.rmlCreateContext(
            unique_name.ptr,
            unique_name.len,
            width,
            height,
            @ptrCast(options.render_interface),
            @ptrCast(options.text_input_handler),
        ) orelse return error.RmlContextCreateFailed;
        return @ptrCast(r);
    }

    /// Updates all elements in the context's documents.
    /// This must be called before Context::Render, but after any elements have been changed, added, or removed.
    pub inline fn update(context: *Context) bool {
        return crml.rmlContext_Update(context.c());
    }

    /// Renders all visible elements in the context's documents.
    pub inline fn render(context: *Context) bool {
        return crml.rmlContext_Render(context.c());
    }

    /// Changes the ratio of the 'dp' unit to the 'px' unit.
    pub inline fn setDensityIndependentPixelRatio(context: *Context, dp_ratio: f32) void {
        return crml.rmlContext_SetDensityIndependentPixelRatio(context.c(), dp_ratio);
    }

    /// Load a document into the context.
    ///
    /// @param[in] document_rml The string containing the document RML.
    /// @param[in] source_url string used to set the document's source URL, or naming the document for log messages.
    /// @return The loaded document, or error if no document was loaded.
    pub inline fn loadDocumentFromMemory(context: *Context, rml_data: []const u8, source_url: []const u8) error{RmlLoadDocumentFailed}!*ElementDocument {
        const el = crml.rmlContext_LoadDocumentFromMemory(
            context.c(),
            rml_data[0..].ptr,
            rml_data.len,
            source_url[0..].ptr,
            source_url.len,
        ) orelse return error.RmlLoadDocumentFailed;
        return @ptrCast(el);
    }

    pub inline fn createDataModel(context: *Context, name: []const u8, data_type_register: ?*DataTypeRegister) error{RmlCreateDataModelFailed}!DataModelConstructor {
        var dmc_result: crml.RmlDataModelConstructor = undefined;
        crml.rmlContext_CreateDataModel(
            context.c(),
            name.ptr,
            name.len,
            if (data_type_register) |dtr| dtr.c() else null,
            &dmc_result,
        );
        return DataModelConstructor{ .impl = dmc_result };
    }

    /// True if the mouse is not interacting with any elements in the context (see 'IsMouseInteracting'), otherwise false.
    pub inline fn processMouseMove(context: *Context, x: i32, y: i32, key_modifier_state: KeyModifier) bool {
        return crml.rmlContext_ProcessMouseMove(context.c(), x, y, @intFromEnum(key_modifier_state));
    }

    /// True if the event was not consumed (ie, was prevented from propagating by an element), false if it was.
    pub inline fn processMouseWheel(context: *Context, mouse_delta_x: f32, mouse_delta_y: f32, key_modifier_state: KeyModifier) bool {
        return crml.rmlContext_ProcessMouseWheel(context.c(), mouse_delta_x, mouse_delta_y, @intFromEnum(key_modifier_state));
    }

    /// cast to C-API type
    pub inline fn c(context: *Context) *crml.RmlContext {
        return @ptrCast(context);
    }
};

pub const ModalFlag = enum(u8) {
    none = crml.RmlModalFlag_None,
    modal = crml.RmlModalFlag_Modal,
    keep = crml.RmlModalFlag_Keep,
};

pub const FocusFlag = enum(u8) {
    none = crml.RmlFocusFlag_None,
    document = crml.RmlFocusFlag_Document,
    keep = crml.RmlFocusFlag_Keep,
    auto = crml.RmlFocusFlag_Auto,
};

pub const ElementDocument = opaque {
    pub const ShowOptions = struct {
        modal_flag: ModalFlag,
        focus_flag: FocusFlag,

        pub const default: ShowOptions = .{
            .modal_flag = .none,
            .focus_flag = .auto,
        };
    };

    pub inline fn show(el: *ElementDocument, options: ShowOptions) void {
        return crml.rmlElementDocument_Show(el.c(), @intFromEnum(options.modal_flag), @intFromEnum(options.focus_flag));
    }

    pub inline fn reloadStyleSheet(el: *ElementDocument) void {
        return crml.rmlElementDocument_ReloadStyleSheet(el.c());
    }

    /// Cast to base Element type
    pub inline fn element(el: *ElementDocument) *Element {
        return @ptrCast(el);
    }

    /// cast to C-API type
    pub inline fn c(el: *ElementDocument) *crml.RmlElementDocument {
        return @ptrCast(el);
    }
};

pub const Element = opaque {
    /// Get a child element by its ID.
    /// @param[in] id The ID of the child element.
    /// @return The child of this element with the given ID, or nullptr if no such child exists.
    //Element* GetElementById(const String& id);
    //Element* QuerySelector(const String& selector);

    /// Get all descendant elements with the given class set on them.
    /// @param[out] elements Resulting elements.
    /// @param[in] class_name Class name to search for.
    //void GetElementsByClassName(ElementList& elements, const String& class_name);

    //void QuerySelectorAll(ElementList& elements, const String& selector);

    /// cast to C-API type
    pub inline fn c(el: *Element) *crml.RmlElement {
        return @ptrCast(el);
    }
};

pub const DataModelConstructor = struct {
    impl: crml.RmlDataModelConstructor,

    /// Bind a data variable.
    /// @note For non-builtin types, make sure they first have been registered with the appropriate 'Register...()' functions.
    pub fn bind(dmc: *DataModelConstructor, comptime name: []const u8, ptr: anytype) BindError!void {
        const PT = @TypeOf(ptr);
        const info = @typeInfo(PT);
        if (info != .pointer)
            @compileError("expected pointer, got " ++ @typeName(PT));
        const T = info.pointer.child;
        const definition = try dmc.getDataTypeRegister().getDefinition(T);
        if (!dmc.bindVariable(name, DataVariable.init(definition, @ptrCast(ptr))))
            return error.RmlBindFailed;
    }

    /// Bind a user-declared DataVariable.
    /// For advanced use cases, such as binding variables to a custom 'VariableDefinition'.
    pub inline fn bindCustomDataVariable(dmc: *DataModelConstructor, name: []const u8, data_variable: DataVariable) bool {
        return crml.rmlDataModelConstructor_BindCustomDataVariable(&dmc.impl, name.ptr, name.len, data_variable.c());
    }

    /// Return a handle to the data model being constructed, which can later be used to synchronize variables and update the model.
    pub inline fn getModelHandle(dmc: *DataModelConstructor) DataModelHandle {
        return .fromC(crml.rmlDataModelConstructor_GetModelHandle(&dmc.impl));
    }

    // [private method] In the C++ code, this function is private even though it's functionally identical
    // to the public method 'bindCustomDataVariable'
    inline fn bindVariable(dmc: *DataModelConstructor, name: []const u8, data_variable: DataVariable) bool {
        return dmc.bindCustomDataVariable(name, data_variable);
    }

    // Returns the type register.
    // The type register contains VariableDefinitions of all the data types registered to this data model's owning context.
    pub inline fn getDataTypeRegister(dmc: *DataModelConstructor) *DataTypeRegister {
        return .fromC(dmc.impl.private_fields.type_register.?);
    }
};

/// [private] This is accessed via DataModelHandle in the public includes
const DataModel = opaque {
    const bindVariable = @compileError("bindVariable is not exposed in Include, use DataModelConstructor.bindCustomDataVariable");

    pub inline fn fromC(dm: *crml.RmlDataModel) *DataModel {
        return @ptrCast(dm);
    }

    /// cast to C-API type
    pub inline fn c(dm: *DataModel) *crml.RmlDataModel {
        return @ptrCast(dm);
    }
};

const VariableDefinition = opaque {
    pub inline fn fromC(vd: *crml.RmlVariableDefinition) *VariableDefinition {
        return @ptrCast(vd);
    }

    /// cast to C-API type
    pub inline fn c(vd: *VariableDefinition) *crml.RmlVariableDefinition {
        return @ptrCast(vd);
    }
};

pub const DataVariable = struct {
    impl: crml.RmlDataVariable,

    /// From LegalVariableName::LegalName()
    const ReservedVariableNames = [_][]const u8{ "it", "it_index", "ev", "true", "false", "size", "literal" };

    /// Used by DataModelConstructor.bind functions
    fn init(variable_definition: *VariableDefinition, ptr: *anyopaque) DataVariable {
        const T = @TypeOf(ptr);
        const info = @typeInfo(T);
        if (info != .pointer)
            @compileError("expected pointer, got " ++ @typeName(T));
        const dv_c = crml.rmlDataVariable_init(variable_definition.c(), ptr);
        return .{ .impl = dv_c };
    }

    /// cast to C-API type
    pub inline fn c(dmc: DataVariable) crml.RmlDataVariable {
        return dmc.impl;
    }
};

pub const DataModelHandle = struct {
    impl: crml.RmlDataModelHandle,

    pub inline fn isVariableDirty(handle: *const DataModelHandle, variable_name: []const u8) bool {
        return crml.rmlDataModelHandle_IsVariableDirty(&handle.impl, variable_name.ptr, variable_name.len);
    }

    pub inline fn dirtyVariable(handle: *const DataModelHandle, variable_name: []const u8) void {
        return crml.rmlDataModelHandle_DirtyVariable(&handle.impl, variable_name.ptr, variable_name.len);
    }

    pub inline fn dirtyAllVariables(handle: *const DataModelHandle) void {
        return crml.rmlDataModelHandle_DirtyAllVariables(&handle.impl);
    }

    /// cast from C-API type
    inline fn fromC(dmc: crml.RmlDataModelHandle) DataModelHandle {
        return .{ .impl = dmc };
    }
};

/// A string with the given max capacity
pub fn FixedString(comptime capacity: usize) type {
    return extern struct {
        header: crml.CRmlFixedStringHeader = .{
            .capacity = undefined,
            .len = undefined,
        },
        buf: [capacity]u8,

        pub const empty: Self = .{
            .header = .{
                .capacity = capacity,
                .len = 0,
            },
            .buf = undefined,
        };

        pub const Error = error{NoSpaceLeft};

        /// Same as init() but useful for getting compile-time checking on the length of
        /// the initial string
        pub inline fn initComptime(comptime data: []const u8) Self {
            var self: Self = .{
                .header = .{ .capacity = capacity, .len = data.len },
                .buf = undefined,
            };
            @memcpy(self.buf[0..data.len], data[0..]);
            return self;
        }

        pub inline fn init(comptime data: []const u8) Self.Error!Self {
            if (data.len >= capacity) return error.NoSpaceLeft;
            var self: Self = .{
                .header = .{ .capacity = capacity, .len = data.len },
                .buf = undefined,
            };
            @memcpy(self.buf[0..data.len], data[0..]);
            return self;
        }

        pub inline fn string(self: *Self) []const u8 {
            return self.buf[0..self.header.len];
        }

        pub fn format(comptime fmt: []const u8, args: anytype) Self.Error!Self {
            var self: Self = .empty;
            var w: Writer = .fixed(self.buf[0..]);
            w.print(fmt, args) catch |err| switch (err) {
                error.WriteFailed => return error.NoSpaceLeft,
            };
            self.header.len = w.end;
            return self;
        }

        const rml_type_options: internal.TypeOptions = .{
            .type_id_mode = .{
                .alias = crml.CRmlFixedStringHeader,
            },
            .create_definition = createRmlDefinition,
        };

        /// Called by DataModelConstructor.bind via DataTypeRegister().getDefinition
        fn createRmlDefinition() internal.CreateDefinitionError!?*VariableDefinition {
            const variable_def = crml.rmlFixedStringScalarDefinition_create() orelse
                return null;
            return .fromC(variable_def);
        }

        const Self = @This();
    };
}

/// API is not ready for public consumption so I'm putting it behind this.
const internal = struct {
    pub const CreateDefinitionError = error{};

    /// [Zig-exclusive] Add 'const rml_type_options: TypeOptions = .{}'
    pub const TypeOptions = struct {
        /// If not set to none, this will be used instead of generating a new type id
        /// at runtime per-type.
        type_id_mode: TypeIdMode = .default,
        /// Called by DataModelConstructor.bind via DataTypeRegister().getDefinition
        create_definition: *const fn () CreateDefinitionError!?*VariableDefinition,

        const TypeIdMode = union(enum) {
            /// Use the type to determine the type id number lazily once at runtime
            default: void,
            /// Use a different type to lazily generate/look-up the unique number once at runtime.
            ///
            /// This is useful for generic types which generate a unique/new type but have an identical
            /// type definition where no behaviour needs to change.
            alias: type,
            /// Set a specific type id
            exact: FamilyId,
        };
    };
};

pub const DataTypeRegister = opaque {
    /// Returns true if it was inserted
    pub inline fn registerDefinition(dtr: *DataTypeRegister, id: FamilyId, definition: *VariableDefinition) error{RmlDefinitionAlreadyRegistered}!void {
        if (!crml.rmlDataTypeRegister_RegisterDefinition(dtr.c(), id.c(), definition.c()))
            return error.RmlDefinitionAlreadyRegistered;
    }

    pub fn getDefinition(dtr: *DataTypeRegister, comptime T: type) error{ RmlCreateDefinitionFailed, RmlDefinitionAlreadyRegistered, RmlTypeNotRegistered }!*VariableDefinition {
        switch (@typeInfo(T)) {
            .pointer => |info| {
                switch (info.size) {
                    .slice => {
                        if (info.is_const and info.child == u8) {
                            return try dtr.registerOrGetConstU8Definition();
                        }
                        @compileError("no support for slice type: " ++ @typeName(T));
                    },
                    else => @compileError("unsupported pointer type: " ++ @typeName(T)),
                }
            },
            .bool => |_| {
                const id = FamilyId.getTypeId(T);
                if (dtr.getDefinitionById(id)) |vd| return vd;

                const variable_def = crml.rmlScalarDefinition_create(crml.RmlVariantType_Bool) orelse
                    return error.RmlCreateDefinitionFailed;
                const vd: *VariableDefinition = .fromC(variable_def);
                try dtr.registerDefinition(id, vd);
                return vd;
            },
            .int => |info| {
                // Scalar
                const variant_type: crml.RmlVariantType = blk: switch (info.signedness) {
                    .signed => {
                        if (info.bits == 1) break :blk crml.RmlVariantType_Bool;
                        if (info.bits <= 8) break :blk crml.RmlVariantType_Byte;
                        if (info.bits <= 32) break :blk crml.RmlVariantType_Int;
                        if (info.bits <= 64) break :blk crml.RmlVariantType_Int64;

                        @compileError("unsupported signed integer type: " ++ @typeName(T));
                    },
                    .unsigned => {
                        if (info.bits == 1) break :blk crml.RmlVariantType_Bool;
                        if (info.bits <= 8) break :blk crml.RmlVariantType_Byte;
                        if (info.bits <= 32) break :blk crml.RmlVariantType_Uint;
                        if (info.bits <= 64) break :blk crml.RmlVariantType_Uint64;

                        @compileError("unsupported unsigned integer type: " ++ @typeName(T));
                    },
                };

                // Get id by type, if we've already registered the definition, use it
                const id = FamilyId.getTypeId(T);
                if (dtr.getDefinitionById(id)) |vd| return vd;

                // Otherwise, register this new type definition
                const variable_def = crml.rmlScalarDefinition_create(variant_type) orelse
                    return error.RmlCreateDefinitionFailed;
                const vd: *VariableDefinition = .fromC(variable_def);
                try dtr.registerDefinition(id, vd);
                return vd;
            },
            .@"struct" => |_| {
                // TODO: Make this supported for enum, union and opaque types as well
                if (@hasDecl(T, "rml_type_options")) {
                    if (@TypeOf(T.rml_type_options) != internal.TypeOptions) {
                        @compileError("invalid 'rml_type_options' type, must be TypeOptions");
                    }
                    const rml_type_options: internal.TypeOptions = T.rml_type_options;
                    const id: FamilyId = switch (rml_type_options.type_id_mode) {
                        .default => FamilyId.getTypeId(T),
                        .alias => |AliasType| FamilyId.getTypeId(AliasType),
                        .exact => |const_family_id| const_family_id,
                    };
                    if (dtr.getDefinitionById(id)) |vd| return vd;

                    // Create definition
                    const variable_def = try rml_type_options.create_definition() orelse
                        return error.RmlCreateDefinitionFailed;
                    try dtr.registerDefinition(id, variable_def);
                    return variable_def;
                }

                const it = dtr.getDefinitionById(FamilyId.getTypeId(T)) orelse {
                    log.debug(
                        "Desired data type '{s}' not registered with the type register, please use the 'Register...()' functions before binding values, adding members, or registering arrays of non-scalar types.",
                        .{@typeName(T)},
                    );
                    return error.RmlTypeNotRegistered;
                };
                return it;
            },
            // If not a builtin type, look it up
            else => {
                const it = dtr.getDefinitionById(FamilyId.getTypeId(T)) orelse {
                    log.debug(
                        "Desired data type '{s}' not registered with the type register, please use the 'Register...()' functions before binding values, adding members, or registering arrays of non-scalar types.",
                        .{@typeName(T)},
                    );
                    return error.RmlTypeNotRegistered;
                };
                return it;
            },
        }
    }

    fn registerOrGetConstU8Definition(dtr: *DataTypeRegister) error{ RmlCreateDefinitionFailed, RmlDefinitionAlreadyRegistered }!*VariableDefinition {
        // Get id by type, if we've already registered the definition, use it
        const id = FamilyId.getTypeId([]const u8);
        if (dtr.getDefinitionById(id)) |vd| return vd;

        // Compute at runtime the shape of a Zig slice and validate
        // it matches the C-implementation
        const ZigSliceHolder = struct { str: []const u8 };
        var slice_holder: ZigSliceHolder = .{ .str = "(slice)" };
        const ptr_to_slice = @intFromPtr(&slice_holder.str);
        const slice_ptr_ptr = @intFromPtr(&slice_holder.str.ptr);
        const slice_len_ptr = @intFromPtr(&slice_holder.str.len);

        const ptr_offset = slice_ptr_ptr - ptr_to_slice;
        const len_offset = slice_len_ptr - ptr_to_slice;
        if (ptr_offset != 0)
            panic("Zig slice ptr offset is invalid, expected 0 but got {}", .{ptr_offset});
        if (len_offset != @sizeOf(usize))
            panic("Zig slice len offset is invalid, expected {} but got {}", .{ @sizeOf(usize), len_offset });

        // Otherwise, register this new type definition
        const variable_def = crml.rmlConstStringPtrLen_Definition_create(@intCast(ptr_offset), @intCast(len_offset)) orelse
            return error.RmlCreateDefinitionFailed;
        const vd: *VariableDefinition = .fromC(variable_def);
        try dtr.registerDefinition(id, vd);
        return vd;
    }

    /// [private] This is not part of the official RmlUi feature-set
    ///
    /// Return definition if found by id
    fn getDefinitionById(dtr: *DataTypeRegister, id: FamilyId) ?*VariableDefinition {
        return @ptrCast(crml.rmlDataTypeRegister_GetDefinitionById(dtr.c(), id.c()));
    }

    /// cast from C-API type
    pub inline fn fromC(dtr: *crml.RmlDataTypeRegister) *DataTypeRegister {
        return @ptrCast(dtr);
    }

    /// cast to C-API type
    pub inline fn c(dtr: *DataTypeRegister) *crml.RmlDataTypeRegister {
        return @ptrCast(dtr);
    }
};

pub const FontStyle = enum(u8) {
    normal = crml.RmlFontStyle_Normal,
    italic = crml.RmlFontStyle_Italic,
};

pub const FontWeight = enum(u10) {
    auto = crml.RmlFontWeight_Auto,
    /// ie. font-weight: 400;
    normal = crml.RmlFontWeight_Normal,
    /// ie. font-weight: 700;
    bold = crml.RmlFontWeight_Bold,
};

/// LoadFontFaceOptions uses the same defaults C++
pub const LoadFontFaceOptions = struct {
    style: FontStyle = .normal,
    weight: FontWeight = .auto,
    /// Set to true to use this font face for unknown characters in other font faces.
    fallback_face: bool = false,
    /// The index of the font face within a font collection
    face_index: u16 = 0,
};

pub inline fn LoadFontFaceFromMemory(data: []const u8, font_family_name: []const u8, options: LoadFontFaceOptions) error{RmlLoadFontFaceFailed}!void {
    if (!crml.rmlLoadFontFaceFromMemory(
        data[0..].ptr,
        data.len,
        font_family_name[0..].ptr,
        font_family_name.len,
        @intFromEnum(options.style),
        @intFromEnum(options.weight),
        options.fallback_face,
        options.face_index,
    )) return error.RmlLoadFontFaceFailed;
}

pub const FileInterface = opaque {};
pub const SystemInterface = opaque {};
pub const RenderInterface = opaque {};
pub const TextInputHandler = opaque {};

/// Sets the interface through which all system requests are made. This is not required to be called, but if it is, it
/// must be called before Initialise().
///
/// @param[in] system_interface A non-owning pointer to the application-specified logging interface.
/// @lifetime The interface must be kept alive until after the call to rmlui.Shutdown.
pub inline fn setSystemInterface(system_interface: *SystemInterface) void {
    return crml.rmlSetSystemInterface(@ptrCast(system_interface));
}

/// Sets the interface through which all rendering requests are made. This is not required to be called, but if it is,
/// it must be called before Initialise(). If no render interface is specified, then all contexts must specify a render
/// interface when created.
///
/// @param[in] render_interface A non-owning pointer to the render interface implementation.
/// @lifetime The interface must be kept alive until after the call to Rml::Shutdown.
pub inline fn setRenderInterface(render_interface: *RenderInterface) void {
    return crml.rmlSetRenderInterface(@ptrCast(render_interface));
}

/// Sets the interface through which all file I/O requests are made. This is not required to be called, but if it is, it
/// must be called before Initialise().
///
/// @param[in] file_interface A non-owning pointer to the application-specified file interface.
/// @lifetime The interface must be kept alive until after the call to Rml::Shutdown.
pub inline fn setFileInterface(file_interface: *FileInterface) void {
    return crml.rmlSetFileInterface(@ptrCast(file_interface));
}
