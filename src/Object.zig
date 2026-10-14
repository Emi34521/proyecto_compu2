const rl = @import("raylib");
const std = @import("std");

// archivo separado para tener un sistema separado, similar al de texturas, y que el modelo no tenga demasiadas líneas de código
// que al fin y al cabo solo las realizará uan vez o lo realizará alguien más.

// Un vértice de una cara: posición, coordenadas de textura y normal.
pub const Vertice = struct {
    position: rl.Vector3,
    tex_coords: rl.Vector2,
    normal: rl.Vector3,
};

// Una cara siempre es un triángulo (si el .obj trae quads o polígonos, se triangulan al cargar).
pub const Cara = struct {
    a: Vertice,
    b: Vertice,
    c: Vertice,
};

// Resultado de leer un .obj.
pub const Malla = struct {
    faces: []Cara,

    // Cuántos datos "crudos" tenía el archivo (sirve para verificar el parser).
    // Ojo: `faces.len` cuenta TRIÁNGULOS, no las líneas `f` del archivo.
    n_posiciones: usize,
    n_uvs: usize,
    n_normales: usize,

    pub fn deinit(self: Malla, gpa: std.mem.Allocator) void {
        gpa.free(self.faces);
    }
};

pub const ErrorObj = error{
    /// Un número no se pudo parsear o falta un campo (ej. `v 1.0 2.0`).
    FormatoInvalido,
    /// Una cara referencia un v/vt/vn que no existe (índice 0, o mayor a lo leído hasta ahora).
    IndiceFueraDeRango,
    /// Una cara con menos de 3 vértices (o con demasiados).
    CaraInvalida,
};

// Máximo de vértices por cara.
const max_vertices_por_cara = 32;

// Igual que Vertice pero la normal es opcional: `f 1/1 2/2 3/3` no trae normales.
const VerticeParcial = struct {
    position: rl.Vector3,
    uv: rl.Vector2,
    normal: ?rl.Vector3,
};

// Índices de una referencia de cara "v", "v/vt", "v//vn" o "v/vt/vn" (ya en base 0).
const RefVertice = struct {
    v: usize,
    vt: ?usize,
    vn: ?usize,
};

fn leerFloat(token: ?[]const u8) ErrorObj!f32 {
    const texto = token orelse return error.FormatoInvalido;
    return std.fmt.parseFloat(f32, texto) catch error.FormatoInvalido;
}

// Los índices del .obj empiezan en 1. También pueden ser negativos.
// Devuelve el índice en base 0, o error si no existe.
fn resolverIndice(texto: []const u8, cantidad: usize) ErrorObj!usize {
    const n = std.fmt.parseInt(isize, texto, 10) catch return error.FormatoInvalido;
    const len: isize = @intCast(cantidad);
    const idx: isize = if (n > 0) n - 1 else if (n < 0) len + n else return error.IndiceFueraDeRango;
    if (idx < 0 or idx >= len) return error.IndiceFueraDeRango;
    return @intCast(idx);
}

fn parseRef(token: []const u8, n_pos: usize, n_uv: usize, n_norm: usize) ErrorObj!RefVertice {
    // Aquí SÍ hay que usar splitScalar y no tokenize en "a//c" el campo del medio está vacío y
    // hay que poder detectarlo.
    var it = std.mem.splitScalar(u8, token, '/');
    const v_txt = it.next() orelse return error.FormatoInvalido;
    const vt_txt = it.next();
    const vn_txt = it.next();
    if (it.next() != null) return error.FormatoInvalido; // más de 3 campos

    return .{
        .v = try resolverIndice(v_txt, n_pos),
        .vt = if (vt_txt) |t| (if (t.len > 0) try resolverIndice(t, n_uv) else null) else null,
        .vn = if (vn_txt) |t| (if (t.len > 0) try resolverIndice(t, n_norm) else null) else null,
    };
}

// Arma un triángulo. Si algún vértice no traía normal, usa la normal plana del triángulo.
fn triangulo(a: VerticeParcial, b: VerticeParcial, c: VerticeParcial) Cara {
    const plana = b.position.subtract(a.position)
        .crossProduct(c.position.subtract(a.position))
        .normalize();
    return .{
        .a = .{ .position = a.position, .tex_coords = a.uv, .normal = a.normal orelse plana },
        .b = .{ .position = b.position, .tex_coords = b.uv, .normal = b.normal orelse plana },
        .c = .{ .position = c.position, .tex_coords = c.uv, .normal = c.normal orelse plana },
    };
}

/// Abre un .obj (ruta relativa al directorio de trabajo) y lo carga.
/// Las posiciones se transforman al cargar posicion * escala + desplazamiento.
pub fn cargarArchivo(
    io: std.Io,
    gpa: std.mem.Allocator,
    path: []const u8,
    escala: f32,
    desplazamiento: rl.Vector3,
) !Malla {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);

    var buffer: [4096]u8 = undefined;
    var file_reader = file.reader(io, &buffer);
    return parse(gpa, &file_reader.interface, escala, desplazamiento);
}

/// Parsea el contenido de un .obj leyendo de cualquier Reader
pub fn parse(
    gpa: std.mem.Allocator,
    reader: *std.Io.Reader,
    escala: f32,
    desplazamiento: rl.Vector3,
) !Malla {
    // Un enum que se encarga de manejar la parte del archivo que está leyendo del .obj
    const Estado = enum {
        init,
        vertices,
        uv, //vt dentro del modelo
        normal, //vn dentro del modelo
        cara, //f dentro del modelo
    };

    // Inicializamos los arraylists para almacenar los datos del modelo con sus respectivos defer para garantizar limpiar los datos
    var positions: std.ArrayList(rl.Vector3) = .empty;
    defer positions.deinit(gpa);

    var uvs: std.ArrayList(rl.Vector2) = .empty;
    defer uvs.deinit(gpa);

    var normals: std.ArrayList(rl.Vector3) = .empty;
    defer normals.deinit(gpa);

    //Limpiar la memoria incluso si se encuentra un error.
    var faces: std.ArrayList(Cara) = .empty;
    errdefer faces.deinit(gpa);

    // takeDelimiter devuelve la línea SIN el '\n' y, a diferencia de takeDelimiterInclusive,
    // también devuelve la última línea si el archivo no termina en salto de línea. Devuelve null al terminar.
    while (try reader.takeDelimiter('\n')) |linea_cruda| {
        // Si el archivo viene de Windows (\r\n) quité el '\r'. Así no hace falta saber el sistema operativo.
        const linea = std.mem.trimEnd(u8, linea_cruda, "\r");

        // tokenize se salta espacios repetidos y líneas vacías (a diferencia de splitScalar).
        var tokens = std.mem.tokenizeAny(u8, linea, " \t");
        const tag = tokens.next() orelse continue; // línea vacía

        state_machine: switch (Estado.init) {
            .init => {
                if (std.mem.eql(u8, tag, "v")) {
                    continue :state_machine .vertices;
                } else if (std.mem.eql(u8, tag, "vt")) {
                    continue :state_machine .uv;
                } else if (std.mem.eql(u8, tag, "vn")) {
                    continue :state_machine .normal;
                } else if (std.mem.eql(u8, tag, "f")) {
                    continue :state_machine .cara;
                }
                // Cualquier otra cosa (#, o, g, s, usemtl, mtllib...) se ignora.
            },
            .vertices => {
                const x = try leerFloat(tokens.next());
                const y = try leerFloat(tokens.next());
                const z = try leerFloat(tokens.next());
                // Escala y desplazamiento se aplican aquí, al cargar. Así cualquier cálculo posterior
                // (como la esfera envolvente) ya trabaja con las posiciones finales.
                const pos = rl.Vector3.init(x, y, z).scale(escala).add(desplazamiento);
                try positions.append(gpa, pos);
            },
            .uv => {
                const u = try leerFloat(tokens.next());
                const v = try leerFloat(tokens.next());
                try uvs.append(gpa, rl.Vector2.init(u, v));
            },
            .normal => {
                const x = try leerFloat(tokens.next());
                const y = try leerFloat(tokens.next());
                const z = try leerFloat(tokens.next());
                // La normal NO se escala ni se desplaza (solo se escala uniformemente, y una normal es dirección).
                try normals.append(gpa, rl.Vector3.init(x, y, z));
            },
            .cara => {
                var poligono: [max_vertices_por_cara]VerticeParcial = undefined;
                var n: usize = 0;

                while (tokens.next()) |token| {
                    if (n == poligono.len) return error.CaraInvalida;
                    const ref = try parseRef(token, positions.items.len, uvs.items.len, normals.items.len);
                    poligono[n] = .{
                        .position = positions.items[ref.v],
                        // Cara sin UV (a//c): usamos (0, 0).
                        .uv = if (ref.vt) |i| uvs.items[i] else rl.Vector2.zero(),
                        .normal = if (ref.vn) |i| normals.items[i] else null,
                    };
                    n += 1;
                }
                if (n < 3) return error.CaraInvalida;

                // Triangulación en abanico: un quad (0,1,2,3) -> (0,1,2) y (0,2,3), etc.
                // Un triángulo normal (n == 3) produce exactamente 1 cara.
                for (1..n - 1) |i| {
                    try faces.append(gpa, triangulo(poligono[0], poligono[i], poligono[i + 1]));
                }
            },
        }
    }

    return .{
        .faces = try faces.toOwnedSlice(gpa),
        .n_posiciones = positions.items.len,
        .n_uvs = uvs.items.len,
        .n_normales = normals.items.len,
    };
}
