const rl = @import("raylib");
const std = @import("std");
const Intersect = @import("../raytracer.zig").Intersect;
const Material = @import("../raytracer.zig").Material;
const builtin = @import("builtin");

const scale: f32 = 50.0;

pub const Modelo = struct {};

pub fn load_model(io: std.Io, gpa: std.mem.Allocator, path: [:0]const u8) !Modelo {
    // Un enum que se encarga de manejar la parte del archivo que está leyendo del .obj
    const parser_state = enum {
        init,
        vertices,
        uv, //vt dentro del modelo
        normal,
    };

    const cwd = std.fs.cwd();
    const file = try cwd.openFile(io, path, .{});
    defer file.close();

    var reader: [1024]u8 = undefined;
    var fd_reader = file.reader(io, &reader);
    const line_reader = &fd_reader.interface;

    // Inicializamos los arraylists para almacenar los datos del modelo con sus respectivos defer para garantizar limpiar los datos
    var positions: std.ArrayList(rl.Vector3) = .empty();
    defer positions.deinit(gpa);

    var uvs: std.ArrayList(rl.Vector2) = .empty();
    defer uvs.deinit(gpa);

    //Limpiar la memoria incluso si se ncuentra un error.
    var faces: std.ArrayList(rl.Vector3) = .empty();
    errdefer faces.deinit(gpa);

    var normals: std.ArrayList(rl.Vector3) = .empty();
    defer normals.deinit(gpa);

    const offset = if (builtin.target.os.tag == .windows) 2 else 1;
    loop: while (line_reader.takeDelimiterInclusive("\n")) |line| {
        state_machine: switch (parser_state.init) {
            .init => {
                switch (line[0]) {
                    'v' => switch (line[1]) {
                        'n' => {
                            continue :state_machine .normal;
                        },
                        't' => {
                            continue :state_machine .uv;
                        },
                        ' ' => {
                            continue :state_machine .vertices;
                        },
                        else => @panic("algo salió mal..."),
                    },
                    'f' => {
                        const datos_stringy = line[2 .. line.len - offset];
                        //cortar los espacios entre los f
                        var splits_espacios = std.mem.splitScalar(u8, datos_stringy, " ");
                        var cara: faces = .{
                            .a = .{
                                .normal = .zero(),
                                .position = .zero(),
                                .tex_coords = .zero(),
                            },
                            .b = .{
                                .normal = .zero(),
                                .position = .zero(),
                                .tex_coords = .zero(),
                            },
                            .c = .{
                                .normal = .zero(),
                                .position = .zero(),
                                .tex_coords = .zero(),
                            },
                        };
                        var counter: usize = 0;
                        while (splits_espacios.next()) |vertex| {
                            var split_iterator = std.mem.splitScalar(u8, vertex, "/");
                            const vert = split_iterator.next() orelse @panic("algo falló al cargar un vértice");
                            const uv = split_iterator.next() orelse @panic("algo falló al cargar una uv");
                            const normal = split_iterator.next() orelse @panic("algo falló al cargar una normal");

                            switch (counter) {
                                0 => {
                                    const v_indx = std.mem.parseInt(usize, vert, 10) catch @panic("no se pudo cargar el .obj");
                                    cara.a.position = positions.items[v_indx - 1];
                                    const n_indx = std.mem.parseInt(usize, normal, 10) catch @panic("no se pudo cargar el .obj");
                                    cara.a.normal = normals.items[n_indx - 1];
                                    const uv_indx = std.mem.parseInt(usize, uv, 10) catch @panic("no se pudo cargar el .obj");
                                    cara.a.tex_coords = uvs.items[uv_indx - 1];
                                },
                                1 => {
                                    const v_indx = std.mem.parseInt(usize, vert, 10) catch @panic("no se pudo cargar el .obj");
                                    cara.b.position = positions.items[v_indx - 1];
                                    const n_indx = std.mem.parseInt(usize, normal, 10) catch @panic("no se pudo cargar el .obj");
                                    cara.b.normal = normals.items[n_indx - 1];
                                    const uv_indx = std.mem.parseInt(usize, vert, 10) catch @panic("no se pudo cargar el .obj");
                                    cara.b.tex_coords = uvs.items[uv_indx - 1];
                                },
                                2 => {
                                    const v_indx = std.mem.parseInt(usize, vert, 10) catch @panic("no se pudo cargar el .obj");
                                    cara.c.position = positions.items[v_indx - 1];
                                    const n_indx = std.mem.parseInt(usize, normal, 10) catch @panic("no se pudo cargar el .obj");
                                    cara.c.normal = normals.items[n_indx - 1];
                                    const uv_indx = std.mem.parseInt(usize, vert, 10) catch @panic("no se pudo cargar el .obj");
                                    cara.c.tex_coords = uvs.items[uv_indx - 1];
                                },
                                else => @panic("Solo se soportan triángulos"),
                            }
                            counter += 1;
                        }
                        try faces.append(gpa, cara);
                    },
                    else => continue :loop,
                }
            },
            .normal => {
                const datos_stringy = line[3 .. line.len - offset];
                var split_iterator = std.mem.splitScalar(u8, datos_stringy, ' ');
                const norm_x = split_iterator.next() orelse @panic("algo falló al cargar las normales");
                const norm_y = split_iterator.next() orelse @panic("algo falló al cargar las normales");
                const norm_z = split_iterator.next() orelse @panic("algo falló al cargar las normales");

                try normals.append(gpa, .{
                    .x = std.fmt.parseFloat(f32, norm_x) catch @panic("falló el append xd"),
                    .y = std.fmt.parseFloat(f32, norm_y) catch @panic("falló el append xd"),
                    .z = std.fmt.parseFloat(f32, norm_z) catch @panic("falló el append xd"),
                });
            },
            .uv => {
                const datos_stringy = line[3 .. line.len - offset];
                var split_iterator = std.mem.splitScalar(u8, datos_stringy, ' ');

                const uv_x = split_iterator.next() orelse @panic("algo falló al cargar el uv");
                const uv_y = split_iterator.next() orelse @panic("algo falló al cargar el uv");

                try uvs.append(gpa, .{
                    .x = std.fmt.parseFloat(f32, uv_x) orelse @panic("Falló el append"),
                    .y = std.fmt.parseFloat(f32, uv_y) orelse @panic("Falló el append"),
                });
            },
            .vertices => {
                const datos_stringy = line[2 .. line.len - offset];
                var split_iterator = std.mem.splitScalar(u8, datos_stringy, ' ');
                const cx = split_iterator.next() orelse @panic("algo falló al cargar los vertices");
                const cy = split_iterator.next() orelse @panic("algo falló al cargar los vertices");
                const cz = split_iterator.next() orelse @panic("algo falló al cargar los vertices");

                try positions.append(gpa, .{
                    .x = std.fmt.parseFloat(f32, cx) catch @panic("falló el append xd"),
                    .y = std.fmt.parseFloat(f32, cy) catch @panic("falló el append xd"),
                    .z = std.fmt.parseFloat(f32, cz) catch @panic("falló el append xd"),
                });
            },
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        error.ReadFailed => |e| return e,
        error.StreamTooLong => |e| return e,
    }
    return .{
        .faces = try faces.toOwnedSlice(gpa),
    };
}
