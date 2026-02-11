# LogBook Counter Application

## Deskripsi

LogBook Counter adalah aplikasi berbasis Flutter yang dikembangkan sebagai tugas praktikum pada Modul 1. Aplikasi ini merupakan pengembangan dari counter sederhana dengan penambahan fitur pengaturan langkah (step) serta pencatatan riwayat aktivitas secara real-time.

Aplikasi dirancang untuk melatih pemahaman dasar mengenai pemrograman Dart, pengelolaan state, manipulasi variabel, penggunaan struktur data List, serta pemisahan logika program dan tampilan antarmuka.

## Tujuan Pengembangan

Tujuan pembuatan aplikasi ini adalah:

- Mengimplementasikan logika perhitungan dengan nilai langkah (step) yang dapat diatur.
- Menyimpan dan menampilkan riwayat aktivitas pengguna.
- Menampilkan perubahan data secara real-time pada antarmuka.
- Membangun struktur kode yang rapi, terpisah antara logika dan tampilan.

## Fitur Aplikasi

1.  **Multi-Step Counter**
    - Penambahan nilai counter.
    - Pengurangan nilai counter.
    - Nilai langkah (step) dapat diatur melalui input pengguna.
    - Setiap perubahan mengikuti nilai step yang ditentukan.

2.  **History Logger**
    - Mencatat setiap aksi (tambah, kurang, reset).
    - Menyimpan waktu terjadinya aktivitas.
    - Menampilkan riwayat secara langsung pada layar.
    - Riwayat dibatasi hanya 5 data terakhir.

3.  **Peningkatan Antarmuka**
    - Perbedaan warna untuk setiap jenis aksi.
    - Dialog konfirmasi sebelum melakukan reset.
    - Notifikasi menggunakan SnackBar setelah reset berhasil.

## Struktur Proyek

```
lib/
 ├── main.dart
 ├── counter_controller.dart
 └── counter_view.dart
```

**Keterangan:**

-   `main.dart`: Titik awal eksekusi aplikasi.
-   `counter_controller.dart`: Berisi logika perhitungan dan pengelolaan data.
-   `counter_view.dart`: Berisi tampilan antarmuka dan interaksi pengguna.

## Teknologi yang Digunakan

-   Flutter
-   Dart
-   Android Device / Emulator
-   Visual Studio Code

## Cara Menjalankan Aplikasi

1.  Masuk ke folder proyek:
    ```sh
    cd logbook_app_001
    ```
2.  Hubungkan perangkat atau jalankan emulator.
3.  Jalankan perintah:
    ```sh
    flutter run
    ```

## Self-Reflection

Penerapan prinsip Single Responsibility Principle (SRP) sangat membantu selama proses pengembangan fitur History Logger. Dengan memisahkan logika perhitungan dan pengelolaan data di Controller serta tampilan antarmuka di View, penambahan fitur riwayat dapat dilakukan tanpa mengubah struktur utama aplikasi. Seluruh proses pencatatan aktivitas cukup ditambahkan pada CounterController, sementara CounterView hanya bertugas menampilkan data tersebut. Pendekatan ini membuat kode lebih terorganisir, mudah dipahami, serta meminimalkan risiko kesalahan saat melakukan pengembangan fitur baru.
