import 'package:flutter/material.dart';

class FaceOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final faceWidth = size.width * 0.75;
    final faceHeight = size.height * 0.55;

    // 1. Layer: Semi-transparent background
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.7);
    
    // Create a path for the screen
    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create a path for the Face Oval (The "Hole")
    final facePath = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(centerX, centerY), 
          width: faceWidth, 
          height: faceHeight
      ));

    // Combine: Result is Screen minus FaceHole
    final holePath = Path.combine(
      PathOperation.difference,
      screenPath,
      facePath,
    );

    canvas.drawPath(holePath, bgPaint);

    // 2. Layer: Border for the face oval
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(centerX, centerY), 
          width: faceWidth, 
          height: faceHeight
      ),
      borderPaint,
    );

    // 3. Optional: Guide Text
    // Not drawing text here to keep it flexible, standard Widgets can overlay text.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
