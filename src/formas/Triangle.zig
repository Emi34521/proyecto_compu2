const rl = @import("raylib");
const std = @import("std");
const Intersect = @import("../raytracer.zig").Intersect;
const Material = @import("../raytracer.zig").Material;

// True: el triángulo se colorea con colores RGB según las coordenadas baricéntricas,
// False: se colorea con el color del material
const barycentric_color = false;
//valor más pequeño que puede tener un float, para evitar errores de precisión
const epsilon = std.math.floatEps(f32);
// valor mínimo de t para que se considere una intersección válida, para evitar que el rayo rebote en la misma superficie
const t_min: f32 = 1e-4;

pub const Triangle = struct {
    puntos: struct {
        A: rl.Vector3,
        B: rl.Vector3,
        C: rl.Vector3,
    },
    // coordenadas de textura, si no se especifican se asume que el triángulo es un triángulo rectángulo con la esquina superior izquierda
    // en A y la esquina inferior derecha en B
    uvs: struct {
        A: rl.Vector2 = .{ .x = 0, .y = 0 },
        B: rl.Vector2 = .{ .x = 1, .y = 0 },
        C: rl.Vector2 = .{ .x = 0, .y = 1 },
    } = .{},
    // material del triángulo
    Material: Material,
    // si es true, el normal del triángulo se invierte si está apuntando hacia el rayo, esto es útil para que los triángulos sean "unilaterales"
    normal_hacia_rayo: bool = true,

    // Aquí es donde hay cambios importantes. Originalmente este intersecto se calcula mediante el área de los triángulos formados
    // por el punto de intersección y los vértices del triángulo. Y está bien, no obstante, este método es un poco más lento
    // debido a esto, claude me recomendó utilizar el método de Möller–Trumbore. No lo quise implementar hasta que, al investigarlo, se me hizo
    // intereseante y decidí implementarlo. https://www.youtube.com/watch?v=fK1RPmF_zjQ video que explica más afondo el método.

    pub fn intersect(self: Triangle, origin: rl.Vector3, direction: rl.Vector3) ?Intersect {
        // Möller–Trumbore algorithm

        // paso 1: calcular los vectores de los lados del triángulo
        // básicamente se calculan los vectores que van desde el vértice A hasta los vértices B y C
        const A = self.puntos.A;
        const e1 = self.puntos.B.subtract(A);
        const e2 = self.puntos.C.subtract(A);

        // paso 2: calcular el determinante
        // el determinante nos dice si el rayo es paralelo al triángulo o no
        // si el determinante es cercano a 0, el rayo es paralelo al triángulo y no hay intersección
        // el determinante se calcula mediante el producto cruzado de los vectores e1 y e2, y luego se calcula
        // el producto punto con el vector de dirección del rayo

        const p = direction.crossProduct(e2);
        const det = e1.dotProduct(p);
        if (@abs(det) < epsilon) return null;
        const inv_det = 1.0 / det;

        // paso 3: calcular la coordenada baricéntrica b1
        // b1 nos dice si el punto de intersección está dentro del triángulo
        // para eso el b1 debe estar entre 0 y 1, si no lo está, el punto de intersección está fuera del triángulo
        const s = origin.subtract(A);
        const b1 = s.dotProduct(p) * inv_det;
        if (b1 < 0 or b1 > 1) return null;

        // paso 4: calcular la coordenada baricéntrica b2
        // b2 nos dice si el punto de intersección está dentro del triángulo
        // para eso el b2 debe ser menor que 0 y la suma de b1 y b1 debe ser menor a 1. De lo contrario, está fuera del triángulo.
        const q = s.crossProduct(e1);
        const b2 = direction.dotProduct(q) * inv_det;
        if (b2 < 0 or b1 + b2 > 1) return null;

        // paso 5: calcular la distancia t desde el origen del rayo hasta el punto de intersección
        // si t es menor que t_min, el punto de intersección está demasiado cerca del origen del rayo y se considera que no hay intersección
        const t = e2.dotProduct(q) * inv_det;
        if (t < t_min) return null;

        // paso 6: calcular la coordenada baricéntrica b0
        // b0 nos dice si el punto de intersección está dentro del triángulo
        // no hace falta calcularlo debido a que b0, b1 y b2 deben de sumar 1 al ser una proporción. entonces se puede ahorrar el cálculo.
        const b0 = 1 - b1 - b2;

        // paso 7: calcular el normal del triángulo
        // el normal del triángulo se calcula mediante el producto cruzado de los vectores
        // que van desde el vértice A hasta los vértices B y C.
        var normal = e1.crossProduct(e2).normalize();
        if (self.normal_hacia_rayo and normal.dotProduct(direction) > 0) {
            // si el normal está apuntando hacia el rayo, se invierte para que apunte en la dirección opuesta
            normal = normal.scale(-1);
        }
        // paso 8: calcular las coordenadas de textura
        // las coordenadas de textura se calculan mediante la interpolación de las coordenadas de textura de los vértices del triángulo
        // utilizando las coordenadas baricéntricas b0, b1 y b2. Esto nos da las coordenadas de textura del punto de intersección.
        const uv: rl.Vector2 = .{
            .x = b0 * self.uvs.A.x + b1 * self.uvs.B.x + b2 * self.uvs.C.x,
            .y = b0 * self.uvs.A.y + b1 * self.uvs.B.y + b2 * self.uvs.C.y,
        };

        // se devuelve la interseeción con el material o las baricentricas.
        var material = self.Material;
        if (barycentric_color) {
            const rojo = (rl.Vector3{ .x = 1, .y = 0, .z = 0 }).scale(b0);
            const verde = (rl.Vector3{ .x = 0, .y = 1, .z = 0 }).scale(b1);
            const azul = (rl.Vector3{ .x = 0, .y = 0, .z = 1 }).scale(b2);
            material.Color = .{ .Color = rojo.add(verde).add(azul) };
        }

        return .{
            .Material = material,
            .Distancia = t,
            .Normal = normal,
            .Punto = origin.add(direction.scale(t)),
            .uv = uv,
        };
    }
};
// explicación del método de Möller-Trumbore
