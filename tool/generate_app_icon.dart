import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  const size = 1024;
  const margin = 96;
  const topBarH = 220;
  const ringR = 22;
  const dotR = 28;
  const dotSpacing = 80;

  final outPath = 'assets/icons/app_icon.png';

  // Colors
  final white = img.ColorRgb8(255, 255, 255);
  final gray = img.ColorRgb8(200, 200, 200);
  final blue = img.ColorRgb8(33, 150, 243); // Material blue 500
  final lightGray = img.ColorRgb8(230, 230, 230);

  // Create base image (white background)
  final canvas = img.Image(width: size, height: size);
  img.fill(canvas, color: white);

  // Card bounds
  final left = margin;
  final top = margin;
  final right = size - margin;
  final bottom = size - margin;

  // Card body
  img.fillRect(canvas, x1: left, y1: top, x2: right, y2: bottom, color: white);
  // Card border
  img.drawRect(canvas, x1: left, y1: top, x2: right, y2: bottom, color: gray);

  // Top bar
  img.fillRect(
    canvas,
    x1: left,
    y1: top,
    x2: right,
    y2: top + topBarH,
    color: blue,
  );

  // Rings (binding circles)
  final ringY = top + topBarH - 40;
  final ringX1 = left + 140;
  final ringX2 = right - 140;
  img.fillCircle(canvas, x: ringX1, y: ringY, radius: ringR, color: white);
  img.fillCircle(canvas, x: ringX2, y: ringY, radius: ringR, color: white);

  // Three dots in center ("Nur noch...")
  final centerY = top + topBarH + ((bottom - top - topBarH) ~/ 2) + 60;
  final centerX = size ~/ 2;
  img.fillCircle(
    canvas,
    x: centerX - dotSpacing,
    y: centerY,
    radius: dotR,
    color: blue,
  );
  img.fillCircle(canvas, x: centerX, y: centerY, radius: dotR, color: blue);
  img.fillCircle(
    canvas,
    x: centerX + dotSpacing,
    y: centerY,
    radius: dotR,
    color: blue,
  );

  // Subtle lines
  final rowTop = top + topBarH + 120;
  final rowLeft = left + 140;
  final rowRight = right - 140;
  img.fillRect(
    canvas,
    x1: rowLeft,
    y1: rowTop,
    x2: rowRight,
    y2: rowTop + 8,
    color: lightGray,
  );
  img.fillRect(
    canvas,
    x1: rowLeft,
    y1: rowTop + 60,
    x2: rowRight,
    y2: rowTop + 68,
    color: lightGray,
  );

  // Save
  final png = img.encodePng(canvas);
  await File(outPath).create(recursive: true);
  await File(outPath).writeAsBytes(png);
  stdout.writeln('Wrote $outPath (${png.length} bytes)');
}
