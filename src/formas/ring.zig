const rl = @import("raylib");
const std = @import("std");
const Intersect = @import("../raytracer.zig").Intersect;
const Material = @import("../raytracer.zig").Material;

pub const anillo = struct {
    center: rl.Vector3,
    rad_exterior: f32,
    rad_interior: f32,
    Material: Material,
    normal: rl.Vector3,
    vel_rot: f32 = 0.0,
    vel_tr: f32 = 0.0,
    rotacion: f32 = 0.0,

    pub fn intersect(self: anillo, origin: rl.Vector3, direction: rl.Vector3) ?Intersect {
        const denom: f32 = self.normal.dotProduct(direction);
        const epsilon = std.math.floatEps(f32);

        //a diferencia del plano, aquí si me interesa aceptar los puntos que estén por debajo del "plano" sino el anillo solo se vería
        //de un lado
        if (@abs(denom) > epsilon) {
            const numerador: f32 = self.normal.dotProduct(self.center.subtract(origin));
            const solucion = numerador / denom;
            if (solucion >= 0) {
                // ahora aquí hay cambios importantes.
                const punto = origin.add(direction.scale(solucion));
                const distancia_punto_centro = self.center.subtract(punto).length();
                // como es un anillo, este solo considerará golpe si está entre ambos radios. Lo demás, no interesa.
                if (distancia_punto_centro > self.rad_exterior) return null;
                if (distancia_punto_centro < self.rad_interior) return null;

                // para calcular el u es la distancia -  rad_interior / (diferencia radios)
                const u = (distancia_punto_centro - self.rad_interior) / (self.rad_exterior - self.rad_interior);
                // para calcular v
                const v: f32 = 1 - u;
                // para detectar como pegará la luz y si es necesario invertir la normal.
                const light_dir = self.normal.dotProduct(direction);
                if (light_dir > 0) {
                    return .{
                        .Material = self.Material,
                        .Distancia = solucion,
                        .Normal = self.normal.scale(-1),
                        .Punto = punto,
                        .uv = .{ .x = u, .y = v },
                    };
                }

                return .{
                    .Material = self.Material,
                    .Distancia = solucion,
                    .Normal = self.normal,
                    .Punto = punto,
                    .uv = .{ .x = u, .y = v },
                };
            }
        }
        return null;
    }
    pub fn traslado(self: *anillo, dt: f32) !void {
        const beta = self.vel_tr * dt;
        const x = self.center.x;
        const z = self.center.z;
        const x_nueva = x * std.math.cos(beta) - z * std.math.sin(beta);
        const z_nueva = x * std.math.sin(beta) + z * std.math.cos(beta);
        self.center.x = x_nueva;
        self.center.z = z_nueva;
    }
    pub fn rotar(self: *anillo, dt: f32) !void {
        self.rotacion += self.vel_rot * dt;
    }
};
