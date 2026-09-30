// Original quota-ring artwork, generated solely from these drawing primitives.
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Collections.Generic;

public static class QuotaIconBuilder {
    public static void Write(string path) {
        int[] sizes = {16, 32, 48, 64, 128, 256};
        var images = new List<byte[]>();
        foreach (int size in sizes) {
            using (var bitmap = new Bitmap(size, size, PixelFormat.Format32bppArgb))
            using (var graphics = Graphics.FromImage(bitmap))
            using (var shape = new GraphicsPath())
            using (var background = new SolidBrush(Color.FromArgb(32, 36, 44)))
            using (var track = new Pen(Color.FromArgb(83, 96, 113), size * 0.10f))
            using (var arc = new Pen(Color.FromArgb(50, 213, 166), size * 0.10f)) {
                graphics.SmoothingMode = SmoothingMode.AntiAlias;
                float corner = size * 0.44f;
                shape.AddArc(0, 0, corner, corner, 180, 90);
                shape.AddArc(size - corner - 1, 0, corner, corner, 270, 90);
                shape.AddArc(size - corner - 1, size - corner - 1, corner, corner, 0, 90);
                shape.AddArc(0, size - corner - 1, corner, corner, 90, 90);
                shape.CloseFigure();
                graphics.FillPath(background, shape);
                arc.StartCap = LineCap.Round; arc.EndCap = LineCap.Round;
                var ring = new RectangleF(size * 0.18f, size * 0.18f, size * 0.64f, size * 0.64f);
                graphics.DrawEllipse(track, ring);
                graphics.DrawArc(arc, ring, -90, 270);
                using (var image = new MemoryStream()) {
                    bitmap.Save(image, ImageFormat.Png); images.Add(image.ToArray());
                }
            }
        }
        using (var file = File.Create(path))
        using (var writer = new BinaryWriter(file)) {
            writer.Write((ushort)0); writer.Write((ushort)1); writer.Write((ushort)sizes.Length);
            int offset = 6 + 16 * sizes.Length;
            for (int i = 0; i < sizes.Length; i++) {
                writer.Write((byte)(sizes[i] % 256)); writer.Write((byte)(sizes[i] % 256));
                writer.Write((byte)0); writer.Write((byte)0); writer.Write((ushort)1); writer.Write((ushort)32);
                writer.Write(images[i].Length); writer.Write(offset); offset += images[i].Length;
            }
            foreach (byte[] image in images) writer.Write(image);
        }
    }
}
