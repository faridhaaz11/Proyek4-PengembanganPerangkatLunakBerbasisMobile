import 'package:flutter/material.dart';
import 'package:logbook_app_001/features/vision/detection_result.dart';

class DamagePainter extends CustomPainter {
  final List<DetectionResult> results;

  const DamagePainter({this.results = const []});

  Color _brandColorForLabel(String label) {
    final normalizedLabel = label.toUpperCase();

    if (normalizedLabel.contains('D40') ||
        normalizedLabel.contains('POTHOLE')) {
      return Colors.redAccent;
    }

    if (normalizedLabel.contains('D00') ||
        normalizedLabel.contains('CRACK') ||
        normalizedLabel.contains('LONGITUDINAL')) {
      return Colors.amberAccent;
    }

    return Colors.orangeAccent;
  }

  void _paintOutlinedLabel(
    Canvas canvas,
    TextPainter painter,
    Offset offset,
    Color fillColor,
  ) {
    final labelRect = offset & painter.size;
    final roundedRect = RRect.fromRectAndRadius(
      labelRect.inflate(4),
      const Radius.circular(8),
    );

    canvas.drawRRect(
      roundedRect,
      Paint()
        ..color = fillColor.withValues(alpha: 0.92)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5),
    );

    canvas.drawRRect(
      roundedRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    painter.paint(canvas, offset);
  }

  void _paintCenterSearchingLabel(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: ' Searching for Road Damage... ',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height / 2) + 28,
    );

    _paintOutlinedLabel(
      canvas,
      textPainter,
      offset,
      Colors.black.withValues(alpha: 0.55),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final plusLength = size.shortestSide * 0.035;

    canvas.drawLine(
      Offset(centerX - plusLength, centerY),
      Offset(centerX + plusLength, centerY),
      centerPaint,
    );
    canvas.drawLine(
      Offset(centerX, centerY - plusLength),
      Offset(centerX, centerY + plusLength),
      centerPaint,
    );

    if (results.isEmpty) {
      _paintCenterSearchingLabel(canvas, size);
      return;
    }

    final activeDetections = results.isEmpty ? const [] : results;

    for (final entry in activeDetections.asMap().entries) {
      final index = entry.key;
      final result = entry.value;
      final detectionColor = _brandColorForLabel(result.label);
      final frameColor = index == 0
          ? detectionColor.withValues(alpha: 0.95)
          : detectionColor.withValues(alpha: 0.65);
      final strokeWidth = index == 0 ? 2.7 : 2.0;
      final detectionRect = Rect.fromLTWH(
        result.box.left * size.width,
        result.box.top * size.height,
        result.box.width * size.width,
        result.box.height * size.height,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(detectionRect, const Radius.circular(10)),
        Paint()
          ..color = frameColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke,
      );

      final detectionText = TextPainter(
        text: TextSpan(
          text:
              ' ${index + 1}. ${result.label} - ${(result.score * 100).round()}% ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black87,
                offset: Offset(0.8, 0.8),
                blurRadius: 2.5,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelOffset = detectionRect.top - detectionText.height - 8 < 0
          ? Offset(detectionRect.left, detectionRect.bottom + 6)
          : Offset(
              detectionRect.left,
              detectionRect.top - detectionText.height - 6,
            );
      _paintOutlinedLabel(canvas, detectionText, labelOffset, detectionColor);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is DamagePainter && oldDelegate.results != results;
  }
}
