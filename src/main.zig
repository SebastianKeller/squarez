const std = @import("std");
const c = @import("c.zig");

const assert = std.debug.assert;
const panic = std.debug.panic;

const grid_png_data = @embedFile("../assets/grid.png");
const font_bmp_data = @embedFile("../assets/font.bmp");

pub fn main() anyerror!void {
    if (!(c.SDL_SetHintWithPriority(c.SDL_HINT_NO_SIGNAL_HANDLERS, "1", c.SDL_HintPriority.SDL_HINT_OVERRIDE) != c.SDL_bool.SDL_FALSE)) {
        panic("failed to disable sdl signal handlers\n", .{});
    }

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        panic("SDL_Init failed: {c}\n", .{c.SDL_GetError()});
    }
    defer c.SDL_Quit();

    const screen = c.SDL_CreateWindow(
        "squarez",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        400,
        400,
        0,
    ) orelse {
        panic("SDL_CreateWindow failed: {c}\n", .{c.SDL_GetError()});
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer = c.SDL_CreateRenderer(screen, -1, 0) orelse {
        panic("SDL_CreateRenderer failed: {c}\n", .{c.SDL_GetError()});
    };
    defer c.SDL_DestroyRenderer(renderer);

    const grid_texture = createTextureFromData(grid_png_data, renderer);
    const font_texture = createTextureFromData(font_bmp_data, renderer);

    var board = Board.create();
    board.setValue(4, 4, 5);

    var player = Point{ .x = 4, .y = 4 };

    while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                c.SDL_QUIT => return,
                else => {},
            }
        }

        drawBackground(renderer, grid_texture);
        drawNumbers(renderer, board, font_texture);

        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(17 - (c.SDL_GetTicks() % 17));
    }
}

fn drawNumbers(renderer: *c.SDL_Renderer, board: Board, font: *c.SDL_Texture) void {
    var x: usize = 0;
    while (x < 9) {
        var y: usize = 0;
        while (y < 9) {
            var value = board.getValue(x, y);
            if (value) |v| {
                var idx: i32 = v + 16; // font map starts with space

                // 95 characters, ascii sorted
                if (idx < 0 or idx > 94)
                    continue;

                const src_rect = c.SDL_Rect{
                    .x = 18 * idx,
                    .y = 0,
                    .w = 18,
                    .h = 36,
                };

                const dst_rect = c.SDL_Rect{
                    .x = 20 + @intCast(i32, x) * 40 + (40 - 18) / 2,
                    .y = 20 + @intCast(i32, y) * 40 + (40 - 36) / 2,
                    .w = 18,
                    .h = 36,
                };

                c.assertZero(c.SDL_RenderCopy(renderer, font, &src_rect, &dst_rect));
            }

            y = y + 1;
        }

        x = x + 1;
    }
}

fn drawBackground(renderer: *c.SDL_Renderer, texture: *c.SDL_Texture) void {
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    c.assertZero(c.SDL_RenderClear(renderer));

    const src_rect = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = 360,
        .h = 360,
    };

    const dst_rect = c.SDL_Rect{
        .x = 20,
        .y = 20,
        .w = 360,
        .h = 360,
    };
    c.assertZero(c.SDL_RenderCopy(renderer, texture, &src_rect, &dst_rect));
}

fn createTextureFromData(data: var, renderer: *c.SDL_Renderer) *c.SDL_Texture {
    const rwops = c.SDL_RWFromConstMem(data, data.len).?;
    const surface = c.IMG_Load_RW(rwops, 0) orelse panic("unable to load image", .{});
    const texture = c.SDL_CreateTextureFromSurface(renderer, surface) orelse panic("unable to create texture", .{});
    return texture;
}

const Board = struct {
    values: [81]?u8,

    const Self = @This();

    pub fn getValue(self: Self, x: usize, y: usize) ?u8 {
        return self.values[y * 9 + x];
    }

    pub fn setValue(self: *Self, x: usize, y: usize, value: ?u8) void {
        self.values[y * 9 + x] = value;
    }

    fn create() Board {
        return Board{
            .values = [_]?u8{null} ** 81,
        };
    }
};

const Point = struct {
    x: u8,
    y: u8,
};
