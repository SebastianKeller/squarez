const std = @import("std");
const c = @import("c.zig");
const assert = std.debug.assert;
const panic = std.debug.panic;

const grid_png_data = @embedFile("../assets/grid.png");
const font_bmp_data = @embedFile("../assets/font.bmp");
const player_png_data = @embedFile("../assets/player.png");

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
    const player_texture = createTextureFromData(player_png_data, renderer);

    var state = Gamestate{
        .board = Board.create(),
        .position = Point{ .x = 4, .y = 4 },
    };

    mainLoop: while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                c.SDL_QUIT => return,
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.sym) {
                        c.SDLK_LEFT => state.movePosition(.Left),
                        c.SDLK_RIGHT => state.movePosition(.Right),
                        c.SDLK_UP => state.movePosition(.Up),
                        c.SDLK_DOWN => state.movePosition(.Down),
                        '1'...'9' => state.setValue(@intCast(u8, event.key.keysym.sym - '0')),
                        'x' => state.setValue(null),
                        'q' => break :mainLoop,
                        else => {},
                    }
                },
                c.SDL_MOUSEBUTTONDOWN => {
                    if (event.button.button == c.SDL_BUTTON_LEFT) {
                        const x = @divFloor((@intCast(u32, event.button.x) - 20), 40);
                        const y = @divFloor((@intCast(u32, event.button.y) - 20), 40);

                        if (x >= 0 and x <= 8 and y >= 0 and y <= 8) {
                            state.setPosition(x, y);
                        }
                    }
                },
                else => {},
            }
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
        c.assertZero(c.SDL_RenderClear(renderer));

        drawPlayerPosition(renderer, &state, player_texture);
        drawBackground(renderer, grid_texture);
        drawNumbers(renderer, &state, font_texture);

        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(17 - (c.SDL_GetTicks() % 17));
    }
}

fn drawPlayerPosition(
    renderer: *c.SDL_Renderer,
    state: *Gamestate,
    texture: *c.SDL_Texture,
) void {
    const src = c.SDL_Rect{
        .x = 0,
        .y = 0,
        .w = 40,
        .h = 40,
    };
    const dst = c.SDL_Rect{
        .x = @intCast(c_int, 20 + state.position.x * 40),
        .y = @intCast(c_int, 20 + state.position.y * 40),
        .w = 40,
        .h = 40,
    };

    c.assertZero(c.SDL_RenderCopy(renderer, texture, &src, &dst));
}

fn drawNumbers(renderer: *c.SDL_Renderer, state: *Gamestate, font: *c.SDL_Texture) void {
    var x: u32 = 0;
    while (x < 9) {
        var y: u32 = 0;
        while (y < 9) {
            var value = state.getValue(x, y);
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

const Gamestate = struct {
    board: Board,
    position: Point,

    const Self = @This();
    fn movePosition(self: *Self, direction: Direction) void {
        switch (direction) {
            .Left => {
                if (self.position.x > 0) self.position.x -= 1;
            },
            .Right => {
                if (self.position.x < 8) self.position.x += 1;
            },
            .Up => {
                if (self.position.y > 0) self.position.y -= 1;
            },
            .Down => {
                if (self.position.y < 8) self.position.y += 1;
            },
        }
    }

    fn setPosition(self: *Self, x: u32, y: u32) void {
        self.position.x = x;
        self.position.y = y;
    }

    fn setValue(self: *Self, value: ?u8) void {
        self.board.setValue(self.position.x, self.position.y, value);
    }

    fn getValue(self: Self, x: u32, y: u32) ?u8 {
        return self.board.getValue(x, y);
    }
};

const Board = struct {
    values: [81]?u8,

    const Self = @This();

    pub fn getValue(self: Self, x: u32, y: u32) ?u8 {
        return self.values[y * 9 + x];
    }

    pub fn setValue(self: *Self, x: u32, y: u32, value: ?u8) void {
        self.values[y * 9 + x] = value;
    }

    fn create() Board {
        return Board{
            .values = [_]?u8{null} ** 81,
        };
    }
};

const Point = struct {
    x: u32,
    y: u32,
};

const Direction = enum {
    Up, Down, Left, Right
};
