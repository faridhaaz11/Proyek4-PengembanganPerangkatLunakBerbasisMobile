// test/integration/hive_sync_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// LAYER 3 — Integration Test: Validasi Kontrak Data Hive ↔ MongoDB
//
// Strategi: Contract Testing untuk Infrastruktur
//   Bukan mengetes koneksi jaringan, melainkan memverifikasi bahwa:
//   1. Data dapat disimpan ke Hive dengan struktur yang benar
//   2. Data yang dibaca kembali dari Hive identik (field-by-field)
//   3. Data yang akan dikirim ke MongoDB memiliki shape yang valid
//      (via toMap() — tanpa perlu koneksi internet)
//
// Terminologi: "Integration" karena mengintegrasikan dua komponen:
//   LogModel (kontrak data) ↔ Hive TypeAdapter (infrastruktur penyimpanan)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:logbook_app_001/features/logbook/models/log_model.dart';

void main() {
  late Directory tempDir;
  late Box<LogModel> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_integration_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LogModelAdapter());
    }
  });

  setUp(() async {
    box = await Hive.openBox<LogModel>('integration_logs');
    await box.clear(); // mulai dari kondisi bersih setiap test
  });

  tearDown(() async {
    await box.close();
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // ─────────────────────────────────────────────────────────────────────
  // Helper: membuat LogModel standar untuk pengujian
  // ─────────────────────────────────────────────────────────────────────
  LogModel sampleLog() => LogModel(
    id: '507f1f77bcf86cd799439011', // Valid 24-char hex ObjectId
    username: 'faridha',
    title: '# Laporan Minggu 1\n\nIni adalah **markdown**.',
    date: DateTime(2026, 3, 9, 10, 30),
    description: 'Deskripsi percobaan menggunakan format Markdown.',
    category: 'Riset',
    authorId: 'faridha',
    teamId: 'team_alpha',
  );

  // ─────────────────────────────────────────────────────────────────────
  // GROUP 1: Persistensi Hive (Simpan → Baca)
  // ─────────────────────────────────────────────────────────────────────
  group('Hive Persistence — Simpan dan Baca Kembali', () {
    test('Data yang disimpan dapat dibaca kembali dengan benar', () async {
      // Arrange
      final original = sampleLog();

      // Act: simpan ke Hive
      await box.add(original);

      // Baca kembali dari disk (tutup dan buka ulang mensimulasikan restart app)
      await box.close();
      box = await Hive.openBox<LogModel>('integration_logs');
      final retrieved = box.values.first;

      // Assert: semua field harus identik
      expect(
        retrieved.id,
        original.id,
        reason: 'ID harus tetap sama setelah disimpan ke Hive',
      );
      expect(retrieved.username, original.username);
      expect(
        retrieved.title,
        original.title,
        reason: 'Konten Markdown harus tersimpan utuh tanpa modifikasi',
      );
      expect(retrieved.date, original.date);
      expect(retrieved.description, original.description);
      expect(retrieved.category, original.category);
      expect(
        retrieved.authorId,
        original.authorId,
        reason: 'authorId (RBAC) harus tersimpan untuk validasi kepemilikan',
      );
      expect(
        retrieved.teamId,
        original.teamId,
        reason: 'teamId harus tersimpan untuk Collaborative Sync',
      );
    });

    test('Banyak log tersimpan dengan urutan yang benar', () async {
      // Arrange
      final logs = List.generate(
        5,
        (i) => LogModel(
          id: 'id_$i',
          username: 'user$i',
          title: 'Log ke-$i',
          date: DateTime(2026, 1, i + 1),
          description: 'Deskripsi $i',
          category: 'Harian',
          authorId: 'user$i',
          teamId: 'team_beta',
        ),
      );

      // Act
      await box.addAll(logs);

      // Assert
      expect(box.length, 5);
      for (int i = 0; i < 5; i++) {
        expect(box.getAt(i)?.title, 'Log ke-$i');
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // GROUP 2: Update dan Delete di Hive
  // ─────────────────────────────────────────────────────────────────────
  group('Hive CRUD — Update dan Hapus', () {
    test('putAt() memperbarui log di posisi yang tepat', () async {
      // Arrange
      await box.add(sampleLog());

      final updated = LogModel(
        id: 'abc123hex',
        username: 'faridha',
        title: 'Judul Diperbarui',
        date: DateTime(2026, 3, 10),
        description: 'Deskripsi baru setelah edit.',
        category: 'Harian',
        authorId: 'faridha',
        teamId: 'team_alpha',
      );

      // Act
      await box.putAt(0, updated);

      // Assert
      expect(
        box.length,
        1,
        reason: 'Harus tetap 1 item setelah update (bukan insert)',
      );
      expect(box.getAt(0)?.title, 'Judul Diperbarui');
      expect(box.getAt(0)?.category, 'Harian');
    });

    test('deleteAt() menghapus log dari Hive', () async {
      // Arrange
      await box.add(sampleLog());
      expect(box.length, 1);

      // Act
      await box.deleteAt(0);

      // Assert
      expect(box.length, 0);
    });

    test('clear() mengosongkan seluruh box', () async {
      // Arrange
      await box.addAll([sampleLog(), sampleLog(), sampleLog()]);
      expect(box.length, 3);

      // Act
      await box.clear();

      // Assert
      expect(box.length, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // GROUP 3: Validasi Kontrak Data untuk MongoDB (toMap)
  // ─────────────────────────────────────────────────────────────────────
  group('Kontrak Data: toMap() → Shape yang Valid untuk MongoDB', () {
    test('toMap() menghasilkan semua field wajib MongoDB', () {
      // Arrange
      final log = sampleLog();

      // Act
      final map = log.toMap();

      // Assert: field-field yang diharapkan ada di dokumen MongoDB
      expect(map.containsKey('username'), isTrue);
      expect(map.containsKey('title'), isTrue);
      expect(map.containsKey('date'), isTrue);
      expect(map.containsKey('description'), isTrue);
      expect(map.containsKey('category'), isTrue);
      expect(
        map.containsKey('authorId'),
        isTrue,
        reason: 'authorId wajib ada agar query kepemilikan RBAC bisa bekerja',
      );
      expect(
        map.containsKey('teamId'),
        isTrue,
        reason:
            'teamId wajib ada agar Collaborative Sync bisa memfilter log per tim',
      );
    });

    test('toMap() menyimpan nilai yang benar untuk setiap field', () {
      // Arrange
      final log = sampleLog();

      // Act
      final map = log.toMap();

      // Assert
      expect(map['username'], 'faridha');
      expect(map['category'], 'Riset');
      expect(map['authorId'], 'faridha');
      expect(map['teamId'], 'team_alpha');
    });

    test('fromMap(toMap()) membentuk LogModel yang ekuivalen', () {
      // Arrange
      final original = LogModel(
        id: null, // Simulasi: log baru belum punya ID MongoDB
        username: 'faridha',
        title: 'Round-trip Test',
        date: DateTime(2026, 5, 20),
        description: 'Deskripsi round-trip',
        category: 'Umum',
        authorId: 'faridha',
        teamId: 'team_alpha',
      );

      // Act: ubah ke Map (seperti saat dikirim ke MongoDB), lalu parse kembali
      final map = original.toMap();
      // Simulasikan respons MongoDB: tambahkan _id palsu
      map['_id'] = null;
      final roundTripped = LogModel.fromMap(map);

      // Assert
      expect(roundTripped.username, original.username);
      expect(roundTripped.title, original.title);
      expect(roundTripped.description, original.description);
      expect(roundTripped.category, original.category);
      expect(roundTripped.authorId, original.authorId);
      expect(roundTripped.teamId, original.teamId);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // GROUP 4: Skenario Restart Aplikasi (Persistensi Jangka Panjang)
  // ─────────────────────────────────────────────────────────────────────
  group('Persistensi Saat Restart — Simulasi Buka Ulang App', () {
    test('Data Hive tetap ada setelah box ditutup dan dibuka ulang', () async {
      // Arrange: simpan 2 log
      await box.add(sampleLog());
      await box.add(
        LogModel(
          id: 'second_id',
          username: 'faridha',
          title: 'Log Kedua',
          date: DateTime(2026, 3, 10),
          description: 'Isi log kedua',
          category: 'Harian',
          authorId: 'faridha',
          teamId: 'team_alpha',
        ),
      );

      // Act: tutup (simulasi app ditutup)
      await box.close();

      // Act: buka ulang (simulasi app dibuka kembali)
      box = await Hive.openBox<LogModel>('integration_logs');

      // Assert: data tidak hilang
      expect(
        box.length,
        2,
        reason: 'Data harus persisten meski app di-restart',
      );
      expect(box.values.any((l) => l.title.contains('Laporan Minggu')), isTrue);
      expect(box.values.any((l) => l.title == 'Log Kedua'), isTrue);
    });
  });
}
