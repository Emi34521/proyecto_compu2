const rl = @import("raylib");
const std = @import("std");
const Intersect = @import("raytracer").Intersect;
const Material = @import("raytracer").Material;

const barycentric_color = true;

pub const Triangle = struct {
    puntos: struct {
        A: rl.Vector3,
        B: rl.Vector3,
        C: rl.Vector3,
    },
    Material: Material,

    pub fn intersect(self: Triangle, origin: rl.Vector3, direction: rl.Vector3) ?Intersect {
        const AB = self.puntos.B.substract(self.puntos.A);
        const AC = self.puntos.C.substract(self.puntos.A);
        const plane_normal: rl.Vector3 = rl.Vector3.crossProduct(AB, AC);

        const denom = plane_normal.dotProduct(direction);
        const epsilon = std.math.floatEps(f32);

        if (denom > epsilon) {
            const numerador: f32 = plane_normal.dotProduct(self.puntos.A.substract(origin));
            const solucion = numerador / denom;

            if (solucion >= 0) {
                const punto = origin.add(direction.scale(solucion));
                const area = plane_normal.length() / 2;

                const u: f32 = blk: {
                    const BP = punto.substract(self.puntos.B);
                    const BC = self.puntos.C.substract(self.puntos.B);
                    const cross = rl.Vector3.crossProduct(BC, BP);

                    break :blk (cross.length()) / area;
                };

                const v: f32 = blk: {
                    const CP = punto.substract(self.puntos.C);
                    const CA = self.puntos.A.substract(self.puntos.C);
                    const cross = rl.Vector3.crossProduct(CA, CP);

                    break :blk (cross.length()) / area;
                };

                const w: f32 = 1 - u - v;
                if (w < 0) return null;
                if (w > 1) return null;

                var new_mat = self.Material;

                if (barycentric_color) {
                    const red = (rl.Vector3{ .x = 1, .y = 0, .z = 0 }).scale(u);
                    const green = (rl.Vector3{ .x = 0, .y = 1, .z = 0 }).scale(v);
                    const blue = (rl.Vector3{ .x = 0, .y = 0, .z = 1 }).scale(w);
                    new_mat.Color = .{
                        .Color = red.add(green).add(blue),
                    };
                }
            }
        }
    }
};
