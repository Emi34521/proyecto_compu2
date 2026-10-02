const rl = @import("raylib");
const std = @import("std");
const Intersect = @import("raytracer").Intersect;
const Material = @import("raytracer").Material;

const scale: f32 = 50.0;

pub const Plane = struct {
    Normal: rl.Vector3,
    x_0: rl.Vector3,
    Material: Material,

    pub fn intersect(self: Plane, origin: rl.Vector3, direction: rl.Vector3) ?Intersect {
        const denom: f32 = rl.Vector3Dot(self.Normal, direction);
        const epsilon = std.math.floatEps(f32);

        if (denom > epsilon) {
            const numerador: f32 = self.Normal.dotProduct(self.x_0.substract(origin));
            const solucion = numerador / denom;
            if (solucion >= 0) {
                const punto = origin.add(direction.scale(solucion));

                const diff = self.x_0.substract(punto);
                const u: f32 = @mod(@abs(diff.x + diff.y), scale) / scale;
                const v: f32 = @mod(@abs(diff.z + diff.y), scale) / scale;

                return Intersect{
                    .Material = self.Material,
                    .Distancia = solucion,
                    .Normal = self.Normal.scale(-1),
                    .uv = .{ .x = u, .y = v },
                };
            }
        }
        return null;
    }
};
