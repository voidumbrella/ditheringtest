const zimg = @import("zigimg");
const std = @import("std");

fn bayer(x: usize, y: usize) f32 {
    const BAYER: [8][8]f32 = .{
        .{ 0, 32, 8, 40, 2, 34, 10, 42 },
        .{ 48, 16, 56, 24, 50, 18, 58, 26 },
        .{ 12, 44, 4, 36, 14, 46, 6, 38 },
        .{ 60, 28, 52, 20, 62, 30, 54, 22 },
        .{ 3, 35, 11, 43, 1, 33, 9, 41 },
        .{ 51, 19, 59, 27, 49, 17, 57, 25 },
        .{ 15, 47, 7, 39, 13, 45, 5, 37 },
        .{ 63, 31, 55, 23, 61, 29, 53, 21 },
    };

    return BAYER[y % 8][x % 8] / 64;
}

const COLOR0 = zimg.color.Rgb24.initRgb(31, 54, 30);
const COLOR1 = zimg.color.Rgb24.initRgb(204, 224, 169);

pub fn main() !u8 {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // discard argv[0] (it's the executable name)
    const in_file = args.next().?;
    const out_file = args.next().?;

    var orig = try zimg.Image.fromFilePath(allocator, in_file);
    defer orig.deinit();

    var new = try zimg.Image.create(allocator, orig.width, orig.height, .rgb24);
    defer new.deinit();

    var buffer = new.pixels.rgb24;
    var x: usize = 0;
    var y: usize = 0;
    var it = orig.iterator();
    while (it.next()) |pixel| {
        // https://en.wikipedia.org/wiki/Relative_luminance
        var luminance = 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;

        const i = y * orig.width + x;
        if (luminance < bayer(x, y)) {
            buffer[i] = COLOR0;
        } else {
            buffer[i] = COLOR1;
        }

        x += 1;
        if (x == orig.width) {
            x = 0;
            y += 1;
        }
    }

    try new.writeToFilePath(
        out_file,
        zimg.Image.EncoderOptions{ .png = .{} },
    );

    return 0;
}
