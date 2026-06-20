# LogBook App

Repositori ini berisi pengembangan aplikasi Flutter bertahap sebagai tugas praktikum, mulai dari counter sederhana hingga aplikasi Smart Patrol Vision dengan pemrosesan citra digital.

---

## LogBook Counter Application

### Deskripsi

LogBook Counter adalah aplikasi berbasis Flutter yang dikembangkan sebagai tugas praktikum pada Modul 1. Aplikasi ini merupakan pengembangan dari counter sederhana dengan penambahan fitur pengaturan langkah (step) serta pencatatan riwayat aktivitas secara real-time.

Aplikasi dirancang untuk melatih pemahaman dasar mengenai pemrograman Dart, pengelolaan state, manipulasi variabel, penggunaan struktur data List, serta pemisahan logika program dan tampilan antarmuka.

### Tujuan Pengembangan

Tujuan pembuatan aplikasi ini adalah:

- Mengimplementasikan logika perhitungan dengan nilai langkah (step) yang dapat diatur.
- Menyimpan dan menampilkan riwayat aktivitas pengguna.
- Menampilkan perubahan data secara real-time pada antarmuka.
- Membangun struktur kode yang rapi, terpisah antara logika dan tampilan.

### Fitur Aplikasi

1. **Multi-Step Counter**
   - Penambahan nilai counter.
   - Pengurangan nilai counter.
   - Nilai langkah (step) dapat diatur melalui input pengguna.
   - Setiap perubahan mengikuti nilai step yang ditentukan.

2. **History Logger**
   - Mencatat setiap aksi (tambah, kurang, reset).
   - Menyimpan waktu terjadinya aktivitas.
   - Menampilkan riwayat secara langsung pada layar.
   - Riwayat dibatasi hanya 5 data terakhir.

3. **Peningkatan Antarmuka**
   - Perbedaan warna untuk setiap jenis aksi.
   - Dialog konfirmasi sebelum melakukan reset.
   - Notifikasi menggunakan SnackBar setelah reset berhasil.

### Struktur Proyek (Modul 1)

```
lib/
 ├── main.dart
 ├── counter_controller.dart
 └── counter_view.dart
```

**Keterangan:**

- `main.dart`: Titik awal eksekusi aplikasi.
- `counter_controller.dart`: Berisi logika perhitungan dan pengelolaan data.
- `counter_view.dart`: Berisi tampilan antarmuka dan interaksi pengguna.

### Self-Reflection

Penerapan prinsip Single Responsibility Principle (SRP) sangat membantu selama proses pengembangan fitur History Logger. Dengan memisahkan logika perhitungan dan pengelolaan data di Controller serta tampilan antarmuka di View, penambahan fitur riwayat dapat dilakukan tanpa mengubah struktur utama aplikasi. Seluruh proses pencatatan aktivitas cukup ditambahkan pada CounterController, sementara CounterView hanya bertugas menampilkan data tersebut. Pendekatan ini membuat kode lebih terorganisir, mudah dipahami, serta meminimalkan risiko kesalahan saat melakukan pengembangan fitur baru.

---

## ETS Smart Patrol Vision

### Ringkasan

Project ini adalah aplikasi Flutter untuk ETS dengan fokus pada:

- Smart Vision (preview kamera + overlay deteksi)
- Capture dari kamera
- Manipulasi gambar menggunakan fungsi PCD (brightness, contrast, histogram, threshold, convolution, dan lainnya)

Implementasi dibuat agar alur pengguna sederhana:

1. Buka Smart Patrol Vision
2. Tangkap gambar
3. Lanjut edit gambar di halaman editor

### Fitur Utama

#### 1) Smart Vision

- Inisialisasi kamera dengan permission handling
- Live preview kamera dengan rasio yang aman
- Overlay deteksi di atas preview (crosshair + box deteksi)
- Label status deteksi pada UI
- Torch (flashlight) toggle
- Overlay toggle
- Lifecycle aman (kamera dispose saat app background/keluar)

#### 2) Image Processing (PCD)

- Brightness
- Contrast
- Grayscale
- Invert
- Threshold B/W
- Histogram Equalization
- Convolution Filter: None, Blur, Sharpen, Edge Detect
- Histogram luminance
- Pemrosesan dilakukan async agar UI tetap responsif

#### 3) Dukungan Data dan Logging

- Penyimpanan lokal menggunakan Hive
- Handshake ke MongoDB (jika konfigurasi tersedia)
- Logging internal aplikasi

### Struktur Folder Inti (Modul 6)

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

### Alur Demo Singkat

1. Buka halaman Smart Patrol Vision.
2. Tunjukkan live preview kamera dan overlay deteksi.
3. Ambil gambar menggunakan tombol capture.
4. Lanjut ke halaman editor gambar.
5. Tunjukkan manipulasi PCD seperti contrast, histogram, dan convolution.
6. Tunjukkan perubahan hasil sebelum dan sesudah filter.

---

## Teknologi yang Digunakan

- Flutter & Dart
- Android Device / Emulator
- Hive (penyimpanan lokal)
- MongoDB (opsional, jika tersedia)
- Visual Studio Code

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

## Cara Menjalankan Aplikasi

1. Masuk ke folder proyek:

   ```bash
   cd logbook_app_001
   ```

2. Ambil dependency:

   ```bash
   flutter pub get
   ```

3. Hubungkan perangkat atau jalankan emulator.

4. Jalankan aplikasi:

   ```bash
   flutter run
   ```
