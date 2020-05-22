pub usingnamespace @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_image.h");
});

const std = @import("std");

pub fn assertZero(ret: c_int) void {
    if (ret == 0) return;
    std.debug.panic("sdl function returned an error: {c}", .{SDL_GetError()});
}
