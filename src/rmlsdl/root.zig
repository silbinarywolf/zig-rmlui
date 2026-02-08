//! SDL interface code

const rml = @import("rml");
const crml = @import("crml");

const Context = rml.Context;
const Error = rml.Error;

const SdlWindow = crml.SDL_Window;
const SdlEvent = crml.SDL_Event;
const SdlRenderer = crml.SDL_Renderer;

/// This should be called within the SDL_PollEvent loop.
///
/// If RmlUi consumed the event then return false / continue the loop and stop processing.
pub fn inputEventHandler(context: *Context, window: *SdlWindow, event: *SdlEvent) bool {
    return crml.rmlInputEventHandler_SDL(context.c(), @ptrCast(window), @ptrCast(event));
}

pub const SystemInterface = opaque {
    pub inline fn create() error{RmlSystemInterfaceCreateFailed}!*SystemInterface {
        const r = crml.rmlSystemInterface_SDL_new() orelse return error.RmlSystemInterfaceCreateFailed;
        return @ptrCast(r);
    }

    pub inline fn destroy(system_interface: *SystemInterface) void {
        return crml.rmlSystemInterface_SDL_free(system_interface.c());
    }

    pub inline fn setWindow(system_interface: *SystemInterface, window: *SdlWindow) void {
        return crml.rmlSystemInterface_SDL_SetWindow(system_interface.c(), window);
    }

    pub inline fn interface(system_interface: *SystemInterface) *rml.SystemInterface {
        return @ptrCast(system_interface);
    }

    /// cast to C-API type
    pub inline fn c(system_interface: *SystemInterface) *crml.SystemInterface_SDL {
        return @ptrCast(system_interface);
    }
};

pub const RenderInterface = opaque {
    /// Pass your SDL renderer in. This will require using @ptrCast().
    pub inline fn create(renderer: *SdlRenderer) error{RmlRenderInterfaceCreateFailed}!*RenderInterface {
        const r = crml.rmlRenderInterface_SDL_new(@ptrCast(renderer)) orelse return error.RmlRenderInterfaceCreateFailed;
        return @ptrCast(r);
    }

    pub inline fn destroy(render_interface: *RenderInterface) void {
        return crml.rmlRenderInterface_SDL_free(render_interface.c());
    }

    pub inline fn beginFrame(render_interface: *RenderInterface) void {
        return crml.rmlRenderInterface_SDL_BeginFrame(render_interface.c());
    }

    pub inline fn endFrame(render_interface: *RenderInterface) void {
        return crml.rmlRenderInterface_SDL_EndFrame(render_interface.c());
    }

    /// cast to base RenderInterface
    pub inline fn interface(render_interface: *RenderInterface) *rml.RenderInterface {
        return @ptrCast(render_interface);
    }

    /// cast to C-API type
    pub inline fn c(render_interface: *RenderInterface) *crml.RenderInterface_SDL {
        return @ptrCast(render_interface);
    }
};

const testing = @import("std").testing;

test {
    testing.refAllDecls(@This());
}
