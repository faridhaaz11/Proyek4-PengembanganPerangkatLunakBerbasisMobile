import 'package:flutter/material.dart';

class DetectionResult {
  final Rect box;
  final String label;
  final double score;

  const DetectionResult({
    required this.box,
    required this.label,
    required this.score,
  });
}
