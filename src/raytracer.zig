const rl = @import("raylib");
const textura = @import("textura.zig").Textura;
const std = @import("std");
const col_or_tex = enum {
    Color,
    Textura,
};
// como se estará implementando la "simulación" de la luz del sol. Entonces estaré haciendo este enum para
// facilitar la creación de una luz puntual o una direccional.
const tipo_luz = enum {
    puntual,
    direccional,
};

pub const Light = struct {
    Color: rl.Vector3,
    Intensity: f32,
    tipo: union(tipo_luz) {
        puntual: rl.Vector3, // posición
        direccional: rl.Vector3, // hacia dónde viaja la luz
    },
    //funciones para que ahora hayan diversos tipos de luz.
    pub fn direccionHacia(self: Light, punto: rl.Vector3) rl.Vector3 {
        switch (self.tipo) {
            .puntual => |posicion| {
                // En la luz "puntual" esta forma de calcular la luz funciona
                //Vector = Destino - Origen
                const direccion = rl.Vector3.subtract(posicion, punto);
                return rl.Vector3.normalize(direccion);
            },
            .direccional => |dir| {
                // en cambio, para una luz direccional simplemente se devuelve el opuesto normalizado
                return rl.Vector3.scale(dir, -1).normalize();
            },
        }
    }
    pub fn distanciaDesde(self: Light, punto: rl.Vector3) f32 {
        switch (self.tipo) {
            .puntual => |posicion| {
                const direccion = rl.Vector3.subtract(posicion, punto);
                const vectorN = rl.Vector3.normalize(direccion);
                return vectorN.length();
            },
            .direccional => {
                return std.math.inf(f32);
            },
        }
    }
};
pub fn V3FromColor(src: rl.Color) rl.Vector3 {
    const x: f32 = @floatFromInt(src.r);
    const y: f32 = @floatFromInt(src.g);
    const z: f32 = @floatFromInt(src.b);
    return .{ .x = x / 255, .y = y / 255, .z = z / 255 };
}

pub fn V3ToColor(color: rl.Vector3) rl.Color {
    const r: u8 = @intFromFloat(@max(0, @min(255, color.x * 255)));
    const g: u8 = @intFromFloat(@max(0, @min(255, color.y * 255)));
    const b: u8 = @intFromFloat(@max(0, @min(255, color.z * 255)));
    return .{ .r = r, .g = g, .b = b, .a = 0xff };
}
pub const Material = struct {
    //xyz como rgb, pero reducimos conversiones primero haciendo mate en f32 y luego convertimos de regreso a u8
    Color: union(col_or_tex) {
        Color: rl.Vector3,
        Textura: *textura,
    }, //tiene un color el material
    Especular: f32,
    Refractive_index: f32,
    Propiedades: struct {
        //todas tienen que sumar 1 como máximo.
        Albedo: f32, //que tanto refleja la luz (va de 0 a 1)
        Especular: f32, // puede ser mayor a 1, indica que tan "liso" es el material. Hace que el punto de luz sea más pequeño
        Reflectividad: f32,
        Transparencia: f32,
    },
    Norm_map: ?*textura = null, //mapa de normales, si es null no hay mapa de normales
};

pub const Intersect = struct {
    Material: Material,
    Distancia: f32,
    Normal: rl.Vector3,
    Punto: rl.Vector3,
    uv: ?rl.Vector2,
};
