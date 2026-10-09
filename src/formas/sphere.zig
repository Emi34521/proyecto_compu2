const rl = @import("raylib");
const Intersect = @import("../raytracer.zig").Intersect;
const Material = @import("../raytracer.zig").Material;
const std = @import("std");

const scale: f32 = 50.0;
pub const Sphere = struct {
    center: rl.Vector3,
    radius: f32,
    material: Material,

    pub fn intersect(self: Sphere, origin: rl.Vector3, direction: rl.Vector3) ?Intersect {
        //https://en.wikipedia.org/wiki/Line%E2%80%93sphere_intersection
        // origin - center
        const center_to_origin = origin.subtract(self.center);

        // Estos son a,b y c como en ax^2 + bx + c = 0

        // const a = direction.dotProduct(direction);
        // a siempre es 1 si direction esta normalizado

        const b = 2 * direction.dotProduct(center_to_origin);
        const c = center_to_origin.dotProduct(center_to_origin) - self.radius * self.radius;

        // const discriminante = b * b - 4.0 * a * c;
        const discriminante = b * b - 4.0 * c;
        if (discriminante > 0) {
            const solucion = (-b - @sqrt(discriminante)) / 2;
            // const solucion = (-b + @sqrt(discriminante)) / 2;
            if (solucion > 0) {
                // punto = origin + direccion*escala;
                const point = origin.add(direction.scale(solucion));
                // Normal se refiere a la normal de la superficie de la forma
                // asumiendo que la esfera es perfectamente esferica,
                // normal es la direccion desde el centro de la esfera al punto que calculamos
                const norm = point.subtract(self.center).normalize();

                //calcular las uv para las texturas de las esferas.
                const u: f32 = 0.5 + (std.math.atan2(norm.z, norm.x) / (2 * std.math.pi));
                const v: f32 = 0.5 - (std.math.asin(norm.y) / std.math.pi);

                // normalizar u y v para que estén entre 0 y 1
                const u_normal: f32 = @mod(u, 1.0);
                const v_normal: f32 = @mod(v, 1.0);

                const uv: rl.Vector2 = .{
                    .x = u_normal,
                    .y = v_normal,
                };

                return .{
                    .Material = self.material,
                    .Distancia = solucion,
                    .Normal = norm,
                    .Punto = point,
                    .uv = uv,
                };
            }
        }
        return null;
    }
};
