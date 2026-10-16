const std = @import("std");
const builtin = @import("builtin");

const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Forma = @import("formas.zig").Forma;
const Camera = @import("camera.zig").Camera;
const Light = @import("raytracer.zig").Light;
const Intersect = @import("raytracer.zig").Intersect;
const Material = @import("raytracer.zig").Material;
const Textura = @import("textura.zig").Textura;
const Modelo = @import("formas/Modelo.zig");
const Anillo = @import("formas/ring.zig").anillo;

const htmlColor = @import("cute_colors.zig").htmlColor;
const V3FromColor = @import("raytracer.zig").V3FromColor;
const V3ToColor = @import("raytracer.zig").V3ToColor;

const Clock = std.Io.Clock.real;

const width = 1300;
const height = 900;

const block_sz: i32 = 100;

// Un cuerpo del sistema solar. Las distancias y los radios no están a escala real porque obviamente no caben,
// solo conservan el orden y las proporciones aproximadas entre planetas.
const Cuerpo = struct {
    nombre: []const u8,
    textura: [:0]const u8, // si el archivo no existe se usa color_respaldo
    color_respaldo: rl.Vector3,
    radio: f32,
    orbita: f32, // distancia al sol
    angulo_grados: f32, // posición sobre su órbita (para que no queden alineados)
    // parámetros propios de cada material (Albedo + Especular + Reflectividad + Transparencia <= 1)
    albedo: f32,
    especular: f32,
    exponente: f32, // qué tan pequeño/brillante es el punto especular
    reflectividad: f32,
    transparencia: f32,
    indice_refraccion: f32,
    brillo: f32 = 0, // > 0: material que emite luz (el sol)
    // variables para determinar si los planetas estarán rotando o se estarán trasladando
    vel_tr: f32 = 0.0,
    vel_rot: f32 = 0.0,
    rotacion: f32 = 0.0,
};

var cuerpos = [_]Cuerpo{
    // 0: el sol. Siempre debe ir de primero y en el origen, ahí también está su luz.
    .{ .nombre = "Sol", .textura = "src/Texturas/sol.png", .color_respaldo = V3FromColor(htmlColor("#ffcc33")), .radio = 9, .orbita = 0, .angulo_grados = 0, .albedo = 0, .especular = 0, .exponente = 0, .reflectividad = 0, .transparencia = 0, .indice_refraccion = 1, .brillo = 1.0 },
    .{ .nombre = "Mercurio", .textura = "src/Texturas/mercurio.png", .color_respaldo = V3FromColor(htmlColor("#9c9c9c")), .radio = 1.2, .orbita = 17, .angulo_grados = 20, .albedo = 0.85, .especular = 0.05, .exponente = 5, .reflectividad = 0, .transparencia = 0, .indice_refraccion = 0, .vel_tr = 0.43, .vel_rot = -0.02 },
    .{ .nombre = "Venus", .textura = "src/Texturas/venus.png", .color_respaldo = V3FromColor(htmlColor("#d9a066")), .radio = 2.4, .orbita = 24, .angulo_grados = 100, .albedo = 0.8, .especular = 0.1, .exponente = 10, .reflectividad = 0, .transparencia = 0, .indice_refraccion = 0, .vel_tr = 0.17, .vel_rot = 0.004 },
    // La Tierra es el material con reflexión (océanos)
    .{ .nombre = "Tierra", .textura = "src/Texturas/tierra.png", .color_respaldo = V3FromColor(htmlColor("#2f6fd0")), .radio = 2.6, .orbita = 32, .angulo_grados = 200, .albedo = 0.7, .especular = 0.15, .exponente = 60, .reflectividad = 0.15, .transparencia = 0, .indice_refraccion = 0, .vel_tr = 0.10, .vel_rot = -1.0 },
    .{ .nombre = "Marte", .textura = "src/Texturas/marte_textura.png", .color_respaldo = V3FromColor(htmlColor("#b5502d")), .radio = 1.8, .orbita = 40, .angulo_grados = 290, .albedo = 0.9, .especular = 0.05, .exponente = 5, .reflectividad = 0, .transparencia = 0, .indice_refraccion = 0, .vel_tr = 0.056, .vel_rot = 0.97 },
    .{ .nombre = "Jupiter", .textura = "src/Texturas/jupiter.png", .color_respaldo = V3FromColor(htmlColor("#c8a27a")), .radio = 6, .orbita = 56, .angulo_grados = 60, .albedo = 0.85, .especular = 0.1, .exponente = 20, .reflectividad = 0, .transparencia = 0, .indice_refraccion = 0, .vel_tr = 0.009, .vel_rot = -2.4 },
    .{ .nombre = "Saturno", .textura = "src/Texturas/saturno.png", .color_respaldo = V3FromColor(htmlColor("#e0cf9a")), .radio = 5, .orbita = 74, .angulo_grados = 150, .albedo = 0.8, .especular = 0.15, .exponente = 25, .reflectividad = 0, .transparencia = 0, .indice_refraccion = 0, .vel_tr = 0.0036, .vel_rot = -2.25 },
    // Urano es el material con refracción (planeta de hielo, índice ~1.31)
    .{ .nombre = "Urano", .textura = "src/Texturas/urano.png", .color_respaldo = V3FromColor(htmlColor("#8fd8e0")), .radio = 3.6, .orbita = 90, .angulo_grados = 240, .albedo = 0.5, .especular = 0.2, .exponente = 80, .reflectividad = 0.05, .transparencia = 0.25, .indice_refraccion = 1.31, .vel_tr = 0.0013, .vel_rot = 1.4 },
    .{ .nombre = "Neptuno", .textura = "src/Texturas/neptuno.png", .color_respaldo = V3FromColor(htmlColor("#3f5fe0")), .radio = 3.5, .orbita = 103, .angulo_grados = 330, .albedo = 0.75, .especular = 0.2, .exponente = 40, .reflectividad = 0.05, .transparencia = 0, .indice_refraccion = 0, .vel_tr = 0.0006, .vel_rot = 1.5 },
};

pub fn main() !void {
    var alloc = switch (builtin.mode) {
        .Debug, .ReleaseSafe => std.heap.DebugAllocator(.{}).init,
        .ReleaseFast, .ReleaseSmall => std.heap.smp_allocator,
    };
    const gpa: std.mem.Allocator = switch (builtin.mode) {
        .Debug, .ReleaseSafe => alloc.allocator(),
        .ReleaseFast, .ReleaseSmall => std.heap.smp_allocator,
    };
    defer switch (builtin.mode) {
        .Debug, .ReleaseSafe => _ = alloc.deinit(),
        .ReleaseFast, .ReleaseSmall => {},
    };

    var threaded: std.Io.Threaded = .init(gpa, .{});
    const io = threaded.io();
    var framebuffer = Framebuffer.init(width, height, .black, .white);

    rl.initWindow(width, height, "Raytracer!!!");
    rl.setTraceLogLevel(.warning);
    defer rl.closeWindow();
    rl.setTargetFPS(30);

    var last_frame_time = Clock.now(io);
    var delta: i64 = 1;
    // Texturas de cada cuerpo. Si el archivo no existe no truena y avisa por consola, usa el color de respaldo.
    var texturas: [cuerpos.len]?Textura = @splat(null);
    defer {
        for (texturas) |t| {
            if (t) |tex| tex.deinit(gpa);
        }
    }
    for (cuerpos, 0..) |c, i| {
        if (rl.fileExists(c.textura)) {
            texturas[i] = try Textura.init(gpa, c.textura);
            std.debug.print("[textura] {s}: {s}\n", .{ c.nombre, c.textura });
        } else {
            std.debug.print("[textura] {s}: falta {s}, uso color de respaldo\n", .{ c.nombre, c.textura });
        }
    }

    // sol + 8 planetas (esferas) + 1 asteroide (modelo)
    var objetos: [cuerpos.len + 2]Forma = undefined;
    for (cuerpos, 0..) |c, i| {
        const ang = std.math.degreesToRadians(c.angulo_grados);
        objetos[i] = .{ .Sphere = .{
            .center = .{ .x = c.orbita * @cos(ang), .y = 0, .z = c.orbita * @sin(ang) },
            .radius = c.radio,
            .vel_tr = c.vel_tr * 2,
            .vel_rot = c.vel_rot,
            .material = .{
                .Color = if (texturas[i] != null)
                    .{ .Textura = &texturas[i].? }
                else
                    .{ .Color = c.color_respaldo },
                .Propiedades = .{
                    .Albedo = c.albedo,
                    .Especular = c.especular,
                    .Reflectividad = c.reflectividad,
                    .Transparencia = c.transparencia,
                },
                .Especular = c.exponente,
                .Refractive_index = c.indice_refraccion,
                .brillo = c.brillo,
            },
        } };
    }
    var textura_ring = try Textura.init(gpa, "src/Texturas/neptuno.png");
    defer textura_ring.deinit(gpa);

    const saturno_ring = Material{ .Color = .{ .Textura = &textura_ring }, .Especular = 0.5, .Refractive_index = 0, .Propiedades = .{
        .Albedo = 0.75,
        .Especular = 0.1,
        .Reflectividad = 0,
        .Transparencia = 0,
    } };

    // Asteroide: en el cinturón entre Marte (40) y Júpiter (56)
    const roca = Material{
        .Color = .{ .Color = V3FromColor(htmlColor("#777")) },
        .Propiedades = .{ .Albedo = 0.9, .Especular = 0.05, .Reflectividad = 0, .Transparencia = 0 },
        .Especular = 5,
        .Refractive_index = 0,
    };
    const asteroide = try Modelo.Modelo.init(io, gpa, "src/modelos/asteroide.obj", roca, 1.2, .{ .x = 47, .y = 2, .z = -20 });
    defer asteroide.deinit(gpa);
    objetos[cuerpos.len] = .{ .Modelo = asteroide };
    const anillo: Anillo = .{
        .rad_exterior = 12.0,
        .center = objetos[6].Sphere.center,
        .rad_interior = 6.5,
        .Material = saturno_ring,
        //.Material = objetos[6].Sphere.material,
        .normal = .{ .x = 0.707, .y = 0.707, .z = 0 },
        .vel_rot = objetos[6].Sphere.vel_rot,
        .vel_tr = objetos[6].Sphere.vel_tr,
    };
    objetos[cuerpos.len + 1] = .{ .Anillo = anillo };

    const lights = [_]Light{
        // El sol: luz puntual en el origen, justo dentro de la esfera del sol
        .{
            .Color = V3FromColor(htmlColor("#fff")),
            .Intensity = 1,
            .tipo = .{ .puntual = .{ .x = 0, .y = 0, .z = 0 } },
        },
        // Relleno muy tenue (direccional) para que el lado oscuro de los planetas no quede negro puro
        .{
            .Color = V3FromColor(htmlColor("#8899ff")),
            .Intensity = 0.12,
            .tipo = .{ .direccional = .{ .x = -0.4, .y = -0.3, .z = -1 } },
        },
    };
    const escenario1: escena = .{
        .luces = &lights,
        .objetos = &objetos,
        .skybox = try Textura.init(gpa, "src/Texturas/Skybox_space.png"),
    };
    //siempre que se cargue una textura, hacer un defer para liberar la memoria
    defer escenario1.skybox.?.deinit(gpa);

    var cameraDistance: f32 = 200;
    var camera: Camera = .init(.{
        .x = 0,
        .y = 0,
        .z = cameraDistance,
    }, .zero());

    const cameraTurnSpeed: f32 = std.math.pi / 2.0;
    var camera_x_angle: f32 = std.math.pi;
    var camera_y_angle: f32 = 0;

    const camera_y_angle_max = std.math.pi / 4.0;
    const camera_y_angle_min = -camera_y_angle_max;

    while (!rl.windowShouldClose()) {
        defer {
            const now = Clock.now(io);
            delta = last_frame_time.durationTo(now).toMicroseconds();
            last_frame_time = now;
        }
        framebuffer.clear();

        const dt: f32 = @as(f32, @floatFromInt(delta)) / 1_000_000;

        if (rl.isKeyDown(.a)) {
            camera_x_angle += cameraTurnSpeed * dt;
        }
        if (rl.isKeyDown(.d)) {
            camera_x_angle -= cameraTurnSpeed * dt;
        }
        if (rl.isKeyDown(.w)) {
            camera_y_angle += cameraTurnSpeed * dt;
            camera_y_angle = @max(camera_y_angle_min, @min(camera_y_angle_max, camera_y_angle));
        }
        if (rl.isKeyDown(.s)) {
            camera_y_angle -= cameraTurnSpeed * dt;
            camera_y_angle = @max(camera_y_angle_min, @min(camera_y_angle_max, camera_y_angle));
        }
        if (rl.isKeyDown(.r)) {
            try rotacion(&objetos, dt);
            //rl.drawText("Rotación activa", 20, 10, 12, htmlColor("#8899ff")); //dibujar estado
        }
        if (rl.isKeyDown(.t)) {
            traslacion(&objetos, dt);
            //dibujaría el estado. Al final no lo agregué y es algo innecesario.
            //rl.drawText("Rotación activa", 20, 10, 12, htmlColor("#8899ff")); //dibujar estado
        }

        camera.Postition.x = @cos(camera_x_angle) * cameraDistance;
        camera.Postition.y = @sin(camera_y_angle) * cameraDistance;
        camera.Postition.z = @sin(camera_x_angle) * cameraDistance;

        //Para hacer un zoom en la cámara con la rueda del mouse.
        //tiene un límite porque, de pasarse
        if (rl.getMouseWheelMove() > 0 and cameraDistance > 10) {
            cameraDistance -= 10;
        }
        if (rl.getMouseWheelMove() < 0 and cameraDistance < 250) {
            cameraDistance += 10;
        }

        camera.lookAt(.zero());

        try render(io, &framebuffer, escenario1, camera);

        try framebuffer.swap_buffers();
    }
}

fn render(io: std.Io, target: *Framebuffer, escenario: escena, camera: Camera) !void {
    //para crear concurrencia y que, en teoría, ganar más fps
    var group = std.Io.Group.init;
    defer group.cancel(io);
    //for con la cantidad de bloques que tiene cada hilo
    for (0..block_sz) |xi| {
        const block_width_0: usize = @as(usize, (width / block_sz) * (xi));
        const block_width_f: usize = @as(usize, (width / block_sz) * (xi + 1));
        for (0..block_sz) |yi| {
            const block_height_0: usize = @as(usize, (height / block_sz) * yi);
            const block_height_f: usize = @as(usize, (height / block_sz) * (yi + 1));
            group.async(io, render_1_to_x, .{
                target,
                escenario,
                camera,
                block_width_0,
                block_height_0,
                block_width_f,
                block_height_f,
            });
        }
    }
    try group.await(io);
}
fn render_1_to_x(target: *Framebuffer, escema: escena, camera: Camera, x_0: usize, y_0: usize, x_f: usize, y_f: usize) void {
    const width_f32: f32 = @floatFromInt(target.width);
    const height_f32: f32 = @floatFromInt(target.height);

    const aspect_ratio = width_f32 / height_f32;
    const FOV = std.math.pi / 3.0;
    const perspective_scale = @tan(FOV * 0.5);

    for (y_0..y_f) |screen_y| {
        for (x_0..x_f) |screen_x| {
            const x_f32: f32 = @floatFromInt(screen_x);
            const y_f32: f32 = @floatFromInt(screen_y);

            const x_minus1_to_1 = (x_f32 * 2) / width_f32 - 1;
            const y_minus1_to_1 = 1 - (y_f32 * 2) / height_f32;

            const x_direction = x_minus1_to_1 * aspect_ratio * perspective_scale;
            const y_direction = y_minus1_to_1 * perspective_scale;

            const direction_from_camera = (rl.Vector3{
                .x = x_direction,
                .y = y_direction,
                .z = 1,
            }).normalize();

            const direction = rl.Vector3{
                .x = direction_from_camera.x * camera.Right.x + direction_from_camera.y * camera.Up.x + direction_from_camera.z * camera.Forward.x,
                .y = direction_from_camera.x * camera.Right.y + direction_from_camera.y * camera.Up.y + direction_from_camera.z * camera.Forward.y,
                .z = direction_from_camera.x * camera.Right.z + direction_from_camera.y * camera.Up.z + direction_from_camera.z * camera.Forward.z,
            };

            const col = cast_ray(camera.Postition, direction, escema, 5);
            target.set_pixel(@intCast(screen_x), @intCast(screen_y), V3ToColor(col)) catch |err| switch (err) {
                error.BadCoordinates => @panic("Malas coordenadas"),
            };
        }
    }
}

fn refract(incident: rl.Vector3, normal: rl.Vector3, refractive_index: f32) ?rl.Vector3 {
    var cosi = incident.dotProduct(normal);

    var etai: f32 = 1;
    var etat = refractive_index;
    var n = normal;

    if (cosi > 0) {
        std.mem.swap(f32, &etai, &etat);
        n = n.scale(-1);
    } else {
        cosi = -cosi;
    }

    const eta = etai / etat;
    const k = 1 - eta * eta * (1 - cosi * cosi);

    if (k < 0) {
        return null;
    } else {
        return (incident.scale(eta).add(n.scale(eta * cosi - @sqrt(k)))).normalize();
    }
}

fn cast_ray(origin: rl.Vector3, direction: rl.Vector3, escenario: escena, max_recursion: usize) rl.Vector3 {
    var closest_hit: ?Intersect = null;
    var z_buffer: f32 = std.math.floatMax(f32);
    for (escenario.objetos) |object| {
        const hit = object.intersect(
            origin,
            direction,
        ) orelse continue;

        if (hit.Distancia < z_buffer) {
            z_buffer = hit.Distancia;

            closest_hit = hit;
        }
    }

    if (closest_hit) |hit| {
        const mat = hit.Material;
        var color: rl.Vector3 = .zero();

        const color_base: rl.Vector3 = switch (mat.Color) {
            .Color => |c| c,
            .Textura => |tex| if (hit.uv) |uv|
                tex.sampleTexture(uv)
            else
                rl.Vector3{ .x = 1, .y = 0, .z = 1 }, // magenta: este objeto aún no tiene UV en lugar de crashear
        };

        // Materiales que brillan por sí solos se suma una sola vez.
        color = color.add(color_base.scale(mat.brillo));

        // Desde el punto a la cámara
        const view_direction = direction.scale(-1);

        if (mat.Propiedades.Reflectividad > 0) {
            if (max_recursion > 0) {
                const reflect_direction = rl.Vector3.reflect(direction, hit.Normal);
                const new_og = hit.Punto.add(reflect_direction.scale(0.001)); // Esto puede hacer que topemos con la misma figura
                // Eso es malo
                const reflect_color = cast_ray(new_og, reflect_direction, escenario, max_recursion - 1);
                color = color.add(reflect_color.scale(mat.Propiedades.Reflectividad));
            } else {
                // Refleja el fondo
                color = color.add(.zero());
            }
        }

        if (mat.Propiedades.Transparencia > 0) {
            if (max_recursion > 0) {
                if (refract(direction, hit.Normal, mat.Refractive_index)) |refract_direction| {
                    const new_og = hit.Punto.add(refract_direction.scale(0.001)); // Esto puede hacer que topemos con la misma figura
                    // Eso es malo
                    const refract_color = cast_ray(new_og, refract_direction, escenario, max_recursion - 1);
                    color = color.add(refract_color.scale(mat.Propiedades.Transparencia));
                } else {
                    const reflect_direction = rl.Vector3{ .x = 0, .y = 1, .z = 0 };
                    const new_og = hit.Punto.add(reflect_direction.scale(0.001)); // Esto puede hacer que topemos con la misma figura
                    // Eso es malo
                    const reflect_color = cast_ray(new_og, reflect_direction, escenario, max_recursion - 1);
                    color = color.add(reflect_color.scale(mat.Propiedades.Reflectividad));
                }
            } else {
                // Refleja el fondo
                color = color.add(.zero());
            }
        }
        //por cada una de las luces, como les pega.
        for (escenario.luces) |light| {
            if (obscured(hit.Punto, light, escenario.objetos)) {
                continue;
            }

            // La dirección del punto a la luz
            const light_dir = light.direccionHacia(hit.Punto);

            // ¿Cómo sabemos qué tan "bien" nos pega la luz?
            const diffuse_intensity = @max(0, light_dir.dotProduct(hit.Normal)) * light.Intensity;

            const diffuse = color_base.scale(diffuse_intensity);
            //const diffuse = mat.Color.scale(diffuse_intensity);

            // Dirección a la que reflejamos la luz
            const reflection_dir = rl.Vector3.reflect(light_dir.scale(-1), hit.Normal).normalize();

            // ¿Qué tan liso es nuestro objeto?
            // ¿Qué tan intensa y precisa es su relfexión especular?
            const specular_intensity = std.math.pow(f32, @max(0, view_direction.dotProduct(reflection_dir)), mat.Especular) * light.Intensity;

            const specular = light.Color.scale(specular_intensity);

            // El cómo mezclar los objetos es más al gusto.
            color = color.add(diffuse.scale(mat.Propiedades.Albedo));
            color = color.add(specular.scale(mat.Propiedades.Especular));
        }

        return color;
    } else return (fondo(direction, escenario));
}

fn obscured(origin: rl.Vector3, light: Light, objects: []const Forma) bool {
    const light_dir = light.direccionHacia(origin);
    // como la otra vez, olvidé que esta función existe, antes la distancia siempre era 1 y casi no existían las sombras
    // ahora funciona correctamente.
    const distancia_a_luz = Light.distanciaDesde(light, origin);

    for (objects) |object| {
        const hitman = object.intersect(origin, light_dir) orelse continue;
        if (hitman.Material.brillo > 0) {
            continue;
        }
        const hit = object.intersect(origin, light_dir) orelse continue;

        if (hit.Distancia > 0.001 and hit.Distancia < distancia_a_luz) {
            return true;
        }
    }

    return false;
}
// función auxiliar que me ayuda a detectar el fondo y retornar un color. Actualmente retorna colores en degradado. Posteriormente
// Planeo que reconozca texturas para hacer una "skybox"
fn fondo(direcion: rl.Vector3, lugar: escena) rl.Vector3 {
    if (lugar.skybox) |tex| {

        //calcular las uv para las texturas, similar a como funciona con las esferas
        const u: f32 = 0.5 + (std.math.atan2(direcion.z, direcion.x) / (2 * std.math.pi));
        const v: f32 = 0.5 - (std.math.asin(std.math.clamp(direcion.y, -1, 1)) / std.math.pi);

        // normalizar u y v para que estén entre 0 y 1
        const u_normal: f32 = @mod(u, 1.0);
        const v_normal: f32 = @mod(v, 1.0);

        const uv: rl.Vector2 = .{
            .x = u_normal,
            .y = v_normal,
        };
        return tex.sampleTexture(uv);
    }
    return .{
        .x = direcion.x * 0.5 + 0.5,
        .y = direcion.y * 0.5 + 0.5,
        .z = direcion.z * 0.5 + 0.5,
    };
}
const escena = struct {
    objetos: []const Forma,
    luces: []const Light,
    skybox: ?Textura,
};
fn rotacion(objectos: []Forma, dt: f32) !void {
    for (objectos) |*obj| {
        switch (obj.*) {
            .Sphere => |*esfera| try esfera.rotar(dt),
            .Anillo => |*anillo| try anillo.rotar(dt),
            else => {},
        }
    }
}
// función para que los planetas se puedan trasladar es decir, girar al rededor del sol.
fn traslacion(objectos: []Forma, dt: f32) void {
    for (objectos) |*obj| {
        switch (obj.*) {
            .Sphere => |*esfera| try esfera.traslado(dt),
            .Anillo => |*anillo| try anillo.traslado(dt),
            else => {},
        }
    }
}
