const rl = @import("raylib");
const std = @import("std");
const Intersect = @import("../raytracer.zig").Intersect;
const Material = @import("../raytracer.zig").Material;
const obj = @import("../obj.zig");

pub const Vertice = obj.Vertice;
pub const Cara = obj.Cara;

pub const Modelo = struct {
    // triángulos del modelo, ya con la escala y el desplazamiento aplicados
    faces: []const Cara,
    // material del modelo
    Material: Material,

    /// Carga un .obj. Igual que Textura.init reserva memoria con gpa y se libera con deinit(gpa).
    /// Cada posición del archivo se transforma como posicion * escala + desplazamiento.
    pub fn init(
        io: std.Io,
        gpa: std.mem.Allocator,
        path: []const u8,
        material: Material,
        escala: f32,
        desplazamiento: rl.Vector3,
    ) !Modelo {
        const malla = try obj.cargarArchivo(io, gpa, path, escala, desplazamiento);

        return .{
            .faces = malla.faces,
            .Material = material,
        };
    }

    pub fn deinit(self: Modelo, gpa: std.mem.Allocator) void {
        gpa.free(self.faces);
    }

    pub fn intersect(self: Modelo, origin: rl.Vector3, direction: rl.Vector3) ?Intersect {
        _ = self;
        _ = origin;
        _ = direction;
        return null;
    }
};
