const rl = @import("raylib");
const std = @import("std");
const V3FromColor = @import("raytracer").V3FromColor;

pub const Textura = struct {
    width: usize,
    height: usize,
    datos: []const rl.Vector3, //cada pixel es un vector3 con valores de 0 a 1

    pub fn init(gpa: std.mem.Allocator, path: [:0]const u8) !Textura {
        const raw_tex = rl.LoadImage(path) catch @panic("Cannot load image");

        if (raw_tex.format != .uncompressed_r8g8b8a8) {
            @panic("Fromat not supported");
        }
        const width: usize = @intCast(raw_tex.width);
        const height: usize = @intCast(raw_tex.height);

        var datos_tex: []rl.Color = undefined;
        datos_tex.ptr = @ptrCast(raw_tex.data);
        datos_tex.len = width * height;

        var datos = try gpa.alloc(rl.Vector3, width * height);
        for (datos_tex, 0..) |dato, i| {
            datos[i] = V3FromColor(dato);
        }

        return .{
            .width = width,
            .height = height,
            .datos = try gpa.alloc(rl.Vector3, width * height),
        };
    }
    pub fn sampleTexture(self: Textura, uv: rl.Vector2) rl.Vector3 {
        const w_f32: f32 = @floatFromInt(self.width - 1);
        const h_f32: f32 = @floatFromInt(self.height - 1);
        const u: usize = @intFromFloat(w_f32 * uv.x);
        const v: usize = @intFromFloat(h_f32 * uv.y);

        const text_index = v * self.width + u;
        return self.datos[text_index];
    }

    pub fn deinit(self: Textura, gpa: std.mem.Allocator) void {
        gpa.free(self.datos);
    }
};
