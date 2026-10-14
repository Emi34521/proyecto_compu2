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
    center: f32,
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
        if (malla.len == 0) return error.ModeloVacio;

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

        const centro = .{ .x = suma_cord.x / total_vertices, .y = suma_cord.y / total_vertices, .z = suma_cord.z / total_vertices };
        //calcular el radio. No encontré una mejor forma de sacarlo así que tomaré el punto con mayor distancia hacia el centro
        //y ese usaré de radio. Por lo que, recorreré nuevamente el mallas.faces

        //variables para guardar y comparar.
        var mayor_d: f32 = 0.0;
        const mayor_g: f32 = 0.0;

        for (malla.faces) |cara| {
            // un vector que vaya desde el punto de un vértice hacia el centro de la esfera
            const vector1 = cara.a.subtrac(centro);
            const vector2 = cara.b.subtrac(centro);
            const vector3 = cara.c.subtrac(centro);
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
            .centre = centro,
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
        const c = center_to_origin.dotProduct(center_to_origin) - self.radius * self.radius;

        // const discriminante = b * b - 4.0 * a * c;
        const discriminante = b * b - 4.0 * c;

        // a diferencia de la esfera, es mayor o igual, como la esfera estará sobre del modelo, con rozar la esfera es más que
        // suficiente.
        if (discriminante >= 0) {
            //const solucion = (-b - @sqrt(discriminante)) / 2;
            // En este caso se utiliza la raíz positiva, debido a que los rayos pueden venir dentro de la esfera. Lo que causaría errores
            const solucion = (-b + @sqrt(discriminante)) / 2;
            if (solucion < 0) return null;
            for (self.faces) |tria| {
                _ = tria;
            }
        }
        return null;
    }
};
