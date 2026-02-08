//! RmlUi Debugger functions

const rml = @import("rml");
const crml = @import("crml");

const Context = rml.Context;
const Error = rml.Error;

/// Initialises the debug plugin. The debugger will be loaded into the given context.
///
/// The debugging tools will be displayed on this context. If this context is destroyed, the debugger will be released.
pub fn initialise(context: *Context) error{RmlDebuggerInitialiseFailed}!void {
    if (!crml.rmlDebuggerInitialise(context.c())) return error.RmlDebuggerInitialiseFailed;
}

/// Returns the visibility of the debugger.
pub fn isVisible() bool {
    return crml.rmlDebuggerIsVisible();
}

/// Sets the visibility of the debugger.
pub fn setVisible(visibility: bool) void {
    return crml.rmlDebuggerSetVisible(visibility);
}
