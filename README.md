# Zig RmlUi

⚠️ *This project is in its early days. Data binding still needs additional work for structs and array types, and the API is subject to change*

![Continuous integration](https://github.com/silbinarywolf/zig-rmlui/actions/workflows/ci.yml/badge.svg)

Zig RmlUi is a library that contains Zig bindings for the C++ library [RmlUi](https://github.com/mikke89/RmlUi) which based on the HTML and CSS standards

```zig
// This is an overly simplified example to give you the gist
// of how this library works
const rml = @import("rml");

pub fn main() !void {
    // Setup platform-specific interfaces (ie. SDL3)
    rml.setSystemInterface(...);
    rml.setRenderInterface(...);
    rml.setFileInterface(...);
    
    try rml.initialise();
    defer rml.shutdown();

    const context = try rml.createContext("main", 1280, 720, .default);
    try rml.debugger.initialise(context);

    // Example of data binding setup, derived from the tutorial here: https://mikke89.github.io/RmlUiDoc/pages/data_bindings/examples.html
    const MyData = struct {
        // FixedString is a Zig-API provided type with a fixed capacity, for two-way binding
        title: rml.FixedString(256) = .initComptime("Hello World!"),
        animal: rml.FixedString(128) = .initComptime("dog"),
        // []const u8 strings are readonly and cannot be updated in an <input> field, but you can bind and update them via "dirtyVariable"
        readonly_text: []const u8 = "the cat is meowing",
        show_text: bool = true,
    };
    var my_data: MyData = .{};
    const my_model = modelblk: {
        var dmc = try context.createDataModel("my_model", null);
        try dmc.bind("title", &my_data.title);
        try dmc.bind("animal", &my_data.animal);
        try dmc.bind("readonly_text", &my_data.readonly_text);
        try dmc.bind("show_text", &my_data.show_text);

        break :modelblk dmc.getModelHandle();
    };

    // Load Document
    const document = try context.loadDocumentFromMemory(@embedFile("data/main.rml"), "data/main.rml");
    document.show(.default);

    while (!has_quit) {
        // Event Loop
        while (SDL_PollEvent(...)) {
             if (!rml.sdl.inputEventHandler(context, window, &sdl_event)) {
                // If false, then RmlUi consumed/processed that event, don't process it ourselves
                continue;
            }
        }

        // Update
        if (my_model.isVariableDirty("animal")) {
            my_data.title = try .format("Hello {s}!", .{my_data.animal.string()});
            my_model.dirtyVariable("title");

            my_data.other_text = "the cats meowing has ceased...";
            my_model.dirtyVariable("other_text");
        }
        _ = context.update(); // Run RmlUi input handling logic, etc

        // Draw
        sdl.SDL_SetRenderDrawColor(renderer, 20, 20, 20, 0);
        sdl.SDL_RenderClear(renderer);

        render_interface.beginFrame();
        _ = context.render(); // Render RmlUi
        render_interface.endFrame();

        sdl.SDL_RenderPresent(renderer)
    }
}
```

## Installation

Option A. Install with package manager
```sh
zig fetch --save https://github.com/silbinarywolf/rmlui/archive/REPLACE_WITH_WANTED_COMMIT.tar.gz"
```

Option B. Copy-paste the dependency into your project directly and put in a `third-party` folder. This is recommended if you want to easily hack on it or tweak it.
```zig
.{
    .name = .yourzigproject,
    .dependencies = .{
        .android = .{
            .path = "third-party/rmlui",
        },
    },
}
```

## Examples

* [SDL3](examples/sdl3): An example of how to get setup with SDL3 and small examples of using bindings.

## How does this Zig library work?

I've handwritten a [C-API wrapper](crmlui/crmlui.cpp) that call out to the C++ code, similar to how [cimgui](https://github.com/cimgui/cimgui) works with [ImGui](github.com/ocornut/imgui).

However because the binding logic for RmlUi relies on C++ templating (generics), I've had to spend some time understanding how those types are registered with RmlUi and then write specific Zig code that works similarly, such as generating a type id dynamically once when a value is bound [here](src/FamilyId.zig).

## Credits

- [mikke89](https://github.com/mikke89/RmlUi) for maintaining this awesome library.
