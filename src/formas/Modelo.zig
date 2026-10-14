const rl = @import("raylib");
const std = @import("std");
const Intersect = @import("../raytracer.zig").Intersect;
const Material = @import("../raytracer.zig").Material;
const obj = @import("../Object.zig");
const triangulo = @import("Triangle.zig");

pub const Vertice = obj.Vertice;
pub const Cara = obj.Cara;

pub const Modelo = struct {
    // triángulos del modelo, ya con la escala y el desplazamiento aplicados
    faces: []const Cara,
    // material del modelo
    Material: Material,
    //olvidé que center era un vector 3 XD
    center: rl.Vector3,
    radio: f32,

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
        //por si el cargado falla. Liberar la memoria
        errdefer malla.deinit(gpa);

        // zona para generar los parametros de una esfera que envuelva al modelo para que el raytracer pueda determinar si cargarlo o no
        //antes de mostrar y renderizar todo el modelo.
        // Si la lista de caras está vacía, se devuelve el respectivo error y así, se ejecuterá el errdefer y se liberará la memoria.
        if (malla.faces.len == 0) return error.ModeloVacio;

        // para guardar la suma de vectores
        var suma_cord = rl.Vector3.init(0, 0, 0);
        //recorre el array de faces y suma sus vértices
        for (malla.faces) |face| {
            suma_cord.x += face.a.position.x + face.b.position.x + face.c.position.x;
            suma_cord.y += face.a.position.y + face.b.position.y + face.c.position.y;
            suma_cord.z += face.a.position.z + face.b.position.z + face.c.position.z;
        }
        //Cantidad total de coordenadas que sumamos, es decir, n
        const total_vertices = @as(f32, @floatFromInt(malla.faces.len * 3));
        // asignar el nuevo centro de la esfera.

        const centro: rl.Vector3 = .{ .x = suma_cord.x / total_vertices, .y = suma_cord.y / total_vertices, .z = suma_cord.z / total_vertices };
        //calcular el radio. No encontré una mejor forma de sacarlo así que tomaré el punto con mayor distancia hacia el centro
        //y ese usaré de radio. Por lo que, recorreré nuevamente el mallas.faces

        //variables para guardar y comparar.
        var mayor_d: f32 = 0.0;
        var mayor_g: f32 = 0.0;

        for (malla.faces) |cara| {
            // un vector que vaya desde el punto de un vértice hacia el centro de la esfera
            const vector1 = cara.a.position.subtract(centro);
            const vector2 = cara.b.position.subtract(centro);
            const vector3 = cara.c.position.subtract(centro);
            // productos punto para poder comparar la distancia. Ya que, el producto punto de un vector por si mismo
            // es igual a la distancia al cuadrado. Esto me servirá para comparar la distancia máxima o más grande
            const vector1dot = vector1.dotProduct(vector1);
            const vector2dot = vector2.dotProduct(vector2);
            const vector3dot = vector3.dotProduct(vector3);

            // si el primero es mayor, simplemente se guarda. Algo importante, es que debe ser exclusivamente mayor
            // no considera si es igual , porque lo que interesa es simplemente detectar la distancia más grande.
            // Una vez detectado se guardará el vector
            if (vector1dot > mayor_d) {
                mayor_d = vector1dot;
            }
            if (vector2dot > mayor_d) {
                mayor_d = vector2dot;
            }
            if (vector3dot > mayor_d) {
                mayor_d = vector3dot;
            }
        }
        // al final de recorrer toda la malla, se asigna el valor con la distancia real. por eso se hace la raíz cuadrada
        // además, se multiplica por esa cantidad para evitar posibles errores de redondeo o que el rayo no golpee por error.
        mayor_g = @sqrt(mayor_d) * 1.0001;
        return .{
            .faces = malla.faces,
            .Material = material,
            .radio = mayor_g,
            .center = centro,
        };
    }

    pub fn deinit(self: Modelo, gpa: std.mem.Allocator) void {
        gpa.free(self.faces);
    }

    //función de intersect, para ver si se debería de mostrar el modelo o no.
    pub fn intersect(self: Modelo, origin: rl.Vector3, direction: rl.Vector3) ?Intersect {
        // verificar si el rayo le pega a una esfera antes de si quiera empezar a renderizar todo.
        // prácticamente reutilizar el código de la esfera.

        const center_to_origin = origin.subtract(self.center);

        // Estos son a,b y c como en ax^2 + bx + c = 0
        // const a = direction.dotProduct(direction);
        // a siempre es 1 si direction esta normalizado

        const b = 2 * direction.dotProduct(center_to_origin);
        const c = center_to_origin.dotProduct(center_to_origin) - self.radio * self.radio;

        // const discriminante = b * b - 4.0 * a * c;
        const discriminante = b * b - 4.0 * c;

        // a diferencia de la esfera, es mayor o igual, como la esfera estará sobre del modelo, con rozar la esfera es más que
        // suficiente.
        if (discriminante >= 0) {
            //const solucion = (-b - @sqrt(discriminante)) / 2;
            // En este caso se utiliza la raíz positiva, debido a que los rayos pueden venir dentro de la esfera. Lo que causaría errores
            const solucion = (-b + @sqrt(discriminante)) / 2;
            if (solucion < 0) return null;
            //variables para guardar los puntos espesificos del triangulo. Estos los devuelve el golpe. POr lo que es fundamental guardarlos
            var cara_t: ?obj.Cara = null;
            var mejor: ?triangulo.Triangle.Golpe = null;

            for (self.faces) |tria| {
                //moller que devuelve o no un golpe
                const moller = triangulo.Triangle.mollerTrumbore(origin, direction, tria.a.position, tria.b.position, tria.c.position);
                //se recorren los golpes que no sean nulos y se guardan.
                if (moller) |golpe| {
                    if (mejor == null or golpe.t < mejor.?.t) {
                        mejor = golpe;
                        cara_t = tria;
                    }
                }
            }
            const golpe = mejor orelse return null; // ninguna cara fue golpeada
            const cara = cara_t.?;
            //calcuar los uv "finales" los cuales representan el mejor golpe. Básicamente donde el t era menor
            const uvf: rl.Vector2 = .{
                .x = golpe.b0 * cara.a.tex_coords.x + golpe.b1 * cara.b.tex_coords.x + golpe.b2 * cara.c.tex_coords.x,
                .y = golpe.b0 * cara.a.tex_coords.y + golpe.b1 * cara.b.tex_coords.y + golpe.b2 * cara.c.tex_coords.y,
            };
            // normal final al igual que antes, se combina con el mejor golpe. Importante normalizarla
            var normal_I: rl.Vector3 = (rl.Vector3{
                .x = golpe.b0 * cara.a.normal.x + golpe.b1 * cara.b.normal.x + golpe.b2 * cara.c.normal.x,
                .y = golpe.b0 * cara.a.normal.y + golpe.b1 * cara.b.normal.y + golpe.b2 * cara.c.normal.y,
                .z = golpe.b0 * cara.a.normal.z + golpe.b1 * cara.b.normal.z + golpe.b2 * cara.c.normal.z,
            }).normalize();

            if (normal_I.dotProduct(direction) > 0) normal_I = normal_I.scale(-1);

            return .{
                .Distancia = golpe.t,
                .Punto = origin.add(direction.scale(golpe.t)),
                .Material = self.Material,
                .uv = uvf,
                .Normal = normal_I,
            };
        }
        return null;
    }
};
