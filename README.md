# Logbook App 001 - ETS Smart Patrol Vision

## Ringkasan

Project ini adalah aplikasi Flutter untuk ETS dengan fokus pada:

- Smart Vision (preview kamera + overlay deteksi)
- Capture dari kamera
- Manipulasi gambar menggunakan fungsi PCD (brightness, contrast, histogram, threshold, convolution, dan lainnya)

Implementasi dibuat agar alur pengguna sederhana:

1. Buka Smart Patrol Vision
2. Tangkap gambar
3. Lanjut edit gambar di halaman editor

## Fitur Utama

### 1) Smart Vision

- Inisialisasi kamera dengan permission handling
- Live preview kamera dengan rasio yang aman
- Overlay deteksi di atas preview (crosshair + box deteksi)
- Label status deteksi pada UI
- Torch (flashlight) toggle
- Overlay toggle
- Lifecycle aman (kamera dispose saat app background/keluar)

### 2) Image Processing (PCD)

- Brightness
- Contrast
- Grayscale
- Invert
- Threshold B/W
- Histogram Equalization
- Convolution Filter: None, Blur, Sharpen, Edge Detect
- Histogram luminance
- Pemrosesan dilakukan async agar UI tetap responsif

### 3) Dukungan Data dan Logging

- Penyimpanan lokal menggunakan Hive
- Handshake ke MongoDB (jika konfigurasi tersedia)
- Logging internal aplikasi

## Struktur Folder Inti

```text
lib/
    main.dart
    features/
        onboarding/
        auth/
        logbook/
        vision/
            vision_view.dart
            vision_controller.dart
            damage_painter.dart
            detection_result.dart
        image_processing/
            image_processing_view.dart
    helpers/
    services/
```

## Kebutuhan Sistem

- Flutter SDK (sesuai environment project)
- Android SDK + perangkat Android atau emulator
- Kamera perangkat aktif

## Konfigurasi Environment

Project menggunakan file `.env`.

Minimal isi yang disarankan:

```env
MONGODB_URI=your_mongodb_connection_string
```

Catatan:

- Jika MongoDB belum tersedia, aplikasi tetap bisa dijalankan untuk demo Vision dan Image Processing.
- Pastikan file `.env` ada di root project.

## Cara Menjalankan

1. Masuk ke root project

```bash
cd logbook_app_001
```

2. Ambil dependency

```bash
flutter pub get
```

3. Jalankan aplikasi

```bash
flutter run
```

## Alur Demo Singkat

1. Buka halaman Smart Patrol Vision.
2. Tunjukkan live preview kamera dan overlay deteksi.
3. Ambil gambar menggunakan tombol capture.
4. Lanjut ke halaman editor gambar.
5. Tunjukkan manipulasi PCD seperti contrast, histogram, dan convolution.
6. Tunjukkan perubahan hasil sebelum dan sesudah filter.

