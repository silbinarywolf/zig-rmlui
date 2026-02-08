
// Override C++ behaviour so "private" fields are public so that we
// can statically assert with offsetof() if our C-struct matches
#define private public
#include <RmlUi/Core/DataVariable.h>
#include <RmlUi/Core/DataModelHandle.h>
#undef private

#include <RmlUi/Core.h>
#include <RmlUi/Debugger.h>

#include <RmlUi/Core/StreamMemory.h>

#if RMLUI_SDL_VERSION_MAJOR == 2 || RMLUI_SDL_VERSION_MAJOR == 3
#include <RmlUi_Backend.h>
#include "RmlUi_Platform_SDL.h"
#include "RmlUi_Renderer_SDL.h"

#ifndef CRMLUI_HAS_SDL_BACKEND
#define CRMLUI_HAS_SDL_BACKEND 1
#endif

#endif

#define CRMLUI_ASSERT RMLUI_ASSERT

// IMGUI_API void*         MemAlloc(size_t size);
// IMGUI_API void          MemFree(void* ptr);
#define CRMLUI_NEW(_TYPE)                       new(_TYPE)
template<typename T> void CRMLUI_DELETE(T* p)   { if (p) { delete(p); } }

/**
 * ```c
 * CRMLUI_COMPILE_TIME_ASSERT(uint32_size, sizeof(Uint32) == 4);
 * ```
 *
 * \param name a unique identifier for this assertion.
 * \param x the value to test. Must be a boolean value.
 */
#ifndef CRMLUI_COMPILE_TIME_ASSERT
#if defined(__cplusplus)
/* Keep C++ case alone: Some versions of gcc will define __STDC_VERSION__ even when compiling in C++ mode. */
#if (__cplusplus >= 201103L)
#define CRMLUI_COMPILE_TIME_ASSERT(name, x)  static_assert(x, #x)
#endif
#elif defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 202311L)
#define CRMLUI_COMPILE_TIME_ASSERT(name, x)  static_assert(x, #x)
#elif defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 201112L)
#define CRMLUI_COMPILE_TIME_ASSERT(name, x) _Static_assert(x, #x)
#endif
#endif /* !CRMLUI_COMPILE_TIME_ASSERT */

#ifndef CRMLUI_COMPILE_TIME_ASSERT
/* universal, but may trigger -Wunused-local-typedefs */
#define CRMLUI_COMPILE_TIME_ASSERT(name, x) typedef int SDL_compile_time_assert_ ## name[(x) * 2 - 1]
#endif

#define CRMLUI_COMPILE_TIME_ASSERT_OFFSETOF_MATCH(field_name, cpp_class, c_struct) \
    CRMLUI_COMPILE_TIME_ASSERT(c_struct ## _field_ ## field_name, offsetof(cpp_class, field_name) == offsetof(c_struct, field_name))

#include "crmlui.h"

#if CRMLUI_HAS_CORE

CRMLUI_API void rmlSetSystemInterface(RmlSystemInterface* _system_interface)
{
    return Rml::SetSystemInterface(_system_interface);
}

CRMLUI_API void rmlSetRenderInterface(RmlRenderInterface* _render_interface)
{
    return Rml::SetRenderInterface(_render_interface);
}

CRMLUI_API bool rmlInitialise(void)
{
    return Rml::Initialise();
}

CRMLUI_API void rmlShutdown(void)
{
    return Rml::Shutdown();
}

CRMLUI_API void rmlSetFileInterface(RmlFileInterface* file_interface)
{
	return Rml::SetFileInterface(file_interface);
}

CRMLUI_API RmlContext* rmlGetContext(int index)
{
	return Rml::GetContext(index);
}

CRMLUI_API int rmlGetNumContexts()
{
	return Rml::GetNumContexts();
}

CRMLUI_API RmlContext* rmlCreateContext(const char* name_ptr, unsigned int name_len, int width, int height, RmlRenderInterface* render_interface, RmlTextInputHandler* text_input_handler)
{
    return Rml::CreateContext(Rml::String{name_ptr, name_len}, Rml::Vector2i(width, height), render_interface, text_input_handler);
}

CRMLUI_API bool rmlRemoveContext(const char* name_ptr, unsigned int name_len)
{
	return Rml::RemoveContext(Rml::String{name_ptr, name_len});
}

CRMLUI_API RmlElementDocument* rmlContext_LoadDocument(RmlContext* context, const char* filename_ptr, unsigned int filename_len)
{
	return context->LoadDocument(Rml::String{filename_ptr, filename_len});
}

CRMLUI_API const char* rmlContext_GetName(RmlContext* context)
{
	return context->GetName().c_str();
}

CRMLUI_API RmlElementDocument* rmlContext_LoadDocumentFromMemory(RmlContext* context, const char* rml_data_ptr, size_t rml_data_len, const char* filename_ptr, unsigned int filename_len)
{
    // Open the stream based on the string contents.
	auto stream = Rml::MakeUnique<Rml::StreamMemory>(reinterpret_cast<const Rml::byte*>(rml_data_ptr), rml_data_len);

	stream->SetSourceURL(Rml::String{filename_ptr, filename_len});

	// Load the document from the stream.
	RmlElementDocument* document = context->LoadDocument(stream.get());

	return document;
}

CRMLUI_API bool rmlContext_Update(RmlContext* context)
{
	return context->Update();
}

CRMLUI_API bool rmlContext_Render(RmlContext* context)
{
	return context->Render();
}

CRMLUI_API void rmlContext_SetDensityIndependentPixelRatio(RmlContext* context, float dp_ratio)
{
	return context->SetDensityIndependentPixelRatio(dp_ratio);
}

CRMLUI_API bool rmlContext_ProcessMouseWheel(RmlContext* context, float wheel_delta_x, float wheel_delta_y, int key_modifier_state)
{
	return context->ProcessMouseWheel(Rml::Vector2f(wheel_delta_x, wheel_delta_y), key_modifier_state);
}

CRMLUI_API bool rmlContext_ProcessMouseMove(RmlContext* context, int x, int y, int key_modifier_state)
{
	return context->ProcessMouseMove(x, y, key_modifier_state);
}

CRMLUI_API double rmlContext_GetNextUpdateDelay(const RmlContext* context) {
	return context->GetNextUpdateDelay();
}

CRMLUI_API void rmlContext_CreateDataModel(RmlContext* context, const char* name_ptr, size_t name_len, RmlDataTypeRegister* data_type_register /* = null*/, RmlDataModelConstructor* dmc_result)
{
	CRMLUI_ASSERT(dmc_result);
	Rml::DataModelConstructor dmc = context->CreateDataModel(Rml::String{name_ptr, name_len}, data_type_register);
	dmc_result->private_fields.model = dmc.model;
	dmc_result->private_fields.type_register = dmc.type_register;
}

CRMLUI_API void rmlElementDocument_Show(RmlElementDocument* document, RmlModalFlag modal_flag /* = ModalFlag::None*/, RmlFocusFlag focus_flag /* = FocusFlag::Auto*/)
{
	return document->Show(static_cast<Rml::ModalFlag>(modal_flag), static_cast<Rml::FocusFlag>(focus_flag));
}

CRMLUI_API void rmlElementDocument_ReloadStyleSheet(RmlElementDocument* document)
{
	return document->ReloadStyleSheet();
}

CRMLUI_API bool rmlLoadFontFace(const char* file_path_ptr, size_t file_path_len, RmlFontWeight weight /* = Style::FontWeight::Auto*/, bool fallback_face /* = false */, int face_index /*= 0*/)
{
	return Rml::LoadFontFace(Rml::String{file_path_ptr, file_path_len}, fallback_face, static_cast<Rml::Style::FontWeight>(weight), face_index);
}

CRMLUI_API bool rmlLoadFontFaceFromMemory(const unsigned char* data_ptr, size_t data_len, const char *font_family_ptr, uint16_t font_family_len, RmlFontStyle style, RmlFontWeight weight, bool fallback_face, int face_index)
{   
    return Rml::LoadFontFace(Rml::Span<const Rml::byte>{data_ptr, data_len}, Rml::String{font_family_ptr, font_family_len}, static_cast<Rml::Style::FontStyle>(style), static_cast<Rml::Style::FontWeight>(weight), fallback_face, face_index);
}

CRMLUI_API bool rmlDataModelConstructor_BindCustomDataVariable(RmlDataModelConstructor* dmc, const char* name_ptr, size_t name_len, RmlDataVariable data_variable)
{
	Rml::DataModelConstructor* _dmc = reinterpret_cast<Rml::DataModelConstructor*>(dmc);
	return _dmc->BindCustomDataVariable(Rml::String{name_ptr, name_len}, Rml::DataVariable(data_variable.private_fields.definition, data_variable.private_fields.ptr));
}

CRMLUI_API bool rmlDataTypeRegister_RegisterDefinition(RmlDataTypeRegister* dtr, RmlFamilyId id, RmlVariableDefinition* definition)
{
	return dtr->RegisterDefinition(id, Rml::UniquePtr<Rml::VariableDefinition>(definition));
}

CRMLUI_API RmlVariableDefinition* rmlDataTypeRegister_GetDefinitionById(RmlDataTypeRegister* dtr, RmlFamilyId id)
{
	auto it = dtr->type_register.find(id);
	if (it == dtr->type_register.end()) {
		return nullptr;
	}
	return it->second.get();
}

CRMLUI_API bool rmlDataModelHandle_IsVariableDirty(const RmlDataModelHandle *handle, const char* variable_name_ptr, size_t variable_name_len)
{
	Rml::DataModelHandle dmh;
	dmh.model = handle->private_fields.model;
	return dmh.IsVariableDirty(Rml::String{variable_name_ptr, variable_name_len});
}

CRMLUI_API void rmlDataModelHandle_DirtyVariable(const RmlDataModelHandle *handle, const char* variable_name_ptr, size_t variable_name_len)
{
	Rml::DataModelHandle dmh;
	dmh.model = handle->private_fields.model;
	return dmh.DirtyVariable(Rml::String{variable_name_ptr, variable_name_len});
}

CRMLUI_API void rmlDataModelHandle_DirtyAllVariables(const RmlDataModelHandle *handle)
{
	Rml::DataModelHandle dmh;
	dmh.model = handle->private_fields.model;
	return dmh.DirtyAllVariables();
}

/**
 * Handle creation of ScalarDefinition types without generics
 */
CRMLUI_API RmlVariableDefinition* rmlScalarDefinition_create(RmlVariantType variant_type)
{
	switch (variant_type) {
	case RmlVariantType_Bool:   return CRMLUI_NEW(Rml::ScalarDefinition<bool>)();
	case RmlVariantType_Byte:   return CRMLUI_NEW(Rml::ScalarDefinition<Rml::byte>)();
	case RmlVariantType_Char:   return CRMLUI_NEW(Rml::ScalarDefinition<char>)();
	case RmlVariantType_Int:    return CRMLUI_NEW(Rml::ScalarDefinition<int>)();
	case RmlVariantType_Int64:  return CRMLUI_NEW(Rml::ScalarDefinition<int64_t>)();
	case RmlVariantType_Uint:   return CRMLUI_NEW(Rml::ScalarDefinition<unsigned int>)();
	case RmlVariantType_Uint64: return CRMLUI_NEW(Rml::ScalarDefinition<uint64_t>)();
	case RmlVariantType_Float:  return CRMLUI_NEW(Rml::ScalarDefinition<float>)();
	case RmlVariantType_Double: return CRMLUI_NEW(Rml::ScalarDefinition<double>)();
	default:                    CRMLUI_ASSERT(false); return nullptr;
	}
}

class CRmluiFixedStringScalarDefinition final : public Rml::VariableDefinition {
public:
	CRmluiFixedStringScalarDefinition() : VariableDefinition(Rml::DataVariableType::Scalar) {}

	bool Get(void* ptr, Rml::Variant& variant) override
	{
		const CRmlFixedStringShape* fixed_string = static_cast<const CRmlFixedStringShape*>(ptr);
		const char* str_ptr = &fixed_string->buf_start[0];
		variant = Rml::String{str_ptr, fixed_string->header.len};
		return true;
	}

	bool Set(void* ptr, const Rml::Variant& variant) override {
		CRmlFixedStringShape* fixed_string = static_cast<CRmlFixedStringShape*>(ptr);
		const Rml::String& value = variant.Get<Rml::String>();
		size_t new_size = value.size();
		if (new_size >= fixed_string->header.capacity) {
			// If too large to fit in fixed string
			return false;
		}
		fixed_string->header.len = new_size;
		char* str_ptr = &fixed_string->buf_start[0];
		memcpy(str_ptr, value.c_str(), new_size);
		return true;
	}
};

CRMLUI_API RmlVariableDefinition* rmlFixedStringScalarDefinition_create()
{
	return CRMLUI_NEW(CRmluiFixedStringScalarDefinition)();
}

class CRmlConstStringPtrLen_Definition_create final : public Rml::VariableDefinition {
public:
	CRmlConstStringPtrLen_Definition_create(uint8_t data_offset, uint8_t len_offset) : data_offset(data_offset), len_offset(len_offset), VariableDefinition(Rml::DataVariableType::Scalar) {}

	bool Get(void* ptr_to_slice, Rml::Variant& variant) override
	{
		const char *raw_ptr = static_cast<const char*>(ptr_to_slice);
		const char* data = *(const char**)(raw_ptr + data_offset);
		size_t len = *(const size_t*)(raw_ptr + len_offset);
		variant = Rml::String{data, len};
		return true;
	}

	bool Set(void* ptr, const Rml::Variant& variant) override {
		return false;
	}
private:
	uint8_t data_offset;
	uint8_t len_offset;
};

CRMLUI_API RmlVariableDefinition* rmlConstStringPtrLen_Definition_create(uint8_t data_offset, uint8_t len_offset)
{
	return CRMLUI_NEW(CRmlConstStringPtrLen_Definition_create)(data_offset, len_offset);
}

/*
 * Handle File system operations with a C v-table
 */
class CRmluiFileInterface : public Rml::FileInterface {
public:
	CRmluiFileInterface(const RmlFileInterfaceVTable *vtable);
	virtual ~CRmluiFileInterface();

	/// Opens a file.
	RmlFileHandle Open(const Rml::String& path) override;

	/// Closes a previously opened file.
	void Close(RmlFileHandle file) override;

	/// Reads data from a previously opened file.
	size_t Read(void* buffer, size_t size, RmlFileHandle file) override;

	/// Seeks to a point in a previously opened file.
	bool Seek(RmlFileHandle file, long offset, int origin) override;

	/// Returns the current position of the file pointer.
	size_t Tell(RmlFileHandle file) override;
private:
    RmlFileInterfaceVTable vtable;
};

CRmluiFileInterface::CRmluiFileInterface(const RmlFileInterfaceVTable *vtable) : vtable(*vtable) {}
CRmluiFileInterface::~CRmluiFileInterface() {}

RmlFileHandle CRmluiFileInterface::Open(const Rml::String& path)
{
	return vtable.open(path.c_str(), path.length(), vtable.userdata);
}

void CRmluiFileInterface::Close(RmlFileHandle file)
{
	return vtable.close(file, vtable.userdata);
}

/// amount_to_read is ~4092 for the StyleSheetParser in RmlUi 6.x.x
size_t CRmluiFileInterface::Read(void* buffer, size_t amount_to_read, RmlFileHandle file)
{
	return vtable.read(static_cast<char*>(buffer), amount_to_read, file, vtable.userdata);
}

bool CRmluiFileInterface::Seek(RmlFileHandle file, long offset, int origin)
{
	return vtable.seek(file, offset, origin, vtable.userdata);
}

size_t CRmluiFileInterface::Tell(RmlFileHandle file)
{
	return vtable.tell(file, vtable.userdata);
}

CRMLUI_API RmlFileInterface* rmlFileInterface_new(const RmlFileInterfaceVTable* file_interface_vtable)
{
    return CRMLUI_NEW(CRmluiFileInterface)(file_interface_vtable);
}

#endif /* CRMLUI_HAS_CORE */

/*
 * Handle Debugger
 */
#if CRMLUI_HAS_DEBUGGER
CRMLUI_API bool rmlDebuggerInitialise(RmlContext* context)
{
    return Rml::Debugger::Initialise(context);
}

CRMLUI_API void rmlDebuggerSetVisible(bool is_visible)
{
    return Rml::Debugger::SetVisible(is_visible);
}

CRMLUI_API bool rmlDebuggerIsVisible(void)
{
    return Rml::Debugger::IsVisible();
}
#endif /* CRMLUI_HAS_DEBUGGER */

/*
 * Handle SDL platform or renderer backend
 */
#if CRMLUI_HAS_SDL_BACKEND

CRMLUI_API SystemInterface_SDL* rmlSystemInterface_SDL_new()
{
    return CRMLUI_NEW(SystemInterface_SDL)();
}

CRMLUI_API void rmlSystemInterface_SDL_SetWindow(SystemInterface_SDL* system_interface, SDL_Window* window)
{
	return system_interface->SetWindow(window);
}

CRMLUI_API void rmlSystemInterface_SDL_free(SystemInterface_SDL* system_interface)
{
    return CRMLUI_DELETE(system_interface);
}

CRMLUI_API RenderInterface_SDL* rmlRenderInterface_SDL_new(SDL_Renderer* renderer)
{
    return CRMLUI_NEW(RenderInterface_SDL)(renderer);
}

CRMLUI_API void rmlRenderInterface_SDL_free(RenderInterface_SDL* render_interface)
{
    return CRMLUI_DELETE(render_interface);
}

CRMLUI_API bool rmlInputEventHandler_SDL(RmlContext* context, SDL_Window* window, SDL_Event *event)
{
    SDL_Event ev  = *event;
    return RmlSDL::InputEventHandler(context, window, ev);
}

CRMLUI_API void rmlRenderInterface_SDL_BeginFrame(RenderInterface_SDL* render_interface)
{
	return render_interface->BeginFrame();
}

CRMLUI_API void rmlRenderInterface_SDL_EndFrame(RenderInterface_SDL* render_interface)
{
	return render_interface->EndFrame();
}

#endif /* CRMLUI_HAS_SDL_BACKEND */
