/**
 * A hack provided by Zig Rmlui that makes the Backends/RmlUi_Renderer_SDL.cpp backend
 * fallback to SDL_LoadPNG_IO instead of using SDL_image
 */
#ifndef ZIG_RMLUI_SDL_IMAGE_WORKAROUND_CORE_H_
#define ZIG_RMLUI_SDL_IMAGE_WORKAROUND_CORE_H_

#include <SDL3/SDL.h>
#include <SDL3/SDL_begin_code.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Load an image from an SDL datasource, optionally specifying the type (type = "PNG", "BMP", "GIF" ) */
SDL_DECLSPEC SDL_Surface * SDLCALL IMG_LoadTyped_IO(SDL_IOStream *src, bool closeio, const char* type) {
    return SDL_LoadPNG_IO(src, true);
}

#ifdef __cplusplus
}
#endif

#endif /* ZIG_RMLUI_SDL_IMAGE_WORKAROUND_CORE_H_ */
