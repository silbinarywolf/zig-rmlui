const std = @import("std");
const builtin = @import("builtin");
const LazyPath = std.Build.LazyPath;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // TODO: Make linkage a build option
    const linkage: std.builtin.LinkMode = .static;
    const optional_freetype_include_path = b.option(
        LazyPath,
        "freetype_include_path",
        "Used to compile with FreeType support and include <ft2build.h>",
    );
    const optional_sdl_include_path = b.option(
        LazyPath,
        "sdl_include_path",
        "Used to compile with SDL platform/renderer support",
    );
    const optional_sdl_image_include_path = b.option(
        LazyPath,
        "sdl_image_include_path",
        "Used to compile with SDL_image platform/renderer support",
    );
    // TODO: Add support for SDL2 if needed in the future
    const sdl_major_version = 3;
    const rmlui_sdl_version_major_macro: *const [1:0]u8 = switch (sdl_major_version) {
        2 => "2",
        3 => "3",
        else => std.debug.panic("invalid SDL major version, only 2 or 3 is supported"),
    };

    const rmlui_path: LazyPath = blk: {
        const dep: *std.Build.Dependency = b.lazyDependency("rmlui", .{}) orelse break :blk b.path("");
        break :blk dep.path("");
    };
    const rmlui_include_path = rmlui_path.path(b, "Include");
    const rmlui_backend_include_path = rmlui_path.path(b, "Backends");

    // -DRMLUI_CUSTOM_RTTI=ON -DCMAKE_CXX_FLAGS="-fno-exceptions -fno-rtti"
    const disable_rtti_and_exceptions = false;

    const cpp_flags: []const []const u8 = [_][]const u8{
        // "In addition, a C++17 compatible compiler is required." - As of 2026-02-08, previously it was 2014
        // https://github.com/mikke89/RmlUi?tab=readme-ov-file#dependencies
        "-std=c++17",
    } ++ if (disable_rtti_and_exceptions)
        &[_][]const u8{ "-fno-exceptions", "-fno-rtti" }
    else
        &[0][]const u8{};

    // Create rmlui_core library
    const rmlui_core_lib = libblk: {
        const mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });
        if (disable_rtti_and_exceptions) {
            mod.addCMacro("RMLUI_CUSTOM_RTTI", "1");
            mod.addCMacro("RMLUI_NO_THIRDPARTY_CONTAINERS", "1");
        }
        if (linkage == .static) {
            mod.addCMacro("RMLUI_STATIC_LIB", "1");
        }
        mod.addCSourceFiles(.{
            .root = rmlui_path.path(b, "Source"),
            .files = &rmlui_src_files,
            .flags = cpp_flags,
        });
        if (optional_freetype_include_path) |freetype_include_path| {
            // If RMLUI_FONT_ENGINE_FREETYPE is not defined then "Source/Core/Core.cpp"
            // won't load the FreeType font interface by default. (FontEngineInterfaceDefault)
            mod.addCMacro("RMLUI_FONT_ENGINE_FREETYPE", "1");
            mod.addCSourceFiles(.{
                .root = rmlui_path.path(b, "Source"),
                .files = &rmlui_font_engine_default_src_files,
                .flags = cpp_flags,
            });
            mod.addIncludePath(freetype_include_path);
        }

        const rmlui_core_lib = b.addLibrary(.{
            .name = "rmlui_core",
            .linkage = .static,
            .root_module = mod,
        });
        b.installArtifact(rmlui_core_lib);
        break :libblk rmlui_core_lib;
    };

    // Add rmlui_debugger library
    const rmlui_debugger_lib = libblk: {
        const mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });
        if (linkage == .static) {
            mod.addCMacro("RMLUI_STATIC_LIB", "1");
        }
        if (disable_rtti_and_exceptions) {
            mod.addCMacro("RMLUI_CUSTOM_RTTI", "1");
            mod.addCMacro("RMLUI_NO_THIRDPARTY_CONTAINERS", "1");
        }
        mod.addCSourceFiles(.{
            .root = rmlui_path.path(b, "Source"),
            .files = &rmlui_debugger_src_files,
            .flags = cpp_flags,
        });

        const rmlui_debugger_lib = b.addLibrary(.{
            .name = "rmlui_debugger",
            .linkage = .static,
            .root_module = mod,
        });
        b.installArtifact(rmlui_debugger_lib);
        break :libblk rmlui_debugger_lib;
    };

    // Add crmlui module (C-bindings)
    const crmlui_mod = modblk: {
        // Add C-RmlUi binding library
        const crmlui_lib = libblk: {
            const mod = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libcpp = true,
            });
            mod.addCMacro("CRMLUI_IMPL_API", "extern \"C\"");
            if (disable_rtti_and_exceptions) {
                mod.addCMacro("RMLUI_CUSTOM_RTTI", "ON");
            }
            if (optional_sdl_include_path) |sdl_include_path| {
                mod.addCMacro("RMLUI_SDL_VERSION_MAJOR", "3");
                mod.addIncludePath(sdl_include_path);
            }
            mod.addCSourceFiles(.{
                .root = b.path("crmlui"),
                .files = &.{"crmlui.cpp"},
                .flags = cpp_flags,
            });
            mod.addIncludePath(rmlui_include_path);
            mod.addIncludePath(rmlui_backend_include_path);

            mod.addCMacro("CRMLUI_HAS_CORE", "1");
            mod.linkLibrary(rmlui_core_lib);

            mod.addCMacro("CRMLUI_HAS_DEBUGGER", "1");
            mod.linkLibrary(rmlui_debugger_lib);

            const crmlui_lib = b.addLibrary(.{
                .name = "crmlui",
                .linkage = .static,
                .root_module = mod,
            });
            b.installArtifact(crmlui_lib);
            break :libblk crmlui_lib;
        };

        var c_translate = b.addTranslateC(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("crmlui/crmlui.h"),
        });
        c_translate.defineCMacro("CRMLUI_HAS_CORE", "1");
        c_translate.defineCMacro("CRMLUI_HAS_DEBUGGER", "1");
        c_translate.defineCMacro("CRMLUI_DEFINE_ENUMS_AND_STRUCTS", "1");
        if (optional_sdl_include_path) |_| {
            c_translate.defineCMacro("CRMLUI_HAS_SDL_BACKEND", "1");
        }
        c_translate.addIncludePath(b.path("crmlui/crmlui.h"));
        const crmlui_mod = c_translate.createModule();
        crmlui_mod.linkLibrary(crmlui_lib);
        break :modblk crmlui_mod;
    };

    // Add rml module
    const rml_mod = modblk: {
        const rml_mod = b.addModule("rml", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/rml/root.zig"),
        });
        rml_mod.addImport("crml", crmlui_mod);
        rml_mod.linkLibrary(rmlui_core_lib);
        break :modblk rml_mod;
    };

    _ = modblk: {
        const rml_debug_mod = b.addModule("rmldebug", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/rmldebug/root.zig"),
        });
        rml_debug_mod.addImport("rml", rml_mod);
        rml_debug_mod.addImport("crml", crmlui_mod);
        rml_debug_mod.linkLibrary(rmlui_debugger_lib);
        break :modblk rml_debug_mod;
    };

    // Add SDL3 backend (rmlui_backend_SDL_SDLrenderer)
    {
        const rmlsdl_mod = b.addModule("rmlsdl", .{
            .root_source_file = b.path("src/rmlsdl/root.zig"),
            .target = target,
            .optimize = optimize,
        });
        rmlsdl_mod.addImport("rml", rml_mod);
        rmlsdl_mod.addImport("crml", crmlui_mod);

        if (optional_sdl_include_path) |sdl_include_path| {
            const sdl_renderer_lib_mod = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libcpp = true,
            });
            if (disable_rtti_and_exceptions) {
                sdl_renderer_lib_mod.addCMacro("RMLUI_CUSTOM_RTTI", "ON");
            }
            sdl_renderer_lib_mod.addCMacro("RMLUI_SDL_VERSION_MAJOR", rmlui_sdl_version_major_macro);
            sdl_renderer_lib_mod.addCSourceFiles(.{
                .root = rmlui_path.path(b, "Backends"),
                .files = rmlui_sdl_renderer_backend,
                .flags = cpp_flags,
            });
            sdl_renderer_lib_mod.addIncludePath(rmlui_include_path);
            sdl_renderer_lib_mod.addIncludePath(sdl_include_path);

            if (optional_sdl_image_include_path) |sdl_image_include_path| {
                // Add SDL_image include path
                // - SDL2: #include <SDL_image.h>
                // - SDL3: #include <SDL3_image/SDL_image.h>
                sdl_renderer_lib_mod.addIncludePath(sdl_image_include_path);
            } else {
                switch (sdl_major_version) {
                    2 => @panic("must add SDL_image include path for SDL2"),
                    3 => {
                        // If SDL3_image is not provided then support PNG loading only using SDL 3.4.X+
                        const sdl3_image_path = b.path("src/sdl3_image_patch");
                        sdl_renderer_lib_mod.addIncludePath(sdl3_image_path);
                    },
                    else => unreachable,
                }
            }

            const sdl_renderer_lib = b.addLibrary(.{
                .name = "rmlui_backend_SDL_SDLrenderer",
                .linkage = .static,
                .root_module = sdl_renderer_lib_mod,
            });
            b.installArtifact(sdl_renderer_lib);

            rmlsdl_mod.linkLibrary(sdl_renderer_lib);
        }
    }

    // NOTE(jae): 2026-01-25
    // Other RmlUi libraries
    // - rmlui_debugger
    // - rmlui_lua
    //
    // Backends I care about:
    // - rmlui_backend_SDL_SDLrenderer
    // - rmlui_backend_SDL_GPU
    //
    // Libraries I dont:
    // - rmlui_shell - rmlui_shell is NOT a sample. It's a utility static library with code common to the RmlUi samples.

    const test_filters: []const []const u8 = b.option([]const []const u8, "test-filter", "Skip tests that do not match any filter") orelse &[0][]const u8{};
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{
        .root_module = rml_mod,
        .filters = test_filters,
    })).step);
}

const SdlMajorVersion = enum {
    @"2",
    @"3",
};

/// Library: rmlui_backend_SDL_SDLrenderer
/// Source: rmlui/Backends/CMakeLists.txt
const rmlui_sdl_renderer_backend = &[_][]const u8{
    "RmlUi_Renderer_SDL.cpp",
    "RmlUi_Backend_SDL_SDLrenderer.cpp",
    // common with rmlui_backend_SDL_SDLrenderer
    "RmlUi_Platform_SDL.cpp",
};

/// Library: rmlui_backend_SDL_GPU
/// Source: rmlui/Backends/CMakeLists.txt
const rmlui_sdl_gpu_backend = &[_][]const u8{
    "RmlUi_Renderer_SDL_GPU.cpp",
    "RmlUi_Backend_SDL_GPU.cpp",
    // common with rmlui_backend_SDL_SDLrenderer
    "RmlUi_Platform_SDL.cpp",
};

const rmlui_src_files = [_][]const u8{
    "Core/BaseXMLParser.cpp",
    "Core/Box.cpp",
    "Core/BoxShadowCache.cpp",
    "Core/CallbackTexture.cpp",
    "Core/Clock.cpp",
    "Core/CompiledFilterShader.cpp",
    "Core/ComputedValues.cpp",
    "Core/ComputeProperty.cpp",
    "Core/Context.cpp",
    "Core/ContextInstancer.cpp",
    "Core/ContextInstancerDefault.cpp",
    "Core/ConvolutionFilter.cpp",
    "Core/Core.cpp",
    "Core/DataController.cpp",
    "Core/DataControllerDefault.cpp",
    "Core/DataExpression.cpp",
    "Core/DataModel.cpp",
    "Core/DataModelHandle.cpp",
    "Core/DataTypeRegister.cpp",
    "Core/DataVariable.cpp",
    "Core/DataView.cpp",
    "Core/DataViewDefault.cpp",
    "Core/Decorator.cpp",
    "Core/DecoratorGradient.cpp",
    "Core/DecoratorNinePatch.cpp",
    "Core/DecoratorShader.cpp",
    "Core/DecoratorText.cpp",
    "Core/DecoratorTiledBox.cpp",
    "Core/DecoratorTiled.cpp",
    "Core/DecoratorTiledHorizontal.cpp",
    "Core/DecoratorTiledImage.cpp",
    "Core/DecoratorTiledVertical.cpp",
    "Core/DecoratorUtilities.cpp",
    "Core/DocumentHeader.cpp",
    "Core/EffectSpecification.cpp",
    "Core/ElementAnimation.cpp",
    "Core/ElementBackgroundBorder.cpp",
    "Core/Element.cpp",
    "Core/ElementDefinition.cpp",
    "Core/ElementDocument.cpp",
    "Core/ElementEffects.cpp",
    "Core/ElementHandle.cpp",
    "Core/ElementInstancer.cpp",
    "Core/ElementMeta.cpp",
    //
    "Core/Elements/ElementFormControl.cpp",
    "Core/Elements/ElementFormControlInput.cpp",
    "Core/Elements/ElementFormControlSelect.cpp",
    "Core/Elements/ElementFormControlTextArea.cpp",
    "Core/Elements/ElementForm.cpp",
    "Core/Elements/ElementImage.cpp",
    "Core/Elements/ElementLabel.cpp",
    "Core/Elements/ElementProgress.cpp",
    "Core/Elements/ElementTabSet.cpp",
    "Core/Elements/ElementTextSelection.cpp",
    "Core/Elements/InputTypeButton.cpp",
    "Core/Elements/InputTypeCheckbox.cpp",
    "Core/Elements/InputType.cpp",
    "Core/Elements/InputTypeRadio.cpp",
    "Core/Elements/InputTypeRange.cpp",
    "Core/Elements/InputTypeSubmit.cpp",
    "Core/Elements/InputTypeText.cpp",
    "Core/Elements/WidgetDropDown.cpp",
    "Core/Elements/WidgetSlider.cpp",
    "Core/Elements/WidgetTextInput.cpp",
    "Core/Elements/WidgetTextInputMultiLine.cpp",
    "Core/Elements/WidgetTextInputSingleLine.cpp",
    "Core/Elements/WidgetTextInputSingleLinePassword.cpp",
    "Core/Elements/XMLNodeHandlerSelect.cpp",
    "Core/Elements/XMLNodeHandlerTabSet.cpp",
    "Core/Elements/XMLNodeHandlerTextArea.cpp",
    "Core/ElementScroll.cpp",
    "Core/ElementStyle.cpp",
    "Core/ElementText.cpp",
    "Core/ElementUtilities.cpp",
    "Core/Event.cpp",
    "Core/EventDispatcher.cpp",
    "Core/EventInstancer.cpp",
    "Core/EventInstancerDefault.cpp",
    "Core/EventListenerInstancer.cpp",
    "Core/EventSpecification.cpp",
    "Core/Factory.cpp",
    "Core/FileInterface.cpp",
    "Core/FileInterfaceDefault.cpp",
    "Core/FilterBasic.cpp",
    "Core/FilterBlur.cpp",
    "Core/Filter.cpp",
    "Core/FilterDropShadow.cpp",
    //
    "Core/FontEffectBlur.cpp",
    "Core/FontEffect.cpp",
    "Core/FontEffectGlow.cpp",
    "Core/FontEffectInstancer.cpp",
    "Core/FontEffectOutline.cpp",
    "Core/FontEffectShadow.cpp",
    "Core/FontEngineInterface.cpp",
    //
    "Core/GeometryBackgroundBorder.cpp",
    "Core/GeometryBoxShadow.cpp",
    "Core/Geometry.cpp",
    //
    "Core/Layout/BlockContainer.cpp",
    "Core/Layout/BlockFormattingContext.cpp",
    "Core/Layout/ContainerBox.cpp",
    "Core/Layout/FlexFormattingContext.cpp",
    "Core/Layout/FloatedBoxSpace.cpp",
    "Core/Layout/FormattingContext.cpp",
    "Core/Layout/InlineBox.cpp",
    "Core/Layout/InlineContainer.cpp",
    "Core/Layout/InlineLevelBox.cpp",
    "Core/Layout/LayoutBox.cpp",
    "Core/Layout/LayoutDetails.cpp",
    "Core/Layout/LayoutEngine.cpp",
    "Core/Layout/LayoutPools.cpp",
    "Core/Layout/LineBox.cpp",
    "Core/Layout/ReplacedFormattingContext.cpp",
    "Core/Layout/TableFormattingContext.cpp",
    "Core/Layout/TableFormattingDetails.cpp",
    "Core/Log.cpp",
    "Core/LogDefault.cpp",
    "Core/Math.cpp",
    "Core/Memory.cpp",
    "Core/MeshUtilities.cpp",
    "Core/ObserverPtr.cpp",
    "Core/Plugin.cpp",
    "Core/PluginRegistry.cpp",
    "Core/Profiling.cpp",
    "Core/PropertiesIteratorView.cpp",
    "Core/Property.cpp",
    "Core/PropertyDefinition.cpp",
    "Core/PropertyDictionary.cpp",
    "Core/PropertyParserAnimation.cpp",
    "Core/PropertyParserBoxShadow.cpp",
    "Core/PropertyParserColorStopList.cpp",
    "Core/PropertyParserColour.cpp",
    "Core/PropertyParserDecorator.cpp",
    "Core/PropertyParserFilter.cpp",
    "Core/PropertyParserFontEffect.cpp",
    "Core/PropertyParserKeyword.cpp",
    "Core/PropertyParserNumber.cpp",
    "Core/PropertyParserRatio.cpp",
    "Core/PropertyParserString.cpp",
    "Core/PropertyParserTransform.cpp",
    "Core/PropertySpecification.cpp",
    "Core/RenderInterfaceCompatibility.cpp",
    "Core/RenderInterface.cpp",
    "Core/RenderManagerAccess.cpp",
    "Core/RenderManager.cpp",
    "Core/ScrollController.cpp",
    "Core/Spritesheet.cpp",
    "Core/Stream.cpp",
    "Core/StreamFile.cpp",
    "Core/StreamMemory.cpp",
    "Core/StringUtilities.cpp",
    "Core/StyleSheetContainer.cpp",
    "Core/StyleSheet.cpp",
    "Core/StyleSheetFactory.cpp",
    "Core/StyleSheetNode.cpp",
    "Core/StyleSheetParser.cpp",
    "Core/StyleSheetSelector.cpp",
    "Core/StyleSheetSpecification.cpp",
    "Core/SystemInterface.cpp",
    "Core/TemplateCache.cpp",
    "Core/Template.cpp",
    "Core/Texture.cpp",
    "Core/TextureDatabase.cpp",
    "Core/TextureLayout.cpp",
    "Core/TextureLayoutRectangle.cpp",
    "Core/TextureLayoutRow.cpp",
    "Core/TextureLayoutTexture.cpp",
    "Core/Traits.cpp",
    "Core/Transform.cpp",
    "Core/TransformPrimitive.cpp",
    "Core/TransformState.cpp",
    "Core/TransformUtilities.cpp",
    "Core/Tween.cpp",
    "Core/TypeConverter.cpp",
    "Core/URL.cpp",
    "Core/Variant.cpp",
    "Core/WidgetScroll.cpp",
    "Core/XMLNodeHandlerBody.cpp",
    "Core/XMLNodeHandler.cpp",
    "Core/XMLNodeHandlerDefault.cpp",
    "Core/XMLNodeHandlerHead.cpp",
    "Core/XMLNodeHandlerTemplate.cpp",
    "Core/XMLParser.cpp",
    "Core/XMLParseTools.cpp",
};

/// Used if RMLUI_FONT_ENGINE_FREETYPE is defined
const rmlui_font_engine_default_src_files = [_][]const u8{
    "Core/FontEngineDefault/FontEngineInterfaceDefault.cpp",
    "Core/FontEngineDefault/FontFace.cpp",
    "Core/FontEngineDefault/FontFaceHandleDefault.cpp",
    "Core/FontEngineDefault/FontFaceLayer.cpp",
    "Core/FontEngineDefault/FontFamily.cpp",
    "Core/FontEngineDefault/FontProvider.cpp",
    "Core/FontEngineDefault/FreeTypeInterface.cpp",
};

const rmlui_debugger_src_files = [_][]const u8{
    "Debugger/Debugger.cpp",
    "Debugger/DebuggerPlugin.cpp",
    "Debugger/DebuggerSystemInterface.cpp",
    "Debugger/ElementContextHook.cpp",
    "Debugger/ElementDataModels.cpp",
    "Debugger/ElementDebugDocument.cpp",
    "Debugger/ElementInfo.cpp",
    "Debugger/ElementLog.cpp",
    "Debugger/Geometry.cpp",
};

const rmlui_lottie_src_files = [_][]const u8{
    "Lottie/ElementLottie.cpp",
    "Lottie/LottiePlugin.cpp",
};

/// Define: RMLUI_SVG_PLUGIN
const rmlui_svg_src_files = [_][]const u8{
    "SVG/DecoratorSVG.cpp",
    "SVG/ElementSVG.cpp",
    "SVG/SVGCache.cpp",
    "SVG/SVGPlugin.cpp",
    "SVG/XMLNodeHandlerSVG.cpp",
};

const rmlui_lua_src_files = [_][]const u8{
    // Lua
    "Lua/Colourb.cpp",
    "Lua/Colourf.cpp",
    "Lua/Context.cpp",
    "Lua/ContextDocumentsProxy.cpp",
    "Lua/Document.cpp",
    "Lua/ElementAttributesProxy.cpp",
    "Lua/ElementChildNodesProxy.cpp",
    "Lua/Element.cpp",
    "Lua/ElementInstancer.cpp",
    // Lua/Elements
    "Lua/Elements/ElementFormControl.cpp",
    "Lua/Elements/ElementFormControlInput.cpp",
    "Lua/Elements/ElementFormControlSelect.cpp",
    "Lua/Elements/ElementFormControlTextArea.cpp",
    "Lua/Elements/ElementForm.cpp",
    "Lua/Elements/ElementTabSet.cpp",
    "Lua/Elements/SelectOptionsProxy.cpp",
    "Lua/ElementStyleProxy.cpp",
    "Lua/ElementText.cpp",
    "Lua/Event.cpp",
    "Lua/EventParametersProxy.cpp",
    "Lua/GlobalLuaFunctions.cpp",
    "Lua/Interpreter.cpp",
    "Lua/Log.cpp",
    "Lua/Lua.cpp",
    "Lua/LuaDataModel.cpp",
    "Lua/LuaDocument.cpp",
    "Lua/LuaDocumentElementInstancer.cpp",
    "Lua/LuaElementInstancer.cpp",
    "Lua/LuaEventListener.cpp",
    "Lua/LuaEventListenerInstancer.cpp",
    "Lua/LuaPlugin.cpp",
    "Lua/LuaType.cpp",
    "Lua/RmlUiContextsProxy.cpp",
    "Lua/RmlUi.cpp",
    "Lua/Utilities.cpp",
    "Lua/Vector2f.cpp",
    "Lua/Vector2i.cpp",
};
