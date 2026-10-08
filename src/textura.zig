const rl = @import("raylib");
const std = @import("std");
const V3FromColor = @import("raytracer.zig").V3FromColor;

pub const Textura = struct {
    width: usize,
    height: usize,
    datos: []const rl.Vector3, //cada pixel es un vector3 con valores de 0 a 1

    pub fn init(gpa: std.mem.Allocator, path: [:0]const u8) !Textura {
        const raw_tex = rl.loadImage(path) catch @panic("Cannot load image");
        defer rl.unloadImage(raw_tex);

        if (raw_tex.format != .uncompressed_r8g8b8a8) {
            @panic("Fromat not supported");
            // En dado caso el formato no sea el adecuado, preferí hacer la conversión y que se vea feo a que no se vea nada.
            // aunque, que se vea feo es un indicativo de que algo falla.
            //rl.imageFormat(&raw_tex, .uncompressed_r8g8b8a8);
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
            .datos = datos,
        };
    }
    pub fn sampleTexture(self: Textura, uv: rl.Vector2) rl.Vector3 {
        // Repetir la textura: nos quedamos solo con la parte fraccionaria, así que
        // 1.3 equivale a 0.3 y -0.2 equivale a 0.8. El resultado queda en [0, 1).
        const u = uv.x - @floor(uv.x);
        // En una imagen y=0 es la fila de arriba, pero en UV v=0 suele ser abajo.
        const v = 1.0 - (uv.y - @floor(uv.y));

        const w_f32: f32 = @floatFromInt(self.width);
        const h_f32: f32 = @floatFromInt(self.height);

        // @min protege el caso límite para no salirse del arreglo
        const x: usize = @min(@as(usize, @intFromFloat(u * w_f32)), self.width - 1);
        const y: usize = @min(@as(usize, @intFromFloat(v * h_f32)), self.height - 1);

        return self.datos[y * self.width + x];
    }

    pub fn deinit(self: Textura, gpa: std.mem.Allocator) void {
        gpa.free(self.datos);
    }
};
