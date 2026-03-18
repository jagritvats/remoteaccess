using System.Drawing;
using System.Drawing.Imaging;

namespace ClaudeRemote.Server.Services;

public class ScreenCaptureService
{
    public byte[] CaptureScreen(int quality = 40)
    {
        var bounds = System.Windows.Forms.Screen.PrimaryScreen?.Bounds
            ?? new Rectangle(0, 0, 1920, 1080);

        using var bitmap = new Bitmap(bounds.Width, bounds.Height);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.CopyFromScreen(bounds.Location, Point.Empty, bounds.Size);

        using var ms = new MemoryStream();
        var encoder = ImageCodecInfo.GetImageEncoders()
            .First(e => e.FormatID == ImageFormat.Jpeg.Guid);

        var encoderParams = new EncoderParameters(1);
        encoderParams.Param[0] = new EncoderParameter(Encoder.Quality, (long)quality);

        bitmap.Save(ms, encoder, encoderParams);
        return ms.ToArray();
    }
}
