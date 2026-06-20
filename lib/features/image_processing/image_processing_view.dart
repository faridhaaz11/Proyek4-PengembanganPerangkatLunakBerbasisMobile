import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ImageProcessingView extends StatefulWidget {
  const ImageProcessingView({
    super.key,
    this.initialImageBytes,
    this.initialStatusMessage,
  });

  final Uint8List? initialImageBytes;
  final String? initialStatusMessage;

  @override
  State<ImageProcessingView> createState() => _ImageProcessingViewState();
}

Uint8List _processPcdImage(Map<String, dynamic> request) {
  final sourceBytes = request['bytes'] as Uint8List;
  final brightnessDelta = request['brightness'] as int;
  final contrast = request['contrast'] as double;
  final grayscaleEnabled = request['grayscale'] as bool;
  final invertEnabled = request['invert'] as bool;
  final thresholdEnabled = request['thresholdEnabled'] as bool;
  final threshold = request['threshold'] as int;
  final equalizeHistogram = request['equalizeHistogram'] as bool;
  final convolution = request['convolution'] as String;
  final maxWidth = request['maxWidth'] as int;

  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    return sourceBytes;
  }

  final workingImage = decoded.width > maxWidth
      ? img.copyResize(decoded, width: maxWidth)
      : img.Image.from(decoded);

  if (equalizeHistogram) {
    _applyHistogramEqualization(workingImage);
  }

  for (var y = 0; y < workingImage.height; y++) {
    for (var x = 0; x < workingImage.width; x++) {
      final pixel = workingImage.getPixel(x, y);
      var red = pixel.r.toInt();
      var green = pixel.g.toInt();
      var blue = pixel.b.toInt();

      if (grayscaleEnabled) {
        final gray = ((red + green + blue) / 3).round();
        red = gray;
        green = gray;
        blue = gray;
      }

      if (thresholdEnabled) {
        final luminance = ((red + green + blue) / 3).round();
        final bw = luminance >= threshold ? 255 : 0;
        red = bw;
        green = bw;
        blue = bw;
      }

      if (invertEnabled) {
        red = 255 - red;
        green = 255 - green;
        blue = 255 - blue;
      }

      red = ((red - 128) * contrast + 128).round();
      green = ((green - 128) * contrast + 128).round();
      blue = ((blue - 128) * contrast + 128).round();

      red = (red + brightnessDelta).clamp(0, 255);
      green = (green + brightnessDelta).clamp(0, 255);
      blue = (blue + brightnessDelta).clamp(0, 255);

      workingImage.setPixelRgba(x, y, red, green, blue, pixel.a.toInt());
    }
  }

  if (convolution != 'none') {
    _applyConvolutionFilter(workingImage, convolution);
  }

  return Uint8List.fromList(img.encodePng(workingImage));
}

void _applyHistogramEqualization(img.Image image) {
  final histogram = List<int>.filled(256, 0);
  final total = image.width * image.height;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final lum = ((p.r + p.g + p.b) / 3).round().clamp(0, 255);
      histogram[lum] += 1;
    }
  }

  final cdf = List<int>.filled(256, 0);
  cdf[0] = histogram[0];
  for (var i = 1; i < 256; i++) {
    cdf[i] = cdf[i - 1] + histogram[i];
  }

  var cdfMin = 0;
  for (var i = 0; i < 256; i++) {
    if (cdf[i] != 0) {
      cdfMin = cdf[i];
      break;
    }
  }

  if (total <= cdfMin) {
    return;
  }

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final red = p.r.toInt();
      final green = p.g.toInt();
      final blue = p.b.toInt();
      final alpha = p.a.toInt();

      final lum = ((red + green + blue) / 3).round().clamp(0, 255);
      final eqLum = (((cdf[lum] - cdfMin) / (total - cdfMin)) * 255)
          .round()
          .clamp(0, 255);

      final ratio = lum == 0 ? 0.0 : eqLum / lum;
      image.setPixelRgba(
        x,
        y,
        (red * ratio).round().clamp(0, 255),
        (green * ratio).round().clamp(0, 255),
        (blue * ratio).round().clamp(0, 255),
        alpha,
      );
    }
  }
}

void _applyConvolutionFilter(img.Image image, String filterName) {
  List<double> kernel;
  double divisor;

  switch (filterName) {
    case 'blur':
      kernel = [1, 1, 1, 1, 1, 1, 1, 1, 1];
      divisor = 9;
      break;
    case 'sharpen':
      kernel = [0, -1, 0, -1, 5, -1, 0, -1, 0];
      divisor = 1;
      break;
    case 'edge':
      kernel = [-1, -1, -1, -1, 8, -1, -1, -1, -1];
      divisor = 1;
      break;
    default:
      return;
  }

  final source = img.Image.from(image);
  for (var y = 1; y < image.height - 1; y++) {
    for (var x = 1; x < image.width - 1; x++) {
      double r = 0;
      double g = 0;
      double b = 0;

      var index = 0;
      for (var ky = -1; ky <= 1; ky++) {
        for (var kx = -1; kx <= 1; kx++) {
          final pixel = source.getPixel(x + kx, y + ky);
          final w = kernel[index++];
          r += pixel.r * w;
          g += pixel.g * w;
          b += pixel.b * w;
        }
      }

      final base = source.getPixel(x, y);
      image.setPixelRgba(
        x,
        y,
        (r / divisor).round().clamp(0, 255),
        (g / divisor).round().clamp(0, 255),
        (b / divisor).round().clamp(0, 255),
        base.a.toInt(),
      );
    }
  }
}

List<int> _computeLuminanceHistogram(Uint8List imageBytes) {
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) {
    return List<int>.filled(256, 0);
  }

  final histogram = List<int>.filled(256, 0);
  for (var y = 0; y < decoded.height; y++) {
    for (var x = 0; x < decoded.width; x++) {
      final pixel = decoded.getPixel(x, y);
      final luminance = ((pixel.r + pixel.g + pixel.b) / 3).round().clamp(
        0,
        255,
      );
      histogram[luminance] += 1;
    }
  }
  return histogram;
}

class _ImageProcessingViewState extends State<ImageProcessingView> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _originalImageBytes;
  Uint8List? _processedImageBytes;
  String _statusMessage =
      'Gunakan Smart Vision atau pilih gambar dari galeri untuk memulai tahap input.';
  bool _isPicking = false;
  double _brightness = 0;
  double _contrast = 1.0;
  bool _grayscaleEnabled = false;
  bool _invertEnabled = false;
  bool _thresholdEnabled = false;
  double _threshold = 0.5;
  bool _equalizeHistogram = false;
  String _convolutionFilter = 'none';
  List<int> _histogramBins = List<int>.filled(256, 0);
  bool _isHistogramLoading = false;
  Timer? _debounceTimer;
  int _processingToken = 0;
  static const int _previewMaxWidth = 1024;

  bool get _hasImage => _originalImageBytes != null;
  bool get _openedFromSmartVision => widget.initialImageBytes != null;

  @override
  void initState() {
    super.initState();
    final initialBytes = widget.initialImageBytes;
    if (initialBytes == null) {
      return;
    }

    _originalImageBytes = initialBytes;
    _statusMessage =
        widget.initialStatusMessage ??
        'Gambar dari Smart Vision berhasil dimuat. Lanjutkan manipulasi PCD.';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _processSelectedImage(immediate: true);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking) {
      return;
    }

    setState(() {
      _isPicking = true;
      _statusMessage = source == ImageSource.camera
          ? 'Membuka kamera...'
          : 'Membuka galeri...';
    });

    try {
      final pickedImage = await _picker.pickImage(
        source: source,
        imageQuality: 95,
      );

      if (!mounted) {
        return;
      }

      if (pickedImage == null) {
        setState(() {
          _statusMessage = 'Belum ada gambar yang dipilih.';
        });
        return;
      }

      final originalBytes = await pickedImage.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _originalImageBytes = originalBytes;
        _processedImageBytes = null;
        _histogramBins = List<int>.filled(256, 0);
        _statusMessage = source == ImageSource.camera
            ? 'Gambar berhasil diambil dari kamera.'
            : 'Gambar berhasil diambil dari galeri.';
      });

      await _processSelectedImage(immediate: true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Gagal memuat gambar: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  void _scheduleProcessing() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 180), () {
      _processSelectedImage();
    });
  }

  Future<void> _processSelectedImage({bool immediate = false}) async {
    final selectedBytes = _originalImageBytes;
    if (selectedBytes == null) {
      return;
    }

    _debounceTimer?.cancel();

    final processingToken = ++_processingToken;
    setState(() {
      _statusMessage = 'Memproses filter PCD...';
    });

    try {
      final processedBytes = await compute(_processPcdImage, <String, dynamic>{
        'bytes': selectedBytes,
        'brightness': (_brightness * 255).round(),
        'contrast': _contrast,
        'grayscale': _grayscaleEnabled,
        'invert': _invertEnabled,
        'thresholdEnabled': _thresholdEnabled,
        'threshold': (_threshold * 255).round(),
        'equalizeHistogram': _equalizeHistogram,
        'convolution': _convolutionFilter,
        'maxWidth': immediate ? _previewMaxWidth : 960,
      });

      if (!mounted || processingToken != _processingToken) {
        return;
      }

      final hasAnyFilterApplied =
          _brightness.abs() > 0.001 ||
          (_contrast - 1.0).abs() > 0.001 ||
          _grayscaleEnabled ||
          _invertEnabled ||
          _thresholdEnabled ||
          _equalizeHistogram ||
          _convolutionFilter != 'none';

      setState(() {
        _processedImageBytes = processedBytes;
        _statusMessage = hasAnyFilterApplied
            ? 'Gambar berhasil diproses dengan pengaturan filter saat ini.'
            : 'Gambar siap diedit. Atur filter untuk mulai manipulasi.';
      });

      await _updateHistogramForBytes(
        processedBytes,
        processingToken: processingToken,
      );
    } catch (e) {
      if (!mounted || processingToken != _processingToken) {
        return;
      }

      setState(() {
        _processedImageBytes = null;
        _statusMessage = 'Gagal memproses gambar: $e';
      });

      await _updateHistogramForBytes(
        selectedBytes,
        processingToken: processingToken,
      );
    } finally {
      if (mounted && processingToken == _processingToken) {
        setState(() {});
      }
    }
  }

  Future<void> _updateHistogramForBytes(
    Uint8List imageBytes, {
    required int processingToken,
  }) async {
    if (!mounted || processingToken != _processingToken) {
      return;
    }

    setState(() {
      _isHistogramLoading = true;
    });

    try {
      final bins = await compute(_computeLuminanceHistogram, imageBytes);
      if (!mounted || processingToken != _processingToken) {
        return;
      }

      setState(() {
        _histogramBins = bins;
      });
    } finally {
      if (mounted && processingToken == _processingToken) {
        setState(() {
          _isHistogramLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _openedFromSmartVision
              ? 'Smart Vision - Editor Gambar'
              : 'ETS PCD - Input Gambar',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        height: 280,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        child: !_hasImage
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.image_outlined, size: 56),
                                    SizedBox(height: 12),
                                    Text(
                                      'Belum ada gambar dipilih',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Gunakan Smart Vision atau galeri untuk memulai.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: _processedImageBytes == null
                                    ? Image.memory(
                                        _originalImageBytes!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      )
                                    : Image.memory(
                                        _processedImageBytes!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (_hasImage) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Histogram (Luminance)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 132,
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: _isHistogramLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : CustomPaint(
                                  painter: _HistogramPainter(
                                    bins: _histogramBins,
                                    barColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_hasImage) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Manipulasi PCD Sederhana',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const SizedBox(
                              width: 96,
                              child: Text(
                                'Brightness',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _brightness,
                                min: -0.4,
                                max: 0.4,
                                divisions: 8,
                                label: _brightness.toStringAsFixed(2),
                                onChanged: (value) {
                                  setState(() {
                                    _brightness = value;
                                  });
                                  _scheduleProcessing();
                                },
                                onChangeEnd: (_) {
                                  _processSelectedImage(immediate: true);
                                },
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const SizedBox(
                              width: 96,
                              child: Text(
                                'Contrast',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _contrast,
                                min: 0.6,
                                max: 1.6,
                                divisions: 10,
                                label: _contrast.toStringAsFixed(2),
                                onChanged: (value) {
                                  setState(() {
                                    _contrast = value;
                                  });
                                  _scheduleProcessing();
                                },
                                onChangeEnd: (_) {
                                  _processSelectedImage(immediate: true);
                                },
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Grayscale',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Aktifkan tampilan hitam putih',
                            style: TextStyle(fontSize: 12.5),
                          ),
                          value: _grayscaleEnabled,
                          onChanged: (value) {
                            setState(() {
                              _grayscaleEnabled = value;
                            });
                            _scheduleProcessing();
                          },
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Invert',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Balik warna (negatif) gambar',
                            style: TextStyle(fontSize: 12.5),
                          ),
                          value: _invertEnabled,
                          onChanged: (value) {
                            setState(() {
                              _invertEnabled = value;
                            });
                            _scheduleProcessing();
                          },
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Threshold B/W',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Ubah ke hitam-putih biner',
                            style: TextStyle(fontSize: 12.5),
                          ),
                          value: _thresholdEnabled,
                          onChanged: (value) {
                            setState(() {
                              _thresholdEnabled = value;
                            });
                            _scheduleProcessing();
                          },
                        ),
                        if (_thresholdEnabled)
                          Row(
                            children: [
                              const SizedBox(
                                width: 96,
                                child: Text(
                                  'Threshold',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _threshold,
                                  min: 0,
                                  max: 1,
                                  divisions: 10,
                                  label: _threshold.toStringAsFixed(2),
                                  onChanged: (value) {
                                    setState(() {
                                      _threshold = value;
                                    });
                                    _scheduleProcessing();
                                  },
                                  onChangeEnd: (_) {
                                    _processSelectedImage(immediate: true);
                                  },
                                ),
                              ),
                            ],
                          ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Histogram Equalization',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Tingkatkan sebaran kontras',
                            style: TextStyle(fontSize: 12.5),
                          ),
                          value: _equalizeHistogram,
                          onChanged: (value) {
                            setState(() {
                              _equalizeHistogram = value;
                            });
                            _scheduleProcessing();
                          },
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _convolutionFilter,
                          decoration: const InputDecoration(
                            labelText: 'Convolution Filter',
                            labelStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'none',
                              child: Text('None'),
                            ),
                            DropdownMenuItem(
                              value: 'blur',
                              child: Text('Blur (3x3)'),
                            ),
                            DropdownMenuItem(
                              value: 'sharpen',
                              child: Text('Sharpen (3x3)'),
                            ),
                            DropdownMenuItem(
                              value: 'edge',
                              child: Text('Edge Detect (3x3)'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _convolutionFilter = value;
                            });
                            _scheduleProcessing();
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _isPicking
                              ? null
                              : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pilih Gambar dari Galeri'),
                        ),
                      ),
                      if (_hasImage) ...[
                        const SizedBox(height: 10),
                        if (_openedFromSmartVision) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Kembali ke Smart Vision'),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter({required this.bins, required this.barColor});

  final List<int> bins;
  final Color barColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = barColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final grid = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    final baselineY = size.height - 1;
    canvas.drawLine(Offset(0, baselineY), Offset(size.width, baselineY), grid);
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), grid);

    if (bins.length != 256) {
      return;
    }

    final maxValue = bins.reduce(math.max);
    if (maxValue <= 0) {
      return;
    }

    final barWidth = size.width / bins.length;
    for (var i = 0; i < bins.length; i++) {
      final normalized = bins[i] / maxValue;
      final barHeight = normalized * (size.height - 2);
      final rect = Rect.fromLTWH(
        i * barWidth,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter oldDelegate) {
    return oldDelegate.bins != bins || oldDelegate.barColor != barColor;
  }
}
