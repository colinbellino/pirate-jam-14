package bunny_raylib

import "core:fmt"
import "core:runtime"
import "core:log"
import "core:strings"
import "core:math/linalg"
import "core:math"
import "core:c/libc"
import rl "vendor:raylib"

MAX_BUNNIES        :: 40_000
MAX_BATCH_ELEMENTS :: 8192

Bunny :: struct {
    position: rl.Vector2,
    speed:    rl.Vector2,
    color:    rl.Color,
}

main :: proc() {
    using rl

    screen_width : i32 = 800
    screen_height : i32 = 450
    InitWindow(screen_width, screen_height, "raylib [core] example - basic window")
    SetTargetFPS(60)

    bunny_texture := LoadTexture("src/bunny_raylib/wabbit_alpha.png")
    bunnies_count := 0
    bunnies := [MAX_BUNNIES]Bunny {}

    for WindowShouldClose() == false {
        if IsMouseButtonDown(.LEFT) {
            for i := 0; i < 100; i += 1 {
                if bunnies_count < MAX_BUNNIES {
                    bunnies[bunnies_count].position = GetMousePosition()
                    bunnies[bunnies_count].speed.x = f32(GetRandomValue(-250, 250)) / 60
                    bunnies[bunnies_count].speed.y = f32(GetRandomValue(-250, 250)) / 60
                    bunnies[bunnies_count].color = {
                        u8(GetRandomValue(50, 240)),
                        u8(GetRandomValue(80, 240)),
                        u8(GetRandomValue(100, 240)),
                        255,
                    }
                    bunnies_count += 1
                }
            }
        }

        if IsMouseButtonDown(.RIGHT) {
            bunnies_count = 0
        }

        for i := 0; i < bunnies_count; i += 1 {
            bunnies[i].position.x += bunnies[i].speed.x
            bunnies[i].position.y += bunnies[i].speed.y

            if ((i32(bunnies[i].position.x) + bunny_texture.width / 2) > GetScreenWidth()) || ((i32(bunnies[i].position.x) + bunny_texture.width / 2) < 0) {
                bunnies[i].speed.x *= -1
            }
            if ((i32(bunnies[i].position.y) + bunny_texture.height / 2) > GetScreenHeight()) || ((i32(bunnies[i].position.y) + bunny_texture.height / 2 - 40) < 0) {
                bunnies[i].speed.y *= -1
            }
        }

        if Drawing() {
            ClearBackground(RAYWHITE)
            for i := 0; i < bunnies_count; i += 1 {
                DrawTexture(bunny_texture, i32(bunnies[i].position.x), i32(bunnies[i].position.y), bunnies[i].color)
            }

            DrawRectangle(0, 0, screen_width, 40, BLACK)
            DrawText(TextFormat("bunnies: %i", bunnies_count), 120, 10, 20, GREEN)
            DrawText(TextFormat("batched draw calls: %i", 1 + bunnies_count / MAX_BATCH_ELEMENTS), 320, 10, 20, MAROON)

            DrawFPS(10, 10)
        }
    }
}

@(deferred_none=rl.EndTextureMode)
TextureMode :: proc(target: rl.RenderTexture2D) -> bool {
    rl.BeginTextureMode(target)
    return true
}

@(deferred_none=rl.EndDrawing)
Drawing :: proc() -> bool {
    rl.BeginDrawing()
    return true
}

@(deferred_none=rl.EndShaderMode)
ShaderMode :: proc(shader: rl.Shader) -> bool {
    rl.BeginShaderMode(shader)
    return true
}
