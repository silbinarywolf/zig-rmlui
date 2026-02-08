#ifndef CRMLUI_INCLUDED
#define CRMLUI_INCLUDED

#include <stddef.h>
#include <stdint.h>
#if defined _WIN32 || defined __CYGWIN__
    #ifdef CRMLUI_NO_EXPORT
        #define API
    #else
        #define API __declspec(dllexport)
    #endif
#else
    #ifdef __GNUC__
        #define API  __attribute__((__visibility__("default")))
    #else
        #define API
    #endif
#endif

#if defined __cplusplus
    #define EXTERN extern "C"
#else
    #include <stdarg.h>
    #include <stdbool.h>
    #define EXTERN extern
#endif

/**
 * Macro that annotates function params with input buffer size.
 * ```c
 * void *memcpy(void *dst, SDL_IN_BYTECAP(len) const void *src, size_t len);
 * ```
 */
#if defined(_MSC_VER) && (_MSC_VER >= 1600) /* VS 2010 and above */
#define CRMLUI_IN_BYTECAP(x) _In_bytecount_(x)
#else
#define CRMLUI_IN_BYTECAP(x)
#endif

/**
 * Macro that annotates function params with input/output string buffer size.
 * ```c
 * size_t strlcat(SDL_INOUT_Z_CAP(maxlen) char *dst, const char *src, size_t maxlen);
 * ```
 *
 * This notes that `dst` is a null-terminated C string, should be `maxlen`
 * bytes in size, and is both read from and written to by the function. The
 * compiler or other analysis tools can warn when this doesn't appear to be
 * the case.
 */
#if defined(_MSC_VER) && (_MSC_VER >= 1600) /* VS 2010 and above */
#define CRMLUI_INOUT_Z_CAP(x) _Inout_z_cap_(x)
#else
#define CRMLUI_INOUT_Z_CAP(x)
#endif

/* ignore CRMLUI_COMPILE_TIME_ASSERT in header files as we don't have the context to compare C++ classes against C structs */
#ifndef CRMLUI_COMPILE_TIME_ASSERT
#define CRMLUI_COMPILE_TIME_ASSERT(name, x) 
#endif 

/* ignore CRMLUI_COMPILE_TIME_ASSERT_OFFSETOF_MATCH in header files as we don't have the context to compare C++ classes against C structs */
#ifndef CRMLUI_COMPILE_TIME_ASSERT_OFFSETOF_MATCH
#define CRMLUI_COMPILE_TIME_ASSERT_OFFSETOF_MATCH(field_name, cpp_class, c_struct) 
#endif

#define CRMLUI_API EXTERN API
#define CONST const

#ifndef CRMLUI_HAS_CORE
#define CRMLUI_HAS_CORE 1
#endif

#ifndef CRMLUI_HAS_DEBUGGER
#define CRMLUI_HAS_DEBUGGER 0
#endif

#ifndef CRMLUI_HAS_SDL_BACKEND
#define CRMLUI_HAS_SDL_BACKEND 0
#endif

#ifdef CRMLUI_DEFINE_ENUMS_AND_STRUCTS
typedef struct RmlSystemInterface RmlSystemInterface;
typedef struct RmlRenderInterface RmlRenderInterface;
typedef struct RmlContext RmlContext;
typedef struct RmlTextInputHandler RmlTextInputHandler;
typedef struct RmlElement RmlElement;
typedef struct RmlElementDocument RmlElementDocument;
typedef struct RmlStream RmlStream;
typedef struct RmlFileInterface RmlFileInterface;
typedef struct RmlDataTypeRegister RmlDataTypeRegister;
typedef struct RmlDataModel RmlDataModel;
typedef struct RmlVariableDefinition RmlVariableDefinition;
typedef struct RmlString RmlString;
typedef struct RmlStructDefinition RmlStructDefinition;
struct RmlSystemInterface;
struct RmlRenderInterface;
struct RmlContext;
struct RmlTextInputHandler;
struct RmlElement;
struct RmlElementDocument;
struct RmlStream;
typedef uintptr_t RmlFileHandle;
struct RmlFileInterface;
struct RmlDataTypeRegister;
struct RmlDataModel;
struct RmlVariableDefinition;
typedef int RmlFamilyId;
struct RmlString;
struct RmlStructDefinition;
#else
typedef Rml::SystemInterface RmlSystemInterface;
typedef Rml::RenderInterface RmlRenderInterface;
typedef Rml::Context RmlContext;
typedef Rml::TextInputHandler RmlTextInputHandler;
typedef Rml::Element RmlElement;
typedef Rml::ElementDocument RmlElementDocument;
typedef Rml::Stream RmlStream;
typedef Rml::FileHandle RmlFileHandle;
typedef Rml::FileInterface RmlFileInterface;
// typedef Rml::DataModelConstructor RmlDataModelConstructor;
typedef Rml::DataTypeRegister RmlDataTypeRegister;
typedef Rml::DataModel RmlDataModel;
typedef Rml::VariableDefinition RmlVariableDefinition;
typedef Rml::FamilyId RmlFamilyId;
typedef Rml::String RmlString;
typedef Rml::StructDefinition RmlStructDefinition;
#endif

/// Comment from RmlUi: Type of data stored in the variant. We use size_t as base to avoid 'padding due to alignment specifier' warning.
typedef enum {
    RmlVariantType_None = '-',
    RmlVariantType_Bool = 'B',
    RmlVariantType_Byte = 'b',
    RmlVariantType_Char = 'c',
    RmlVariantType_Float  = 'f',
    RmlVariantType_Double = 'd',
    RmlVariantType_Int    = 'i',
    RmlVariantType_Int64  = 'I',
    RmlVariantType_Uint   = 'u',
    RmlVariantType_Uint64 = 'U',
    RmlVariantType_String = 's',
    RmlVariantType_Vector2f = '2',
    RmlVariantType_Vector3f = '3',
    RmlVariantType_Vector4f = '4',
    RmlVariantType_ColourF = 'g',
    RmlVariantType_ColourB = 'h',
    RmlVariantType_ScriptInterface = 'p',
    RmlVariantType_TransformPtr = 't',
    RmlVariantType_TransitionList = 'T',
    RmlVariantType_AnimationList = 'A',
    RmlVariantType_DecoratorsPtr = 'D',
    RmlVariantType_FiltersPtr = 'F',
    RmlVariantType_FontEffectsPtr = 'E',
    RmlVariantType_ColorStopList = 'C',
    RmlVariantType_BoxShadowList = 'S',
    RmlVariantType_VoidPtr = '*',
} RmlVariantType_;
typedef size_t RmlVariantType;
CRMLUI_COMPILE_TIME_ASSERT(rml_variant_type_size, sizeof(Rml::Variant::Type) == sizeof(RmlVariantType));

typedef struct CRmlSlice_PtrLen_usize {
	void* ptr;
	size_t size;
} CRmlSlice_PtrLen_usize;

// 24 == 32-bit
// 32 == 64-bit
// CRMLUI_COMPILE_TIME_ASSERT(rml_variant_local_data_size, Rml::Variant::LOCAL_DATA_SIZE == 32);

typedef struct RmlDataModelConstructor RmlDataModelConstructor;
typedef struct RmlDataModelConstructor_Private RmlDataModelConstructor_Private;
struct RmlDataModelConstructor_Private {
    RmlDataModel* model;
    RmlDataTypeRegister* type_register;
};
struct RmlDataModelConstructor {
    RmlDataModelConstructor_Private private_fields;
};
CRMLUI_COMPILE_TIME_ASSERT(RmlDataModelConstructor_struct_size, sizeof(Rml::DataModelConstructor) == sizeof(RmlDataModelConstructor));
CRMLUI_COMPILE_TIME_ASSERT_OFFSETOF_MATCH(model, Rml::DataModelConstructor, RmlDataModelConstructor_Private);
CRMLUI_COMPILE_TIME_ASSERT_OFFSETOF_MATCH(type_register, Rml::DataModelConstructor, RmlDataModelConstructor_Private);

typedef struct RmlDataVariable RmlDataVariable;
typedef struct RmlDataVariable_Private RmlDataVariable_Private;
struct RmlDataVariable_Private {
    RmlVariableDefinition* definition;
	void* ptr;
};
struct RmlDataVariable {
    RmlDataVariable_Private private_fields;
};
CRMLUI_COMPILE_TIME_ASSERT(RmlDataVariable_struct_size, sizeof(Rml::DataVariable) == sizeof(RmlDataVariable));
CRMLUI_COMPILE_TIME_ASSERT_OFFSETOF_MATCH(definition, Rml::DataVariable, RmlDataVariable_Private);
CRMLUI_COMPILE_TIME_ASSERT_OFFSETOF_MATCH(ptr, Rml::DataVariable, RmlDataVariable_Private);

typedef struct RmlDataModelHandle_Private {
    RmlDataModel* model;
} RmlDataModelHandle_Private;
typedef struct RmlDataModelHandle {
    RmlDataModelHandle_Private private_fields;
} RmlDataModelHandle;
CRMLUI_COMPILE_TIME_ASSERT(RmlDataModelHandle_struct_size, sizeof(Rml::DataModelHandle) == sizeof(RmlDataModelHandle));
CRMLUI_COMPILE_TIME_ASSERT_OFFSETOF_MATCH(model, Rml::DataModelHandle, RmlDataModelHandle_Private);

typedef struct RmlStructHandle_Private {
    RmlDataTypeRegister* type_register;
	RmlStructDefinition* struct_definition;
} RmlStructHandle_Private;
typedef struct RmlStructHandle {
    RmlStructHandle_Private private_fields;
} RmlStructHandle;
CRMLUI_COMPILE_TIME_ASSERT(RmlStructHandle_struct_size, sizeof(Rml::StructHandle<RmlDataModelConstructor>) == sizeof(RmlStructHandle));
CRMLUI_COMPILE_TIME_ASSERT_OFFSETOF_MATCH(type_register, Rml::StructHandle<RmlDataModelConstructor>, RmlStructHandle_Private);
CRMLUI_COMPILE_TIME_ASSERT_OFFSETOF_MATCH(struct_definition, Rml::StructHandle<RmlDataModelConstructor>, RmlStructHandle_Private);

typedef enum {
	RmlModalFlag_None,  // Remove modal state.
	RmlModalFlag_Modal, // Set modal state, other documents cannot receive focus.
	RmlModalFlag_Keep,  // Modal state unchanged.
} RmlModalFlag_;
typedef unsigned char RmlModalFlag;

typedef enum {
	RmlFocusFlag_None,     // No focus.
	RmlFocusFlag_Document, // Focus the document.
	RmlFocusFlag_Keep,     // Focus the element in the document which last had focus.
	RmlFocusFlag_Auto,     // Focus the first tab element with the 'autofocus' attribute or else the document.
} RmlFocusFlag_;
typedef unsigned char RmlFocusFlag;

typedef enum {
    RmlFontStyle_Normal = 0,
    RmlFontStyle_Italic = 1,
} RmlFontStyle_;
typedef uint8_t RmlFontStyle;

typedef enum {
    RmlFontWeight_Auto = 0,
    RmlFontWeight_Normal = 400,
    RmlFontWeight_Bold = 700,
} RmlFontWeight_;
typedef uint16_t RmlFontWeight;

/** C-API only type for handling fixed string type definitions */
typedef struct CRmlFixedStringHeader {
    size_t len;
	size_t capacity;
} CRmlFixedStringHeader;

/** 
 * Example: 
 * The shape of a FixedString type is a header with the len and capacity, then
 * the remaining data is an N-sized array
 */
typedef struct CRmlFixedStringShape {
	CRmlFixedStringHeader header;
	char buf_start[1]; /* [capacity]buf */
} CRmlFixedStringShape;

#if CRMLUI_HAS_CORE

/// Sets the interface through which all system requests are made. This is not required to be called, but if it is, it
/// must be called before Initialise().
/// @param[in] system_interface A non-owning pointer to the application-specified logging interface.
/// @lifetime The interface must be kept alive until after the call to Rml::Shutdown.
/// From: RmlUi/Core/Core.h
CRMLUI_API void rmlSetSystemInterface(RmlSystemInterface* _system_interface);

/// Returns RmlUi's system interface.
/// From: RmlUi/Core/Core.h
CRMLUI_API void rmlSetRenderInterface(RmlRenderInterface* _render_interface);

/// Initialises RmlUi.
/// Call rmlShutdown() to uninitialise;
///
/// From: RmlUi/Core/Core.h
CRMLUI_API bool rmlInitialise(void);

/// From: RmlUi/Core/Core.h
CRMLUI_API void rmlShutdown(void);

/// Sets the interface through which all file I/O requests are made. This is not required to be called, but if it is, it
/// must be called before Initialise().
///
/// The C-API to use for this function is rmlFileInterface_new.
///
/// @param[in] file_interface A non-owning pointer to the application-specified file interface.
/// @lifetime The interface must be kept alive until after the call to Rml::Shutdown.
CRMLUI_API void rmlSetFileInterface(RmlFileInterface* file_interface);

/// Fetches a context by index.
/// @param[in] index The index of the desired context. If this is outside the valid range of contexts, it will be clamped.
/// @return The requested context, or nullptr if no contexts exist.
CRMLUI_API RmlContext* rmlGetContext(int index);

/// Returns the number of active contexts.
/// @return The total number of active RmlUi contexts.
CRMLUI_API int rmlGetNumContexts();

/// Creates a new element context.
/// @param[in] name_ptr The new name of the context. This must be unique.
/// @param[in] name_len The length of the name ptr given.
/// @param[in] width The width dimension of the new context.
/// @param[in] height The height dimension of the new context.
/// @param[in] render_interface The custom render interface to use, or nullptr to use the default.
/// @param[in] text_input_handler The custom text input handler to use, or nullptr to use the default.
/// @lifetime If specified, the render interface and the text input handler must be kept alive until after the call to
///           Rml::Shutdown. Alternatively, the render interface can be destroyed after all contexts it belongs to have been
///           destroyed, and a subsequent call has been made to Rml::ReleaseRenderManagers.
/// @return A non-owning pointer to the new context, or nullptr if the context could not be created.
CRMLUI_API RmlContext* rmlCreateContext(CRMLUI_IN_BYTECAP(name_len) const char* name_ptr, unsigned int name_len, int width, int height, RmlRenderInterface* render_interface /* = nullptr*/, RmlTextInputHandler* text_input_handler/* = nullptr */);

// Removes and destroys a context.
// @param[in] name The name of the context to remove.
// @return True if name is a valid context, false otherwise.
CRMLUI_API bool rmlRemoveContext(const char* name_ptr, unsigned int name_len);

/// Load a document into the context.
///
/// @return The loaded document, or nullptr if no document was loaded.
CRMLUI_API RmlElementDocument* rmlContext_LoadDocument(RmlContext* context, const char* filename_ptr, unsigned int filename_len);

/// Load a document into the context from memory.
///
/// @return The loaded document, or nullptr if no document was loaded.
CRMLUI_API RmlElementDocument* rmlContext_LoadDocumentFromMemory(RmlContext* context, const char* rml_data_ptr, size_t rml_data_len, const char* filename_ptr, unsigned int filename_len);

/// Updates all elements in the context's documents.
/// This must be called before Context::Render, but after any elements have been changed, added, or removed.
CRMLUI_API bool rmlContext_Update(RmlContext* context);

CRMLUI_API const char* rmlContext_GetName(RmlContext* context);

/// Changes the ratio of the 'dp' unit to the 'px' unit.
/// @param[in] dp_ratio The new density-independent pixel ratio of the context.
CRMLUI_API void rmlContext_SetDensityIndependentPixelRatio(RmlContext* context, float dp_ratio);

/// Sends a mousescroll event into this context, and scrolls the document unless the event was stopped from propagating.
/// @param[in] wheel_delta The mouse-wheel movement this frame, with positive values being directed right and down.
/// @param[in] key_modifier_state The state of key modifiers (shift, control, caps-lock, etc.) keys; this should be generated by ORing together
/// members of the Input::KeyModifier enumeration.
/// @return True if the event was not consumed (ie, was prevented from propagating by an element), false if it was.
CRMLUI_API bool rmlContext_ProcessMouseWheel(RmlContext* context, float wheel_delta_x, float wheel_delta_y, int key_modifier_state);

/// Sends a mouse movement event into this context.
/// @param[in] x The x-coordinate of the mouse cursor, in window-coordinates (ie, 0 should be the left of the client area).
/// @param[in] y The y-coordinate of the mouse cursor, in window-coordinates (ie, 0 should be the top of the client area).
/// @param[in] key_modifier_state The state of key modifiers (shift, control, caps-lock, etc.) keys; this should be generated by ORing together
/// members of the Input::KeyModifier enumeration.
/// @return True if the mouse is not interacting with any elements in the context (see 'IsMouseInteracting'), otherwise false.
CRMLUI_API bool rmlContext_ProcessMouseMove(RmlContext* context, int x, int y, int key_modifier_state);

/// Renders all visible elements in the context's documents.
///
/// Call between Backend::BeginFrame and Backend::EndFrame.
/// Backend::BeginFrame for SDL example:
///    SDL_SetRenderDrawColor(data->renderer, 0, 0, 0, 0);
///    SDL_RenderClear(data->renderer);
///    render_interface.BeginFrame()
///
/// Backend::EndFrame for SDL example:
///    render_interface.EndFrame();
///    SDL_RenderPresent(data->renderer);
CRMLUI_API bool rmlContext_Render(RmlContext* context);

/// Creates a data model.
/// The returned constructor can be used to bind data variables. Elements can bind to the model using the attribute 'data-model="name"'.
/// @param[in] name The name of the data model.
/// @param[in] data_type_register The data type register to use for the data model, or null to use the default register.
/// @return A constructor for the data model, or empty if it could not be created.
CRMLUI_API void rmlContext_CreateDataModel(RmlContext* context, const char* name_ptr, size_t name_len, RmlDataTypeRegister* data_type_register /* = null*/, RmlDataModelConstructor* data_model_constructor_result);

/// Get the max delay until Update() and Render() should get called again. An application can choose to only call
/// update and render once the time has elapsed, but there's no harm in doing so more often. The returned value can
/// be infinity, in which case Update() should be invoked after user input was received. A value of 0 means "render
/// as fast as possible", for example if an animation is playing.
/// @return Time until the next update is expected.
CRMLUI_API double rmlContext_GetNextUpdateDelay(const RmlContext* context);

/// Show the document.
///
/// @param[in] document this parameter 
/// @param[in] modal_flag Flags controlling the modal state of the document, see the 'ModalFlag' description for details.
/// @param[in] focus_flag Flags controlling the focus, see the 'FocusFlag' description for details.
CRMLUI_API void rmlElementDocument_Show(RmlElementDocument* document, RmlModalFlag modal_flag /* = ModalFlag::None*/, RmlFocusFlag focus_flag /* = FocusFlag::Auto*/);

/// Reload the document's style sheet from source files.
/// Styles will be reloaded from <style> tags and external style sheets, but not inline 'style' attributes.
/// @note The source url originally used to load the document must still be a valid RML document.
CRMLUI_API void rmlElementDocument_ReloadStyleSheet(RmlElementDocument* document);

/// Adds a new font face to the font engine. The face's family, style, and weight will be determined from the face itself.
/// @param[in] file_path The path to the file to load the face from. The path is passed directly to the file interface which is used to load the file.
/// The default file interface accepts both absolute paths and paths relative to the working directory.
/// @param[in] fallback_face True to use this font face for unknown characters in other font faces.
/// @param[in] weight The weight to load when the font face contains multiple weights, otherwise the weight to register the font as. By default, it
/// loads all found font weights.
/// @param[in] face_index The index of the font face within a font collection.
/// @return True if the face was loaded successfully, false otherwise.
CRMLUI_API bool rmlLoadFontFace(const char* file_path_ptr, size_t file_path_len, RmlFontWeight weight /* = Style::FontWeight::Auto*/, bool fallback_face /* = false */, int face_index /*= 0*/);

/// Adds a new font face from memory to the font engine. The face's family, style, and weight are given by the parameters.
/// @param[in] data The font data.
/// @param[in] family The family to register the font as.
/// @param[in] style The style to register the font as.
/// @param[in] weight The weight to load when the font face contains multiple weights, otherwise the weight to register the font as. By default, it
/// loads all found font weights.
/// @param[in] fallback_face True to use this font face for unknown characters in other font faces.
/// @param[in] face_index The index of the font face within a font collection.
/// @return True if the face was loaded successfully, false otherwise.
/// @lifetime The pointed to 'data' must remain available until after the call to Rml::Shutdown.
CRMLUI_API bool rmlLoadFontFaceFromMemory(const unsigned char* data_ptr, size_t data_len, const char *font_family_ptr, uint16_t font_family_len, RmlFontStyle style, RmlFontWeight weight, bool fallback_face, int face_index);

CRMLUI_API bool rmlDataModelConstructor_BindCustomDataVariable(RmlDataModelConstructor* dmc, const char* name_ptr, size_t name_len, RmlDataVariable data_variable);

// NOTE(jae): 2026-02-01
// Not exposed in Include, but you can use DataModelConstructor_BindCustomDataVariable
// CRMLUI_API bool rmlDataModel_BindVariable(RmlDataModel* data_model, const char* name_ptr, size_t name_len, RmlDataVariable variable);

CRMLUI_API RmlDataModelHandle rmlDataModelConstructor_GetModelHandle(RmlDataModelConstructor* dmc) {
    RmlDataModelHandle handle;
    handle.private_fields.model = dmc->private_fields.model;
	return handle;
}

CRMLUI_API bool rmlDataModelHandle_IsVariableDirty(const RmlDataModelHandle* handle, const char* variable_name_ptr, size_t variable_name_len);
CRMLUI_API void rmlDataModelHandle_DirtyVariable(const RmlDataModelHandle* handle, const char* variable_name_ptr, size_t variable_name_len);
CRMLUI_API void rmlDataModelHandle_DirtyAllVariables(const RmlDataModelHandle* handle);

CRMLUI_API RmlDataVariable rmlDataVariable_init(RmlVariableDefinition* definition, void* ptr)
{
    RmlDataVariable dv;
    dv.private_fields.definition = definition;
	dv.private_fields.ptr = ptr;
    return dv;
}


CRMLUI_API bool rmlDataTypeRegister_RegisterDefinition(RmlDataTypeRegister* dtr, RmlFamilyId id, RmlVariableDefinition* definition);

/**
 * This is a C-API only function, as C does not have templates/generics
 */
CRMLUI_API RmlVariableDefinition* rmlDataTypeRegister_GetDefinitionById(RmlDataTypeRegister* dtr, RmlFamilyId id);

/**
 * Variable Definitions
 */

CRMLUI_API RmlVariableDefinition* rmlScalarDefinition_create(RmlVariantType variant_type);
CRMLUI_API RmlVariableDefinition* rmlFixedStringScalarDefinition_create(void);
CRMLUI_API RmlVariableDefinition* rmlConstStringPtrLen_Definition_create(uint8_t data_offset, uint8_t len_offset); /** Assumes a struct with a ptr and size_t length */

/**
 * File System Interface
 */
typedef RmlFileHandle (*RmlFileInterfaceOpen)(const char* path_ptr, unsigned int path_len, void* userdata);
typedef void (*RmlFileInterfaceClose)(RmlFileHandle file, void* userdata);
typedef size_t (*RmlFileInterfaceRead)(char* buffer, size_t size, RmlFileHandle file, void* userdata);
typedef bool (*RmlFileInterfaceSeek)(RmlFileHandle file, long offset, int origin, void* userdata);
typedef size_t (*RmlFileInterfaceTell)(RmlFileHandle file, void* userdata);
typedef struct RmlFileInterfaceVTable RmlFileInterfaceVTable;
struct RmlFileInterfaceVTable {
    void* userdata;
    RmlFileInterfaceOpen open;
    RmlFileInterfaceClose close;
    RmlFileInterfaceRead read;
    RmlFileInterfaceSeek seek;
    RmlFileInterfaceTell tell;
};

CRMLUI_API RmlFileInterface* rmlFileInterface_new(const RmlFileInterfaceVTable* file_interface);

#endif

/**
 * Debugger
 */
#if CRMLUI_HAS_DEBUGGER

/// Initialises the debug plugin. The debugger will be loaded into the given context.
/// @param[in] host_context RmlUi context to load the debugger into. The debugging tools will be displayed on this context. If this context is
///     destroyed, the debugger will be released.
/// @return True if the debugger was successfully initialised
CRMLUI_API bool rmlDebuggerInitialise(RmlContext* context);
CRMLUI_API void rmlDebuggerSetVisible(bool is_visible);
CRMLUI_API bool rmlDebuggerIsVisible(void);

#endif

/**
 * SDL Platform and Renderer
 */

#if defined(CRMLUI_DEFINE_ENUMS_AND_STRUCTS) && CRMLUI_HAS_SDL_BACKEND
typedef struct SystemInterface_SDL SystemInterface_SDL;
typedef struct RenderInterface_SDL RenderInterface_SDL;
struct SystemInterface_SDL;
struct RenderInterface_SDL;

#ifndef SDL_VERSION_MAJOR
typedef struct SDL_Renderer SDL_Renderer;
typedef struct SDL_Window SDL_Window;
typedef struct SDL_Event SDL_Event;
struct SDL_Renderer;
struct SDL_Window;
struct SDL_Event;
#endif

#endif

#if CRMLUI_HAS_SDL_BACKEND
CRMLUI_API SystemInterface_SDL* rmlSystemInterface_SDL_new(void);
CRMLUI_API void rmlSystemInterface_SDL_SetWindow(SystemInterface_SDL* system_interface, SDL_Window* window);
CRMLUI_API void rmlSystemInterface_SDL_free(SystemInterface_SDL* system_interface);
CRMLUI_API RenderInterface_SDL* rmlRenderInterface_SDL_new(SDL_Renderer* renderer);
CRMLUI_API void rmlRenderInterface_SDL_free(RenderInterface_SDL* render_interface);
CRMLUI_API bool rmlInputEventHandler_SDL(RmlContext* context, SDL_Window* window, SDL_Event *event);
/// Call SDL_SetRenderDrawColor and SDL_RenderClear before this
CRMLUI_API void rmlRenderInterface_SDL_BeginFrame(RenderInterface_SDL* render_interface);
/// Call SDL_RenderPresent after this
CRMLUI_API void rmlRenderInterface_SDL_EndFrame(RenderInterface_SDL* render_interface);
#endif

#endif
