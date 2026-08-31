# Self-contained GIF Generator with built-in LZW compressor and unified palette (Safe C#)

Add-Type -AssemblyName System.Drawing

$csharpCode = @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class GifEncoder {
    private Stream _stream;
    private int _width;
    private int _height;
    private List<Color> _palette;
    private Dictionary<int, byte> _colorCache = new Dictionary<int, byte>();
    private bool _started = false;

    public void Start(Stream stream, int width, int height, List<Color> globalPalette) {
        _stream = stream;
        _width = width;
        _height = height;
        _palette = new List<Color>(globalPalette);
        
        while (_palette.Count < 256) {
            _palette.Add(Color.Black);
        }

        // Header: GIF89a
        byte[] header = new byte[] { (byte)'G', (byte)'I', (byte)'F', (byte)'8', (byte)'9', (byte)'a' };
        _stream.Write(header, 0, 6);

        // Logical Screen Descriptor (7 bytes)
        byte[] lsd = new byte[7];
        lsd[0] = (byte)(_width & 0xFF);
        lsd[1] = (byte)((_width >> 8) & 0xFF);
        lsd[2] = (byte)(_height & 0xFF);
        lsd[3] = (byte)((_height >> 8) & 0xFF);
        lsd[4] = 0xF7; // GCT present, 8 bits/pixel (256 colors)
        lsd[5] = 0;    // Background color index
        lsd[6] = 0;    // Pixel aspect ratio
        _stream.Write(lsd, 0, 7);

        // Global Color Table (768 bytes)
        byte[] gct = new byte[768];
        for (int i = 0; i < 256; i++) {
            gct[i * 3 + 0] = _palette[i].R;
            gct[i * 3 + 1] = _palette[i].G;
            gct[i * 3 + 2] = _palette[i].B;
        }
        _stream.Write(gct, 0, 768);

        // Netscape Application Extension for infinite loop
        byte[] netscape = new byte[] {
            0x21, 0xFF, 0x0B,
            (byte)'N', (byte)'E', (byte)'T', (byte)'S', (byte)'C', (byte)'A', (byte)'P', (byte)'E', (byte)'2', (byte)'.', (byte)'0',
            0x03, 0x01, 0x00, 0x00, 0x00
        };
        _stream.Write(netscape, 0, netscape.Length);
        _started = true;
    }

    public void AddFrame(Bitmap bmp, int delayMs) {
        if (!_started) throw new InvalidOperationException("Call Start first");

        byte[] indexedPixels = Quantize(bmp);

        // 1. Graphic Control Extension (8 bytes)
        int delay100ths = Math.Max(1, delayMs / 10);
        byte[] gce = new byte[] {
            0x21, 0xF9, 0x04,
            0x04, // Disposal method: 1 = do not dispose / overwrite
            (byte)(delay100ths & 0xFF), (byte)((delay100ths >> 8) & 0xFF),
            0x00, // transparent index
            0x00  // block terminator
        };
        _stream.Write(gce, 0, gce.Length);

        // 2. Image Descriptor (10 bytes)
        byte[] id = new byte[10];
        id[0] = 0x2C; // Separator
        id[1] = 0; id[2] = 0; // Left = 0
        id[3] = 0; id[4] = 0; // Top = 0
        id[5] = (byte)(_width & 0xFF);
        id[6] = (byte)((_width >> 8) & 0xFF);
        id[7] = (byte)(_height & 0xFF);
        id[8] = (byte)((_height >> 8) & 0xFF);
        id[9] = 0x00; // Use Global Color Table
        _stream.Write(id, 0, 10);

        // 3. Compress and write image data using LZW
        WriteLzwData(indexedPixels, 8);
    }

    private byte[] Quantize(Bitmap bmp) {
        int w = bmp.Width;
        int h = bmp.Height;
        byte[] indices = new byte[w * h];

        BitmapData data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try {
            int byteCount = Math.Abs(data.Stride) * h;
            byte[] rawBytes = new byte[byteCount];
            Marshal.Copy(data.Scan0, rawBytes, 0, byteCount);

            int stride = data.Stride;
            int idx = 0;
            for (int y = 0; y < h; y++) {
                int rowOffset = y * stride;
                for (int x = 0; x < w; x++) {
                    int pixelOffset = rowOffset + x * 4;
                    byte b = rawBytes[pixelOffset + 0];
                    byte g = rawBytes[pixelOffset + 1];
                    byte r = rawBytes[pixelOffset + 2];
                    indices[idx++] = GetClosestColorIndex(r, g, b);
                }
            }
        } finally {
            bmp.UnlockBits(data);
        }
        return indices;
    }

    private byte GetClosestColorIndex(byte r, byte g, byte b) {
        int key = (r << 16) | (g << 8) | b;
        byte result;
        if (_colorCache.TryGetValue(key, out result)) {
            return result;
        }

        int bestDist = int.MaxValue;
        byte bestIdx = 0;

        for (int i = 0; i < _palette.Count; i++) {
            Color c = _palette[i];
            int dr = r - c.R;
            int dg = g - c.G;
            int db = b - c.B;
            int dist = 2 * dr * dr + 4 * dg * dg + 3 * db * db;
            if (dist < bestDist) {
                bestDist = dist;
                bestIdx = (byte)i;
                if (dist == 0) break;
            }
        }

        _colorCache[key] = bestIdx;
        return bestIdx;
    }

    private void WriteLzwData(byte[] pixels, int initCodeSize) {
        _stream.WriteByte((byte)initCodeSize);

        int clearCode = 1 << initCodeSize; // 256
        int eoiCode = clearCode + 1;       // 257

        int codeSize = initCodeSize + 1;   // 9
        int maxCode = 1 << codeSize;

        Dictionary<int, int> dict = new Dictionary<int, int>();
        Action resetDict = () => {
            dict.Clear();
            codeSize = initCodeSize + 1;
            maxCode = 1 << codeSize;
        };

        resetDict();

        BitWriter bitWriter = new BitWriter(_stream);
        bitWriter.Write(clearCode, codeSize);

        int prefix = pixels[0];

        for (int i = 1; i < pixels.Length; i++) {
            int suffix = pixels[i];
            int key = (prefix << 8) | suffix;

            int code;
            if (dict.TryGetValue(key, out code)) {
                prefix = code;
            } else {
                bitWriter.Write(prefix, codeSize);

                if (dict.Count + clearCode + 2 < 4096) {
                    dict[key] = dict.Count + clearCode + 2;
                    if (dict.Count + clearCode + 2 >= maxCode && codeSize < 12) {
                        codeSize++;
                        maxCode = 1 << codeSize;
                    }
                } else {
                    bitWriter.Write(clearCode, codeSize);
                    resetDict();
                }

                prefix = suffix;
            }
        }

        bitWriter.Write(prefix, codeSize);
        bitWriter.Write(eoiCode, codeSize);
        bitWriter.Flush();

        _stream.WriteByte(0x00); // Block terminator
    }

    public void Finish() {
        if (_stream != null) {
            _stream.WriteByte(0x3B); // GIF Trailer
            _stream.Flush();
        }
    }

    private class BitWriter {
        private Stream _out;
        private byte[] _buf = new byte[255];
        private int _bufPos = 0;
        private int _curBits = 0;
        private int _numBits = 0;

        public BitWriter(Stream stream) {
            _out = stream;
        }

        public void Write(int code, int size) {
            _curBits |= (code << _numBits);
            _numBits += size;

            while (_numBits >= 8) {
                EmitByte((byte)(_curBits & 0xFF));
                _curBits >>= 8;
                _numBits -= 8;
            }
        }

        public void Flush() {
            if (_numBits > 0) {
                EmitByte((byte)(_curBits & 0xFF));
                _curBits = 0;
                _numBits = 0;
            }
            FlushBlock();
        }

        private void EmitByte(byte b) {
            _buf[_bufPos++] = b;
            if (_bufPos == 255) {
                FlushBlock();
            }
        }

        private void FlushBlock() {
            if (_bufPos > 0) {
                _out.WriteByte((byte)_bufPos);
                _out.Write(_buf, 0, _bufPos);
                _bufPos = 0;
            }
        }
    }
}

public class PaletteBuilder {
    public static List<Color> BuildMasterPalette() {
        HashSet<int> seen = new HashSet<int>();
        List<Color> pal = new List<Color>();

        Action<Color> add = (c) => {
            int rgb = (c.R << 16) | (c.G << 8) | c.B;
            if (!seen.Contains(rgb)) {
                seen.Add(rgb);
                pal.Add(c);
            }
        };

        add(Color.White);
        add(Color.FromArgb(248, 250, 252));
        add(Color.FromArgb(241, 245, 249));
        add(Color.FromArgb(226, 232, 240));
        add(Color.FromArgb(203, 213, 225));
        add(Color.FromArgb(148, 163, 184));
        add(Color.FromArgb(100, 116, 139));
        add(Color.FromArgb(71, 85, 105));
        add(Color.FromArgb(51, 65, 85));
        add(Color.FromArgb(30, 41, 59));
        add(Color.FromArgb(15, 23, 42));
        add(Color.Black);

        string[] hexes = new string[] {
            "#2ca02c", "#16a34a", "#15803d", "#4ade80", "#bbf7d0",
            "#9467bd", "#9333ea", "#7e22ce", "#c084fc", "#e9d5ff",
            "#1f77b4", "#2563eb", "#1d4ed8", "#60a5fa", "#bfdbfe",
            "#ff7f0e", "#ea580c", "#c2410c", "#fb923c", "#fed7aa",
            "#d62728", "#dc2626", "#b91c1c", "#f87171", "#fecaca"
        };

        foreach (var h in hexes) {
            add(ColorTranslator.FromHtml(h));
        }

        int[] steps = new int[] { 0, 51, 102, 153, 204, 255 };
        foreach (int r in steps) {
            foreach (int g in steps) {
                foreach (int b in steps) {
                    add(Color.FromArgb(r, g, b));
                }
            }
        }

        for (int i = 0; i <= 255; i += 17) {
            add(Color.FromArgb(i, i, i));
        }

        return pal;
    }
}

public class SeriesData {
    public string Name { get; set; }
    public Color Color { get; set; }
    public double[] Values { get; set; }

    public SeriesData(string name, string hexColor, double[] values) {
        Name = name;
        Color = ColorTranslator.FromHtml(hexColor);
        Values = values;
    }
}

public class BannerRenderer {
    public const int Width = 640;
    public const int Height = 320;
    public const int TopPad = 50;
    public const int BottomPad = 50;

    // Usable Chart Area strictly inside y: 50..270 (height: 220px)
    private const float PlotLeft = 52f;
    private const float PlotRight = 588f;
    private const float PlotTop = 106f;
    private const float PlotBottom = 244f;
    private const float YMax = 72f;

    private static readonly string[] Years = new string[] { "2020", "2021", "2022", "2023", "2024", "2025", "2026" };

    public static Bitmap RenderFrame(List<SeriesData> seriesList, float progress, bool isFinal) {
        Bitmap bmp = new Bitmap(Width, Height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;

            // Background
            using (SolidBrush bgBrush = new SolidBrush(Color.White)) {
                g.FillRectangle(bgBrush, 0, 0, Width, Height);
            }

            // Title at y = 54 (strictly >= 50px)
            using (Font titleFont = new Font("Segoe UI", 11.5f, FontStyle.Bold))
            using (SolidBrush titleBrush = new SolidBrush(Color.FromArgb(15, 23, 42))) {
                g.DrawString("Evolution of AI Frontier Training Budgets", titleFont, titleBrush, new PointF(24, 54));
            }

            // Period badge (2020 - 2026) at top right
            using (Font badgeFont = new Font("Segoe UI", 8.0f, FontStyle.Bold))
            using (SolidBrush badgeTextBrush = new SolidBrush(Color.FromArgb(71, 85, 105)))
            using (SolidBrush badgeBg = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                string badgeStr = "2020 - 2026";
                SizeF badgeSize = g.MeasureString(badgeStr, badgeFont);
                float bx = Width - badgeSize.Width - 28;
                float by = 55;
                g.FillRectangle(badgeBg, bx - 6, by - 2, badgeSize.Width + 12, badgeSize.Height + 4);
                g.DrawString(badgeStr, badgeFont, badgeTextBrush, new PointF(bx, by));
            }

            // Horizontal Legend at y = 80
            float legendX = 26f;
            float legendY = 80f;
            using (Font legFont = new Font("Segoe UI", 7.5f, FontStyle.Bold)) {
                foreach (var s in seriesList) {
                    using (SolidBrush dotBrush = new SolidBrush(s.Color))
                    using (SolidBrush textBrush = new SolidBrush(Color.FromArgb(51, 65, 85))) {
                        g.FillEllipse(dotBrush, legendX, legendY + 2, 7, 7);
                        g.DrawString(s.Name, legFont, textBrush, new PointF(legendX + 10, legendY));
                        SizeF sz = g.MeasureString(s.Name, legFont);
                        legendX += sz.Width + 18f;
                    }
                }
            }

            // Gridlines & Y-Axis Labels
            double[] gridVals = new double[] { 0, 20, 40, 60 };
            using (Pen gridPen = new Pen(Color.FromArgb(226, 232, 240), 1) { DashStyle = DashStyle.Dash })
            using (Font axisFont = new Font("Segoe UI", 7.5f, FontStyle.Regular))
            using (SolidBrush axisBrush = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                foreach (var val in gridVals) {
                    float y = ValToY(val);
                    g.DrawLine(gridPen, PlotLeft, y, PlotRight, y);
                    string yLabel = string.Format("{0}%", (int)val);
                    SizeF sz = g.MeasureString(yLabel, axisFont);
                    g.DrawString(yLabel, axisFont, axisBrush, new PointF(PlotLeft - sz.Width - 6, y - sz.Height / 2));
                }
            }

            // X-Axis Baseline
            using (Pen axisLinePen = new Pen(Color.FromArgb(203, 213, 225), 1.2f)) {
                g.DrawLine(axisLinePen, PlotLeft, PlotBottom, PlotRight, PlotBottom);
            }

            // X-Axis Year Labels
            using (Font xFont = new Font("Segoe UI", 8.0f, FontStyle.Bold))
            using (SolidBrush xBrush = new SolidBrush(Color.FromArgb(51, 65, 85))) {
                for (int i = 0; i < Years.Length; i++) {
                    float x = YearToX(i);
                    using (Pen tickPen = new Pen(Color.FromArgb(203, 213, 225), 1.2f)) {
                        g.DrawLine(tickPen, x, PlotBottom, x, PlotBottom + 3);
                    }
                    string yr = Years[i];
                    SizeF sz = g.MeasureString(yr, xFont);
                    g.DrawString(yr, xFont, xBrush, new PointF(x - sz.Width / 2, PlotBottom + 5));
                }
            }

            // Draw Series Curves
            int maxIndex = Years.Length - 1; // 6
            float currentT = Math.Min(progress, (float)maxIndex);

            foreach (var series in seriesList) {
                List<PointF> linePoints = new List<PointF>();
                int fullYears = (int)Math.Floor(currentT);

                for (int i = 0; i <= fullYears; i++) {
                    linePoints.Add(new PointF(YearToX(i), ValToY(series.Values[i])));
                }

                if (currentT > fullYears && fullYears < maxIndex) {
                    float frac = currentT - fullYears;
                    double interpVal = series.Values[fullYears] + frac * (series.Values[fullYears + 1] - series.Values[fullYears]);
                    linePoints.Add(new PointF(YearToX(currentT), ValToY(interpVal)));
                }

                if (linePoints.Count >= 2) {
                    using (Pen linePen = new Pen(series.Color, 2.5f) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round }) {
                        g.DrawLines(linePen, linePoints.ToArray());
                    }
                }

                // Draw completed point dots
                for (int i = 0; i <= fullYears; i++) {
                    float px = YearToX(i);
                    float py = ValToY(series.Values[i]);
                    float r = 3.5f;

                    using (SolidBrush fillBrush = new SolidBrush(Color.White))
                    using (Pen borderPen = new Pen(series.Color, 2.0f)) {
                        g.FillEllipse(fillBrush, px - r, py - r, r * 2, r * 2);
                        g.DrawEllipse(borderPen, px - r, py - r, r * 2, r * 2);
                    }

                    if (isFinal) {
                        DrawPointLabel(g, series, i, px, py);
                    }
                }

                // Animation leading point & floating value tag
                if (!isFinal && linePoints.Count > 0) {
                    PointF head = linePoints[linePoints.Count - 1];
                    float hr = 4.5f;
                    using (SolidBrush headFill = new SolidBrush(series.Color)) {
                        g.FillEllipse(headFill, head.X - hr, head.Y - hr, hr * 2, hr * 2);
                    }

                    double curVal = series.Values[fullYears];
                    if (currentT > fullYears && fullYears < maxIndex) {
                        float frac = currentT - fullYears;
                        curVal = series.Values[fullYears] + frac * (series.Values[fullYears + 1] - series.Values[fullYears]);
                    }

                    using (Font valFont = new Font("Segoe UI", 7.0f, FontStyle.Bold))
                    using (SolidBrush valBrush = new SolidBrush(series.Color)) {
                        string valStr = string.Format("{0:0}%", curVal);
                        float tagY = head.Y - 14f;
                        if (tagY < PlotTop - 4) tagY = head.Y + 6f;
                        g.DrawString(valStr, valFont, valBrush, new PointF(head.X - 8, tagY));
                    }
                }
            }
        }
        return bmp;
    }

    private static void DrawPointLabel(Graphics g, SeriesData series, int yearIndex, float px, float py) {
        using (Font ptFont = new Font("Segoe UI", 7.5f, FontStyle.Bold))
        using (SolidBrush ptBrush = new SolidBrush(series.Color)) {
            string str = string.Format("{0}%", (int)series.Values[yearIndex]);
            SizeF sz = g.MeasureString(str, ptFont);

            float ty = py - sz.Height - 2;
            float tx = px - sz.Width / 2;

            if (series.Name.Contains("Energy")) {
                ty = py + 4;
            } else if (series.Name.Contains("Data") && yearIndex >= 4) {
                ty = py - sz.Height - 1;
            } else if (series.Name.Contains("R&D") && yearIndex == 6) {
                ty = py - sz.Height - 2;
            } else if (series.Name.Contains("Data Center") && yearIndex <= 2) {
                ty = py + 3;
            }

            g.DrawString(str, ptFont, ptBrush, new PointF(tx, ty));
        }
    }

    private static float YearToX(float yearIdx) {
        return PlotLeft + yearIdx * ((PlotRight - PlotLeft) / 6.0f);
    }

    private static float ValToY(double val) {
        float ratio = (float)(val / YMax);
        return PlotBottom - ratio * (PlotBottom - PlotTop);
    }
}
'@

Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies System.Drawing

$seriesList = New-Object 'System.Collections.Generic.List[SeriesData]'
$seriesList.Add((New-Object SeriesData("R&D Staff", "#2ca02c", [double[]]@(48, 40, 32, 23, 16, 11, 8))))
$seriesList.Add((New-Object SeriesData("Data & RLHF", "#9467bd", [double[]]@(10, 10, 9, 7, 5, 3, 3))))
$seriesList.Add((New-Object SeriesData("Chips", "#1f77b4", [double[]]@(30, 35, 42, 50, 57, 63, 65))))
$seriesList.Add((New-Object SeriesData("Data Center Infra", "#ff7f0e", [double[]]@(10, 12, 14, 16, 18, 19, 20))))
$seriesList.Add((New-Object SeriesData("Energy", "#d62728", [double[]]@(2, 3, 3, 4, 4, 4, 4))))

$assetsDir = Join-Path $PSScriptRoot "assets"
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir | Out-Null
}

$outputPath = Join-Path $assetsDir "social_preview.gif"

Write-Host "Generating animated GIF to $outputPath..."

$palette = [PaletteBuilder]::BuildMasterPalette()
$fs = [System.IO.File]::Create($outputPath)
$encoder = New-Object GifEncoder
$encoder.Start($fs, 640, 320, $palette)

# Progression frames: 0.0 to 6.0 (36 steps, ~70ms each = 2.5s animation)
$steps = 36
for ($i = 0; $i -le $steps; $i++) {
    $progress = ($i / [float]$steps) * 6.0
    $isFinal = ($i -eq $steps)
    $bmp = [BannerRenderer]::RenderFrame($seriesList, $progress, $isFinal)
    
    if ($isFinal) {
        # Hold final frame for 2.4s (12 frames x 200ms)
        for ($h = 0; $h -lt 12; $h++) {
            $encoder.AddFrame($bmp, 200)
        }
    } else {
        $encoder.AddFrame($bmp, 70)
    }
    $bmp.Dispose()
}

$encoder.Finish()
$fs.Close()
$fs.Dispose()

$fileInfo = Get-Item $outputPath
$fileSizeKB = [math]::Round($fileInfo.Length / 1024, 2)
$fileSizeMB = [math]::Round($fileInfo.Length / (1024 * 1024), 2)

Write-Host "Generated $outputPath"
Write-Host "File size: $fileSizeKB KB ($fileSizeMB MB)"
