const Sphere = @import("formas/sphere.zig").Sphere;
const Intersect = @import("raytracer.zig").Intersect;
const rl = @import("raylib");
const Plane = @import("formas/Plane.zig").Plane;
const Triangle = @import("formas/Triangle.zig").Triangle;

const tipo = enum {
    Sphere,
    Triangle,
    Plane,
    //Plane_norm_offset,
    //Modelo,
};

pub const Forma = union(tipo) {
    Sphere: Sphere,
    Triangle: Triangle,
    Plane: Plane,
    //Plane_norm_offset: void,
    //Modelo: void,

    pub fn intersect(self: Forma, origin: rl.Vector3, direction: rl.Vector3) ?Intersect {
        return switch (self) {
            .Sphere => |a| a.intersect(origin, direction),
            .Triangle => |a| a.intersect(origin, direction),
            .Plane => |a| a.intersect(origin, direction),
            //.Plane_norm_offset => |a| a.intersect(origin, direction),
            // .Modelo => |a| a.intersect(origin, direction),
        };
    }
};
