import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:logbook_app_001/features/image_processing/image_processing_view.dart';
import 'package:logbook_app_001/features/vision/damage_painter.dart';
import 'package:logbook_app_001/features/vision/vision_controller.dart';

class VisionView extends StatefulWidget {
  const VisionView({super.key});

  @override
  State<VisionView> createState() => _VisionViewState();
}

class _VisionViewState extends State<VisionView> {
  late VisionController _visionController;

  Future<void> _openPcdFromVision() async {
    final bytes = await _visionController.captureImageBytesForPcd();
    if (!mounted) {
      return;
    }

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengambil gambar. Coba ulangi lagi.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageProcessingView(
          initialImageBytes: bytes,
          initialStatusMessage:
              'Gambar dari Smart Vision siap untuk manipulasi PCD.',
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _visionController.ensureCameraReady();
  }

  @override
  void initState() {
    super.initState();
    _visionController = VisionController();
  }

  @override
  void dispose() {
    _visionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Patrol Vision')),
      body: ListenableBuilder(
        listenable: _visionController,
        builder: (context, child) {
          if (_visionController.hasCameraAccessDenied) {
            return _buildNoCameraAccessState();
          }

          if (_visionController.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _visionController.errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _visionController.initCamera(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_visionController.isInitializing ||
              !_visionController.isInitialized ||
              _visionController.controller == null) {
            return _buildLoadingState();
          }

          return _buildVisionStack();
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Menghubungkan ke Sensor Visual...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Mohon tunggu sebentar, kamera sedang dipersiapkan untuk inspeksi jalan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCameraAccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_off,
                size: 48,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Camera Access',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Akses kamera diperlukan untuk menampilkan preview dan menjalankan deteksi visual. Buka Settings lalu aktifkan izin kamera.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _visionController.openAppSettingsPage,
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisionStack() {
    final cameraController = _visionController.controller;
    if (cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final previewSize = cameraController.value.previewSize;
    if (previewSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewSize.height,
              height: previewSize.width,
              child: CameraPreview(cameraController),
            ),
          ),
        ),
        if (_visionController.isOverlayEnabled)
          Positioned.fill(
            child: CustomPaint(
              painter: DamagePainter(results: _visionController.currentResults),
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          top: 16,
          child: SafeArea(bottom: false, child: _buildVisionHud()),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(top: false, child: _buildControlBar()),
        ),
      ],
    );
  }

  Widget _buildVisionHud() {
    final detections = _visionController.currentResults;
    final hasDetection = detections.isNotEmpty;
    final active = hasDetection ? detections.first : null;
    final statusText = hasDetection
        ? '${active!.label} • ${(active.score * 100).round()}%'
        : 'Belum ada target';

    return Row(
      children: [
        Expanded(
          child: _buildHudChip(
            icon: Icons.track_changes,
            title: 'Mode',
            value: 'Live Tracking',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildHudChip(
            icon: hasDetection ? Icons.check_circle : Icons.search,
            title: 'Deteksi',
            value: statusText,
            valueColor: hasDetection ? Colors.lightGreenAccent : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildHudChip({
    required IconData icon,
    required String title,
    required String value,
    Color valueColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _visionController.isCapturing
                  ? null
                  : _openPcdFromVision,
              icon: _visionController.isCapturing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(
                _visionController.isCapturing
                    ? 'Mengambil Gambar...'
                    : 'Capture & Edit Gambar',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _visionController.isTorchEnabled
                          ? Icons.flash_on
                          : Icons.flash_off,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Flashlight',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _visionController.isTorchEnabled,
                      onChanged: (_) => _visionController.toggleTorch(),
                      activeColor: Colors.amberAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.layers, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Overlay',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _visionController.isOverlayEnabled,
                      onChanged: _visionController.setOverlayEnabled,
                      activeColor: Colors.lightBlueAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
