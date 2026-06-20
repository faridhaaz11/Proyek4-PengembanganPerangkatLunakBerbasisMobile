import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:logbook_app_001/features/vision/detection_result.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:permission_handler/permission_handler.dart';

class VisionController extends ChangeNotifier with WidgetsBindingObserver {
  CameraController? controller;
  bool isInitialized = false;
  String? errorMessage;
  bool isProcessing = false;
  bool _hasCameraAccessDenied = false;
  bool _isTorchEnabled = false;
  bool _isOverlayEnabled = true;
  List<DetectionResult> _currentResults = const [];
  bool _isDisposed = false;
  bool _isInitializing = false;
  bool _isStreamingImages = false;
  bool _isCapturing = false;
  int _frameCounter = 0;
  Rect? _lastTrackedBox;
  Rect? _secondaryTrackedBox;
  String _lastTrackedLabel = 'D00';
  String _secondaryTrackedLabel = 'D00';
  double _secondaryTrackedScore = 0.0;
  int _stableTrackingFrames = 0;
  int _missedTrackingFrames = 0;
  int _secondaryStableTrackingFrames = 0;
  int _secondaryMissedTrackingFrames = 0;

  static const double _trackingDistanceWeight = 132.0;
  static const double _centerBiasWeight = 22.0;
  static const double _maxTrackDistanceSquared = 0.06 * 0.06;
  static const int _maxMissedFramesToHold = 6;
  static const double _detectionBoxWidth = 0.37;
  static const double _detectionBoxHeight = 0.24;
  static const double _secondaryTrackDistanceSquared = 0.03 * 0.03;
  static const double _secondaryTrackWeight = 220.0;
  static const int _secondaryMaxMissedFramesToHold = 10;
  static const double _secondaryMinSeparationSquared = 0.28 * 0.28;
  static const double _secondaryDistanceRewardWeight = 92.0;
  static const double _secondaryCornernessWeight = 1.25;
  static const double _secondaryMinCornerness = 8.0;
  static const int _secondaryReacquireAfterMisses = 5;
  static const double _secondaryMaxStepDistanceSquared = 0.11 * 0.11;

  VisionController() {
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  Future<void> initCamera() async {
    if (_isDisposed || _isInitializing) {
      return;
    }

    _isInitializing = true;
    try {
      final permissionStatus = await Permission.camera.request();
      if (_isDisposed) {
        return;
      }

      if (!permissionStatus.isGranted) {
        controller = null;
        isInitialized = false;
        _hasCameraAccessDenied = true;
        errorMessage = permissionStatus.isPermanentlyDenied
            ? 'No Camera Access'
            : 'No Camera Access';
        notifyListeners();
        return;
      }

      final cameras = await availableCameras();
      if (_isDisposed) {
        return;
      }

      if (cameras.isEmpty) {
        errorMessage = 'No camera detected on device.';
        isInitialized = false;
        notifyListeners();
        return;
      }

      await controller?.dispose();
      controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller!.initialize();
      if (_isTorchEnabled) {
        await _applyTorchState(controller!, enabled: true);
      }

      await _startImageStream();

      isInitialized = true;
      _hasCameraAccessDenied = false;
      errorMessage = null;
      _currentResults = const [];
    } catch (e) {
      errorMessage = 'Failed to initialize camera: $e';
      isInitialized = false;
    } finally {
      _isInitializing = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  List<DetectionResult> get currentResults => _currentResults;

  bool get isTorchEnabled => _isTorchEnabled;

  bool get isOverlayEnabled => _isOverlayEnabled;

  bool get isInitializing => _isInitializing;

  bool get hasCameraAccessDenied => _hasCameraAccessDenied;

  bool get isCapturing => _isCapturing;

  Future<void> ensureCameraReady() async {
    if (_isDisposed) {
      return;
    }

    final cameraController = controller;
    final hasReadyCamera =
        cameraController != null &&
        cameraController.value.isInitialized &&
        isInitialized;

    if (hasReadyCamera) {
      if (!_isStreamingImages) {
        await _startImageStream();
      }
      return;
    }

    await initCamera();
  }

  Future<Uint8List?> captureImageBytesForPcd() async {
    final cameraController = controller;
    if (_isDisposed ||
        _isCapturing ||
        cameraController == null ||
        !cameraController.value.isInitialized) {
      return null;
    }

    _isCapturing = true;
    notifyListeners();
    final shouldRestartStream = _isStreamingImages;

    try {
      if (shouldRestartStream) {
        await _stopImageStream();
      }

      final capture = await cameraController.takePicture();
      final bytes = await capture.readAsBytes();
      return bytes;
    } catch (e) {
      LogHelper.writeLog(
        'Capture image for PCD failed: $e',
        source: 'vision_controller.dart',
        level: 2,
      );
      return null;
    } finally {
      if (!_isDisposed && shouldRestartStream) {
        await _startImageStream();
      }

      if (!_isDisposed) {
        _isCapturing = false;
        notifyListeners();
      }
    }
  }

  Future<void> openAppSettingsPage() async {
    if (_isDisposed) {
      return;
    }

    await openAppSettings();
  }

  Future<void> toggleTorch() async {
    final cameraController = controller;
    if (_isDisposed ||
        cameraController == null ||
        !cameraController.value.isInitialized) {
      return;
    }

    final nextEnabled = !_isTorchEnabled;
    try {
      await _applyTorchState(cameraController, enabled: nextEnabled);
      _isTorchEnabled = nextEnabled;
      notifyListeners();
    } catch (e) {
      _isTorchEnabled = false;
      LogHelper.writeLog(
        'Torch toggle failed: $e',
        source: 'vision_controller.dart',
        level: 2,
      );
      notifyListeners();
    }
  }

  void setOverlayEnabled(bool enabled) {
    if (_isDisposed || _isOverlayEnabled == enabled) {
      return;
    }

    _isOverlayEnabled = enabled;
    notifyListeners();
  }

  Future<void> _applyTorchState(
    CameraController cameraController, {
    required bool enabled,
  }) async {
    await cameraController.setFlashMode(
      enabled ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _startImageStream() async {
    final cameraController = controller;
    if (_isDisposed ||
        cameraController == null ||
        !cameraController.value.isInitialized ||
        _isStreamingImages) {
      return;
    }

    await cameraController.startImageStream(_onCameraFrame);
    _isStreamingImages = true;
  }

  Future<void> _stopImageStream() async {
    final cameraController = controller;
    if (cameraController == null || !_isStreamingImages) {
      return;
    }

    try {
      await cameraController.stopImageStream();
    } catch (_) {
      // Camera may already be disposed by lifecycle transitions.
    } finally {
      _isStreamingImages = false;
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_isDisposed || !isInitialized || isProcessing) {
      return;
    }

    _frameCounter += 1;
    if (_frameCounter % 4 != 0) {
      return;
    }

    unawaited(processFrame(image));
  }

  Future<void> processFrame(CameraImage image) async {
    if (_isDisposed || isProcessing) {
      return;
    }

    isProcessing = true;
    try {
      final detections = _detectCandidatesFromLuma(image);
      if (_isDisposed) {
        return;
      }

      if (detections.isNotEmpty) {
        _currentResults = detections;
        final primary = detections.first;
        LogHelper.writeLog(
          'LiveDetection: label=${primary.label} score=${(primary.score * 100).round()} '
          'box=${primary.box.left.toStringAsFixed(2)},${primary.box.top.toStringAsFixed(2)} '
          '${primary.box.width.toStringAsFixed(2)}x${primary.box.height.toStringAsFixed(2)} '
          'candidates=${detections.length}',
          source: 'vision_controller.dart',
          level: 2,
        );
      } else {
        _currentResults = const [];
      }

      notifyListeners();
    } finally {
      isProcessing = false;
    }
  }

  List<DetectionResult> _detectCandidatesFromLuma(CameraImage image) {
    if (image.planes.isEmpty) {
      return const [];
    }

    final lumaPlane = image.planes.first;
    final bytes = lumaPlane.bytes;
    final width = image.width;
    final height = image.height;
    if (bytes.isEmpty || width <= 0 || height <= 0) {
      return const [];
    }

    final bytesPerRow = lumaPlane.bytesPerRow;
    final stepX = (width / 44).floor().clamp(6, 24);
    final stepY = (height / 56).floor().clamp(6, 20);
    final frameCenterX = width / 2.0;
    final frameCenterY = height / 2.0;

    final candidates = <_LumaCandidate>[];

    for (int y = stepY; y < height - stepY; y += stepY) {
      final rowOffset = y * bytesPerRow;
      for (int x = stepX; x < width - stepX; x += stepX) {
        final center = bytes[rowOffset + x];

        final right = bytes[rowOffset + x + stepX ~/ 2];
        final left = bytes[rowOffset + x - stepX ~/ 2];
        final up = bytes[(y - stepY ~/ 2) * bytesPerRow + x];
        final down = bytes[(y + stepY ~/ 2) * bytesPerRow + x];

        final surroundingAvg = (right + left + up + down) / 4.0;
        final contrast = (surroundingAvg - center).clamp(0, 255).toDouble();
        final darkness = (255 - center).toDouble();
        final horizontalEdge = (right - left).abs().toDouble();
        final verticalEdge = (up - down).abs().toDouble();
        final cornerness = horizontalEdge < verticalEdge
            ? horizontalEdge
            : verticalEdge;
        final dx = (x - frameCenterX).abs() / width;
        final dy = (y - frameCenterY).abs() / height;
        final centerPenalty = (dx * dx + dy * dy) * _centerBiasWeight;
        final candidateScore =
            (contrast * 0.72) + (darkness * 0.28) - centerPenalty;

        if (contrast > 10 && candidateScore > 14) {
          candidates.add(
            _LumaCandidate(
              x: x,
              y: y,
              score: candidateScore,
              luma: center,
              contrast: contrast,
              cornerness: cornerness,
            ),
          );
        }
      }
    }

    if (candidates.isEmpty) {
      if (_lastTrackedBox != null &&
          _missedTrackingFrames < _maxMissedFramesToHold) {
        _missedTrackingFrames += 1;
        final primary = DetectionResult(
          box: _lastTrackedBox!,
          label: _lastTrackedLabel,
          score: (0.56 - (_missedTrackingFrames * 0.04)).clamp(0.40, 0.56),
        );

        final secondary = _secondaryTrackedBox == null
            ? null
            : DetectionResult(
                box: _secondaryTrackedBox!,
                label: _secondaryTrackedLabel,
                score: (0.48 - (_secondaryMissedTrackingFrames * 0.03)).clamp(
                  0.35,
                  0.48,
                ),
              );

        return secondary == null ? [primary] : [primary, secondary];
      }

      _lastTrackedBox = null;
      _stableTrackingFrames = 0;
      _missedTrackingFrames = 0;
      _secondaryTrackedBox = null;
      _secondaryStableTrackingFrames = 0;
      _secondaryMissedTrackingFrames = 0;
      _secondaryTrackedScore = 0.0;
      return const [];
    }

    final bestGlobal = _pickBestByScore(candidates);
    final previous = _lastTrackedBox;
    _LumaCandidate chosen = bestGlobal;

    if (previous != null) {
      final previousCenter = previous.center;
      final localBest = _pickBestNearTrack(
        candidates,
        previousCenter,
        width.toDouble(),
        height.toDouble(),
      );

      if (localBest != null) {
        chosen = localBest;
      }
    }

    const boxWidth = _detectionBoxWidth;
    const boxHeight = _detectionBoxHeight;

    final centerX = chosen.x / width;
    final centerY = chosen.y / height;

    final rawLeft = (centerX - (boxWidth / 2)).clamp(0.0, 1.0 - boxWidth);
    final rawTop = (centerY - (boxHeight / 2)).clamp(0.0, 1.0 - boxHeight);

    var box = Rect.fromLTWH(rawLeft, rawTop, boxWidth, boxHeight);
    if (previous != null) {
      box = Rect.lerp(previous, box, 0.16)!;
    }

    _missedTrackingFrames = 0;
    _stableTrackingFrames = previous == null
        ? 1
        : (_stableTrackingFrames + 1).clamp(1, 9999);
    _lastTrackedBox = box;

    final heavyDamage = chosen.luma < 78 || chosen.contrast > 28;
    final confidence = (chosen.score / 100.0).clamp(0.60, 0.96);
    _lastTrackedLabel = heavyDamage ? 'D40' : 'D00';

    final primary = DetectionResult(
      box: box,
      label: _lastTrackedLabel,
      score: confidence,
    );

    final secondary = _pickSecondaryDetection(
      candidates: candidates,
      primary: chosen,
      width: width.toDouble(),
      height: height.toDouble(),
    );

    if (secondary != null) {
      if (_secondaryTrackedBox != null) {
        _secondaryTrackedBox = Rect.lerp(
          _secondaryTrackedBox,
          secondary.box,
          0.08,
        )!;
      } else {
        _secondaryTrackedBox = secondary.box;
      }
      _secondaryTrackedLabel = secondary.label;
      _secondaryTrackedScore = secondary.score;
      _secondaryMissedTrackingFrames = 0;
      _secondaryStableTrackingFrames = _secondaryTrackedBox == null
          ? 1
          : (_secondaryStableTrackingFrames + 1).clamp(1, 9999);
    } else if (_secondaryTrackedBox != null &&
        _secondaryMissedTrackingFrames < _secondaryMaxMissedFramesToHold) {
      _secondaryMissedTrackingFrames += 1;
      return [
        primary,
        DetectionResult(
          box: _secondaryTrackedBox!,
          label: _secondaryTrackedLabel,
          score: (0.46 - (_secondaryMissedTrackingFrames * 0.03)).clamp(
            0.33,
            0.46,
          ),
        ),
      ];
    } else {
      _secondaryTrackedBox = null;
      _secondaryStableTrackingFrames = 0;
      _secondaryMissedTrackingFrames = 0;
      _secondaryTrackedScore = 0.0;
    }

    return secondary == null ? [primary] : [primary, secondary];
  }

  DetectionResult? _pickSecondaryDetection({
    required List<_LumaCandidate> candidates,
    required _LumaCandidate primary,
    required double width,
    required double height,
  }) {
    final previousSecondary = _secondaryTrackedBox;

    if (previousSecondary != null) {
      if (_secondaryStableTrackingFrames < 3) {
        return null;
      }

      final lockedCandidate = _pickBestNearTrack(
        candidates,
        previousSecondary.center,
        width,
        height,
        maxDistanceSquared: _secondaryTrackDistanceSquared,
        distanceWeight: _secondaryTrackWeight,
      );

      if (lockedCandidate != null &&
          _normalizedDistanceSquared(
                lockedCandidate.x / width,
                lockedCandidate.y / height,
                primary.x / width,
                primary.y / height,
              ) >=
              _secondaryMinSeparationSquared) {
        if (lockedCandidate.cornerness >= _secondaryMinCornerness) {
          final movementFromPrevious = _normalizedDistanceSquared(
            lockedCandidate.x / width,
            lockedCandidate.y / height,
            previousSecondary.center.dx,
            previousSecondary.center.dy,
          );

          if (movementFromPrevious <= _secondaryMaxStepDistanceSquared &&
              (_secondaryTrackedScore <= 0.0 ||
                  lockedCandidate.score >= (_secondaryTrackedScore * 0.98))) {
            return _candidateToDetection(lockedCandidate, width, height);
          }
        }
      }

      if (_secondaryMissedTrackingFrames < _secondaryReacquireAfterMisses) {
        return null;
      }
    }

    _LumaCandidate? best;
    double bestScore = -1;

    for (final candidate in candidates) {
      if (candidate.x == primary.x && candidate.y == primary.y) {
        continue;
      }

      final distanceSquared = _normalizedDistanceSquared(
        candidate.x / width,
        candidate.y / height,
        primary.x / width,
        primary.y / height,
      );

      if (distanceSquared < _secondaryMinSeparationSquared) {
        continue;
      }

      if (candidate.cornerness < _secondaryMinCornerness) {
        continue;
      }

      final weightedScore =
          candidate.score +
          (distanceSquared * _secondaryDistanceRewardWeight) +
          (candidate.cornerness * _secondaryCornernessWeight);
      if (weightedScore > bestScore) {
        bestScore = weightedScore;
        best = candidate;
      }
    }

    if (best == null) {
      return null;
    }

    return _candidateToDetection(best, width, height);
  }

  DetectionResult _candidateToDetection(
    _LumaCandidate candidate,
    double width,
    double height,
  ) {
    const boxWidth = _detectionBoxWidth;
    const boxHeight = _detectionBoxHeight;
    final centerX = candidate.x / width;
    final centerY = candidate.y / height;
    final rawLeft = (centerX - (boxWidth / 2)).clamp(0.0, 1.0 - boxWidth);
    final rawTop = (centerY - (boxHeight / 2)).clamp(0.0, 1.0 - boxHeight);
    final box = Rect.fromLTWH(rawLeft, rawTop, boxWidth, boxHeight);
    final confidence = (candidate.score / 100.0).clamp(0.50, 0.88);
    final label = candidate.luma < 78 || candidate.contrast > 28
        ? 'D40'
        : 'D00';

    return DetectionResult(box: box, label: label, score: confidence);
  }

  _LumaCandidate _pickBestByScore(List<_LumaCandidate> candidates) {
    var best = candidates.first;
    for (final candidate in candidates.skip(1)) {
      if (candidate.score > best.score) {
        best = candidate;
      }
    }
    return best;
  }

  _LumaCandidate? _pickBestNearTrack(
    List<_LumaCandidate> candidates,
    Offset previousCenter,
    double width,
    double height, {
    double maxDistanceSquared = _maxTrackDistanceSquared,
    double distanceWeight = _trackingDistanceWeight,
  }) {
    _LumaCandidate? best;
    double bestWeightedScore = -1;

    for (final candidate in candidates) {
      final distanceSquared = _normalizedDistanceSquared(
        candidate.x / width,
        candidate.y / height,
        previousCenter.dx,
        previousCenter.dy,
      );
      if (distanceSquared > maxDistanceSquared) {
        continue;
      }

      final weightedScore =
          candidate.score - (distanceSquared * distanceWeight);
      if (weightedScore > bestWeightedScore) {
        bestWeightedScore = weightedScore;
        best = candidate;
      }
    }

    return best;
  }

  double _normalizedDistanceSquared(
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return (dx * dx) + (dy * dy);
  }

  void updateDetections(List<DetectionResult> results) {
    if (_isDisposed) {
      return;
    }

    _currentResults = results;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_stopImageStream());
      _isTorchEnabled = false;
      _hasCameraAccessDenied = false;
      _lastTrackedBox = null;
      _stableTrackingFrames = 0;
      _missedTrackingFrames = 0;
      cameraController.dispose();
      controller = null;
      isInitialized = false;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      initCamera();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopImageStream());
    controller?.dispose();
    controller = null;
    super.dispose();
  }
}

class _LumaCandidate {
  const _LumaCandidate({
    required this.x,
    required this.y,
    required this.score,
    required this.luma,
    required this.contrast,
    required this.cornerness,
  });

  final int x;
  final int y;
  final double score;
  final int luma;
  final double contrast;
  final double cornerness;
}
