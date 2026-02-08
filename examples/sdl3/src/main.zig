const std = @import("std");
const rml = @import("rml");
const rmldebug = @import("rmldebug");
const rmlsdl = @import("rmlsdl");
const log = std.log;
const sdl = @import("sdl");

const RmlAppState = struct {
    system_interface: *rmlsdl.SystemInterface,
    render_interface: *rmlsdl.RenderInterface,
    file_interface: rml.ZigFileInterface,
    context: *rml.Context,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_GAMEPAD)) {
        log.err("unable to initialize SDL: {s}", .{sdl.SDL_GetError()});
        return error.SdlError;
    }
    defer sdl.SDL_Quit();

    if (!sdl.SDL_SetHint(sdl.SDL_HINT_RENDER_VSYNC, "1")) {
        log.err("failed to enable vsync: {s}", .{sdl.SDL_GetError()});
        return error.SdlError;
    }

    var window: ?*sdl.SDL_Window = undefined;
    var renderer: ?*sdl.SDL_Renderer = undefined;
    if (!sdl.SDL_CreateWindowAndRenderer("RmlUi Example", 1280, 720, sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY, &window, &renderer)) {
        log.err("failed to create window and renderer: {s}", .{sdl.SDL_GetError()});
        return error.SdlError;
    }
    defer sdl.SDL_DestroyWindow(window);
    defer sdl.SDL_DestroyRenderer(renderer);

    // Set window to be resizeable so users can see how text flow automatically fits to the window
    _ = sdl.SDL_SetWindowResizable(window, true);

    const rmlui_template_name = "data/main.rml";
    var rmlui: RmlAppState = rmluiblk: {
        // Setup RML interfaces to handle
        // - Rendering
        // - System
        // - File System (ie. loading *.rcss files)
        const system_interface = try rmlsdl.SystemInterface.create();
        system_interface.setWindow(@ptrCast(window));
        errdefer system_interface.destroy();
        rml.setSystemInterface(system_interface.interface());
        const render_interface = try rmlsdl.RenderInterface.create(@ptrCast(renderer));
        errdefer render_interface.destroy();
        rml.setRenderInterface(render_interface.interface());
        var file_interface: rml.ZigFileInterface = undefined;
        try file_interface.init(allocator, .{
            // NOTE: Can set a specific directory to load RmlUi assets from, otherwise defaults to current working directory
            // .root_directory = try std.fs.cwd().openDir("src", .{}),
            .embedded_files = &.{
                .{ .path = "data/main.rcss", .data = @embedFile("data/main.rcss") },
                .{ .path = rmlui_template_name, .data = @embedFile(rmlui_template_name) },
            },
        });
        errdefer file_interface.deinit(allocator);
        rml.setFileInterface(file_interface.interface());

        // Setup RML
        try rml.initialise();
        errdefer rml.shutdown();

        // Load fonts
        const lato_font_family_name = "Lato";
        try rml.loadFontFaceFromMemory(
            @embedFile("data/Lato-Regular.ttf"),
            lato_font_family_name,
            .{},
        );
        try rml.loadFontFaceFromMemory(
            @embedFile("data/Lato-Light.ttf"),
            lato_font_family_name,
            .{},
        );

        // Setup the RmlUi Context: https://mikke89.github.io/RmlUiDoc/pages/cpp_manual/contexts.html
        var window_width: c_int = undefined;
        var window_height: c_int = undefined;
        if (!sdl.SDL_GetWindowSize(window, &window_width, &window_height)) {
            log.err("failed to get window size: {s}", .{sdl.SDL_GetError()});
            return error.SdlError;
        }
        const context = try rml.createContext("main", window_width, window_height, .default);
        errdefer context.destroy();
        context.setDensityIndependentPixelRatio(sdl.SDL_GetWindowDisplayScale(window));

        try rmldebug.initialise(context);

        break :rmluiblk RmlAppState{
            .system_interface = system_interface,
            .render_interface = render_interface,
            .file_interface = file_interface,
            .context = context,
        };
    };
    defer {
        rmlui.context.destroy();
        rml.shutdown();
        rmlui.system_interface.destroy();
        rmlui.render_interface.destroy();
        rmlui.file_interface.deinit(allocator);
    }

    // Example of data binding setup, based on the tutorial here:
    // https://mikke89.github.io/RmlUiDoc/pages/data_bindings/examples.html
    const MyData = struct {
        // FixedString is a Zig-API provided type with a fixed capacity
        title: rml.FixedString(256) = .initComptime("Hello World!"),
        animal: rml.FixedString(128) = .initComptime("dog"),
        // []const u8 strings are readonly and cannot be updated in an <input> field, but you can bind and update them via "dirtyVariable"
        readonly_text: []const u8 = "the cat is meowing",
        show_text: bool = true,
    };
    var my_data: MyData = .{};
    const my_model = modelblk: {
        var dmc = try rmlui.context.createDataModel("my_model", .default);
        try dmc.bind("title", &my_data.title);
        try dmc.bind("animal", &my_data.animal);
        try dmc.bind("readonly_text", &my_data.readonly_text);
        try dmc.bind("show_text", &my_data.show_text);

        break :modelblk dmc.getModelHandle();
    };

    const document = try rmlui.context.loadDocument(rmlui_template_name);
    document.show(.default);

    var has_quit = false;
    while (!has_quit) {
        // Event polling
        {
            const power_save = true;

            // If you're building a UI application, you can use SDL_WaitEventTimeout to utilize
            // less CPU usage. This logic was taken from the RmlUi renderer code here:
            // https://github.com/mikke89/RmlUi/blob/8063b13f068747496fa596dfa77997ecea4e5f0e/Backends/RmlUi_Backend_SDL_SDLrenderer.cpp#L167
            var sdl_event: sdl.SDL_Event = undefined;
            var has_event = if (power_save)
                sdl.SDL_WaitEventTimeout(&sdl_event, @intFromFloat(@min(rmlui.context.getNextUpdateDelay(), 10) * 1000))
            else
                sdl.SDL_PollEvent(&sdl_event);
            while (has_event) : (has_event = sdl.SDL_PollEvent(&sdl_event)) {
                // Press+Release 'CTRL+D' to open and close the debugger UI
                if (sdl_event.type == sdl.SDL_EVENT_KEY_UP and
                    (sdl_event.key.mod == sdl.SDL_KMOD_LCTRL or sdl_event.key.mod == sdl.SDL_KMOD_RCTRL) and
                    sdl_event.key.key == sdl.SDLK_D)
                {
                    if (!rmldebug.isVisible()) {
                        log.info("RmlUi debugger opened", .{});
                        rmldebug.setVisible(true);
                    } else {
                        log.info("RmlUi debugger closed", .{});
                        rmldebug.setVisible(false);
                    }
                }
                if (!rmlsdl.inputEventHandler(rmlui.context, @ptrCast(window), @ptrCast(&sdl_event))) {
                    // If false, then RmlUi consumed/processed that event, don't process it ourselves
                    continue;
                }

                switch (sdl_event.type) {
                    sdl.SDL_EVENT_QUIT => {
                        // If triggered quit, close entire app
                        has_quit = true;
                    },
                    // ... Handle SDL events ...
                    else => {},
                }
            }
        }

        // Update logic
        {
            if (my_model.isVariableDirty("animal")) {
                my_data.title = try .format("Hello {s}!", .{my_data.animal.string()});
                my_model.dirtyVariable("title");

                my_data.readonly_text = "the cats meowing has ceased...";
                my_model.dirtyVariable("readonly_text");
            }

            // Update RmlUi context
            // https://github.com/mikke89/RmlUi/blob/801b23945d36e7368c8f3df4653bee1b513c71d5/Samples/tutorial/template/src/main.cpp#L67
            _ = rmlui.context.update();
        }

        // Draw
        {
            _ = sdl.SDL_SetRenderDrawColor(renderer, 20, 20, 20, 0);
            _ = sdl.SDL_RenderClear(renderer);

            // Render RmlUi context
            // https://github.com/mikke89/RmlUi/blob/801b23945d36e7368c8f3df4653bee1b513c71d5/Samples/tutorial/template/src/main.cpp#L69C12-L69C22
            rmlui.render_interface.beginFrame();
            _ = rmlui.context.render();
            rmlui.render_interface.endFrame();

            if (!sdl.SDL_RenderPresent(renderer)) {
                log.err("render present failed: {s}", .{sdl.SDL_GetError()});
                return error.SdlError;
            }
        }
    }
}
