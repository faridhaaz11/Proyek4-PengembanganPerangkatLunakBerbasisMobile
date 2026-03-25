// test/unit/log_controller_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// LAYER 2 — Unit Test: Validasi LogController dengan Mock Database
//
// Prinsip Dependency Inversion (SOLID):
//   LogController TIDAK bergantung pada MongoDB asli, melainkan pada
//   interface IMongoService. Di sini kita mengganti MongoDB asli dengan
//   MockMongoService — sebuah implementasi palsu yang bisa kita kendalikan.
//
// Keuntungan:
//   ✓ Tidak perlu koneksi internet
//   ✓ Tes berjalan < 100ms
//   ✓ Deterministik — tidak flaky karena jaringan
//   ✓ Membuktikan LogController berperilaku sesuai kontrak RBAC
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:logbook_app_001/services/i_mongo_service.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/features/logbook/log_controller.dart';

// ── MOCK DEFINITION ──────────────────────────────────────────────────────────
/// MockMongoService: Implementasi palsu dari IMongoService.
/// Menggunakan package mocktail untuk menangkap dan mengendalikan pemanggilan.
class MockMongoService extends Mock implements IMongoService {}

void main() {
  // ── GLOBAL SETUP ───────────────────────────────────────────────────────────
  late MockMongoService mockMongo;
  late Box<LogModel> testBox;
  late Directory tempDir;
  late LogController controller;

  // Model bantu untuk pengujian
  LogModel makeLog({
    String id = 'abc123',
    String username = 'testuser',
    String title = 'Judul Test',
    String desc = 'Isi deskripsi test',
    String category = 'Umum',
    String authorId = 'testuser',
    String teamId = 'team_A',
  }) {
    return LogModel(
      id: id,
      username: username,
      title: title,
      date: DateTime(2026, 1, 1),
      description: desc,
      category: category,
      authorId: authorId,
      teamId: teamId,
    );
  }

  setUpAll(() async {
    // Inisialisasi Flutter binding agar platform channel (connectivity) tidak crash
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock connectivity_plus plugin agar loadLogs berjalan tanpa native platform.
    // Mensimulasikan kondisi "Online" (wifi tersedia).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (MethodCall call) async {
            if (call.method == 'check') {
              // Kembalikan list string yang diharapkan oleh parseConnectivityResults
              return ['wifi'];
            }
            return null;
          },
        );

    // Inisialisasi dotenv agar LogHelper.writeLog tidak crash saat test
    dotenv.loadFromString(
      envString: '',
      mergeWith: {'LOG_LEVEL': '0', 'LOG_MUTE': ''},
      isOptional: true,
    );

    // Daftarkan fallback value untuk tipe non-primitif di mocktail
    registerFallbackValue(
      LogModel(
        username: 'fallback',
        title: 'fallback',
        date: DateTime.now(),
        description: 'fallback',
        category: 'fallback',
      ),
    );
  });

  setUp(() async {
    // Inisialisasi Hive di direktori sementara (tidak perlu platform)
    tempDir = await Directory.systemTemp.createTemp('hive_ctrl_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LogModelAdapter());
    }
    testBox = await Hive.openBox<LogModel>('test_ctrl_logs');

    // Buat mock dan controller baru dengan dependensi yang disuntikkan
    mockMongo = MockMongoService();

    // Stub semua metode yang mungkin dipanggil
    when(() => mockMongo.connect()).thenAnswer((_) async {});
    when(() => mockMongo.close()).thenAnswer((_) async {});
    when(() => mockMongo.insertLog(any())).thenAnswer((_) async {});
    when(() => mockMongo.updateLog(any())).thenAnswer((_) async {});
    when(() => mockMongo.deleteLog(any())).thenAnswer((_) async {});
    when(() => mockMongo.upsertLog(any())).thenAnswer((_) async {});
    when(() => mockMongo.getLogsByTeam(any())).thenAnswer((_) async => []);
    when(
      () => mockMongo.getLogs(username: any(named: 'username')),
    ).thenAnswer((_) async => []);

    controller = LogController(
      userRole: 'Anggota',
      userId: 'testuser',
      teamId: 'team_A',
      mongoService: mockMongo, // ← Injeksi Mock (bukan MongoDB asli)
      connectivityStream: const Stream.empty(), // ← Nonaktifkan bg sync
      hiveBox: testBox, // ← Injeksi Hive box sementara
    );
  });

  tearDown(() async {
    controller.dispose();
    await testBox.clear();
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // ── TEST GROUP 1: addLog ───────────────────────────────────────────────────
  group('addLog — Penambahan Log Baru', () {
    test('Menambahkan log ke logsNotifier setelah berhasil disimpan', () async {
      // Act
      await controller.addLog('Judul Baru', 'Deskripsi', 'Umum', 'testuser');

      // Assert: logsNotifier harus berisi 1 item
      expect(controller.logsNotifier.value.length, 1);
      expect(controller.logsNotifier.value.first.title, 'Judul Baru');
    });

    test('Memanggil mockMongo.insertLog tepat satu kali', () async {
      // Act
      await controller.addLog('Log Atlas', 'Desc', 'Riset', 'testuser');

      // Assert: kontrak dengan database → insertLog dipanggil 1x
      verify(() => mockMongo.insertLog(any())).called(1);
    });

    test('Log baru tersimpan ke Hive lokal (offline-first)', () async {
      // Act
      await controller.addLog('Log Hive', 'Desc', 'Harian', 'testuser');

      // Assert: data ada di Hive box
      expect(testBox.values.length, 1);
      expect(testBox.values.first.title, 'Log Hive');
    });
  });

  // ── TEST GROUP 2: updateLog + RBAC ────────────────────────────────────────
  group('updateLog — RBAC Lapis-Dua: Proteksi Kepemilikan', () {
    test(
      'Anggota NON-OWNER → DIBLOKIR, mock.updateLog TIDAK dipanggil',
      () async {
        // Arrange: Isi log milik orang lain (authorId ≠ userId controller)
        final foreignLog = makeLog(
          title: 'Data Orang Lain',
          authorId: 'user_lain', // bukan 'testuser'
        );
        await testBox.add(foreignLog);
        controller.logsNotifier.value = [foreignLog];

        // Act: Anggota mencoba update log milik orang lain
        await controller.updateLog(0, 'Judul Baru', 'Desc', 'Umum');

        // Assert: Aksi diblokir — mock TIDAK dipanggil
        verifyNever(() => mockMongo.updateLog(any()));

        // Assert: Data di logsNotifier tetap tidak berubah
        expect(
          controller.logsNotifier.value.first.title,
          'Data Orang Lain',
          reason: 'Judul harus tetap sama karena update diblokir RBAC',
        );
      },
    );

    test(
      'Anggota OWNER (isOwner: true) → DIIZINKAN, mock.updateLog dipanggil',
      () async {
        // Arrange: log milik sendiri
        final ownLog = makeLog(
          title: 'Data Saya',
          authorId: 'testuser', // sama dengan userId controller
        );
        await testBox.add(ownLog);
        controller.logsNotifier.value = [ownLog];

        // Act
        await controller.updateLog(0, 'Judul Diperbarui', 'Desc Baru', 'Riset');

        // Assert: mock dipanggil
        verify(() => mockMongo.updateLog(any())).called(1);

        // Assert: logsNotifier diperbarui
        expect(controller.logsNotifier.value.first.title, 'Judul Diperbarui');
      },
    );
  });

  // ── TEST GROUP 3: removeLog + RBAC ────────────────────────────────────────
  group('removeLog — RBAC Lapis-Dua: Proteksi Penghapusan', () {
    test(
      'Task 5 — Asisten TIDAK BISA Delete data milik orang lain (Owner-Only)',
      () async {
        // Arrange: ubah controller menjadi Asisten
        final assistenCtrl = LogController(
          userRole: 'Asisten',
          userId: 'asisten01',
          teamId: 'team_A',
          mongoService: mockMongo,
          connectivityStream: const Stream.empty(),
          hiveBox: testBox,
        );

        // Log ini milik 'user_lain', bukan 'asisten01'
        // Task 5: canPerform(delete) = isOwner = false → diblokir
        final log = makeLog(
          title: 'Log Orang Lain',
          authorId: 'user_lain', // bukan asisten01 → isOwner = false
        );
        await testBox.add(log);
        assistenCtrl.logsNotifier.value = [log];

        // Act
        await assistenCtrl.removeLog(0);

        // Assert: bukan pemilik → diblokir
        verifyNever(() => mockMongo.deleteLog(any()));

        // Assert: data tetap ada
        expect(
          assistenCtrl.logsNotifier.value.length,
          1,
          reason: 'Task 5: Asisten tidak boleh menghapus log milik orang lain',
        );

        assistenCtrl.dispose();
      },
    );

    test(
      'Task 5 — Ketua TIDAK BISA Delete data milik orang lain (Owner-Only)',
      () async {
        // Arrange: ubah controller menjadi Ketua
        final ketuaCtrl = LogController(
          userRole: 'Ketua',
          userId: 'ketua01',
          teamId: 'team_A',
          mongoService: mockMongo,
          connectivityStream: const Stream.empty(),
          hiveBox: testBox,
        );

        // Log ini milik 'testuser', bukan 'ketua01'
        final log = makeLog(id: 'id_log_anggota', title: 'Log Anggota');
        await testBox.add(log);
        ketuaCtrl.logsNotifier.value = [log];

        // Act: Ketua mencoba menghapus log milik orang lain
        await ketuaCtrl.removeLog(0);

        // Assert: Task 5 — Owner-Only → diblokir, mock TIDAK dipanggil
        verifyNever(() => mockMongo.deleteLog(any()));

        // Assert: data tetap ada di notifier
        expect(
          ketuaCtrl.logsNotifier.value.length,
          1,
          reason:
              'Task 5 Data Sovereignty: Ketua tidak boleh menghapus '
              'log milik anggota lain',
        );

        ketuaCtrl.dispose();
      },
    );

    test('Task 5 — Ketua BISA Delete data MILIKNYA SENDIRI', () async {
      // Arrange: log milik 'ketua01' sendiri
      final ketuaCtrl = LogController(
        userRole: 'Ketua',
        userId: 'ketua01',
        teamId: 'team_A',
        mongoService: mockMongo,
        connectivityStream: const Stream.empty(),
        hiveBox: testBox,
      );

      final log = makeLog(
        id: 'id_milik_ketua',
        title: 'Log Milik Ketua',
        authorId: 'ketua01', // milik ketua sendiri
      );
      await testBox.add(log);
      ketuaCtrl.logsNotifier.value = [log];

      // Act
      await ketuaCtrl.removeLog(0);

      // Assert: Ketua adalah pemilik → diizinkan
      verify(() => mockMongo.deleteLog(any())).called(1);
      expect(ketuaCtrl.logsNotifier.value.length, 0);

      ketuaCtrl.dispose();
    });
  });

  // ── TEST GROUP 4: loadLogs (Offline-First) ────────────────────────────────
  group('loadLogs — Strategi Offline-First', () {
    test(
      'Mem-populate logsNotifier dari Hive dulu, lalu merge data Cloud + pending lokal',
      () async {
        // Arrange: isi Hive dengan data awal
        final cachedLog = makeLog(title: 'Data Cache Hive');
        await testBox.add(cachedLog);

        // Arrange: Cloud mengembalikan data berbeda
        final cloudLog = makeLog(title: 'Data Terbaru Cloud', id: 'cloud1');
        when(
          () => mockMongo.getLogsByTeam('team_A'),
        ).thenAnswer((_) async => [cloudLog]);

        // Act
        await controller.loadLogs('team_A');

        // Assert: setelah load selesai, data cloud + item lokal yang belum ada di cloud dipertahankan
        expect(controller.logsNotifier.value.length, 2);
        final titles = controller.logsNotifier.value
            .map((l) => l.title)
            .toSet();
        expect(titles.contains('Data Terbaru Cloud'), true);
        expect(titles.contains('Data Cache Hive'), true);
        verify(() => mockMongo.getLogsByTeam('team_A')).called(1);
      },
    );

    test(
      'Jika Cloud gagal → tetap gunakan data cache Hive (Offline Mode)',
      () async {
        // Arrange: isi Hive dengan cache
        final cachedLog = makeLog(title: 'Cache Offline');
        await testBox.add(cachedLog);

        // Arrange: mock cloud melempar Exception
        when(
          () => mockMongo.getLogsByTeam(any()),
        ).thenThrow(Exception('No connection'));

        // Act
        await controller.loadLogs('team_A');

        // Assert: tetap pakai cache Hive
        expect(controller.logsNotifier.value.length, 1);
        expect(controller.logsNotifier.value.first.title, 'Cache Offline');
      },
    );
  });

  // ── TEST GROUP 5: RBAC Privacy Leak Test (Task 5 — Data Sovereignty) ────
  group('getVisibleLogs — RBAC Security Check: Data Privacy', () {
    test(
      'RBAC Security Check: Private logs should NOT be visible to teammates',
      () {
        // ── 1. Setup Data ──────────────────────────────────────────────
        // User A memiliki 2 catatan: 1 Private dan 1 Public (satu tim).
        const userAId = 'user_A';
        const userBId = 'user_B';

        final privateLog = LogModel(
          id: 'log_private_001',
          username: userAId,
          title: 'Catatan Rahasia User A',
          date: DateTime(2026, 3, 1),
          description: 'Isi catatan yang TIDAK boleh dilihat User B',
          category: 'Pribadi',
          authorId: userAId,
          teamId: 'team_A',
          isPublic: false, // ← PRIVATE
        );

        final publicLog = LogModel(
          id: 'log_public_001',
          username: userAId,
          title: 'Pengumuman Tim dari User A',
          date: DateTime(2026, 3, 2),
          description: 'Isi catatan yang boleh dilihat semua anggota tim',
          category: 'Pekerjaan',
          authorId: userAId,
          teamId: 'team_A',
          isPublic: true, // ← PUBLIC
        );

        // ── 2. Action ──────────────────────────────────────────────────
        // Buat controller User B dengan kedua log sudah tersedia di notifier
        // (mensimulasikan hasil setelah fetchLogs/loadLogs dari Cloud)
        final userBController = LogController(
          userRole: 'Anggota',
          userId: userBId,
          teamId: 'team_A',
          mongoService: mockMongo,
          connectivityStream: const Stream.empty(),
          hiveBox: testBox,
        );
        userBController.logsNotifier.value = [privateLog, publicLog];

        // User B memanggil getVisibleLogs() — filter privasi
        final visibleToUserB = userBController.getVisibleLogs(userBId);

        // ── 3. Assert (Validasi) ───────────────────────────────────────
        // User B hanya boleh melihat 1 catatan (yang Public)
        expect(
          visibleToUserB.length,
          1,
          reason:
              'VULNERABILITY DETECTED: User B seharusnya hanya melihat 1 log '
              '(Public), bukan ${visibleToUserB.length}. '
              'Log Private milik User A bocor ke User B!',
        );

        // Pastikan catatan yang tampil adalah yang Public
        expect(
          visibleToUserB.first.isPublic,
          isTrue,
          reason: 'Log yang terlihat oleh User B HARUS berstatus Public',
        );

        // Pastikan log Private benar-benar tersembunyi
        final containsPrivate = visibleToUserB.any(
          (log) => log.id == privateLog.id,
        );
        expect(
          containsPrivate,
          isFalse,
          reason:
              'SECURITY BREACH: Log Private milik User A '
              '("${privateLog.title}") tidak boleh ada dalam daftar User B!',
        );

        expect(
          visibleToUserB.first.title,
          equals(publicLog.title),
          reason: 'Log yang terlihat harus berjudul "${publicLog.title}"',
        );

        userBController.dispose();
      },
    );

    test('Pemilik (User A) DAPAT melihat log Private miliknya sendiri', () {
      const userAId = 'user_A';

      final privateLog = LogModel(
        id: 'priv_A',
        username: userAId,
        title: 'Catatan Privat',
        date: DateTime(2026, 3, 1),
        description: 'Hanya saya yang lihat',
        category: 'Pribadi',
        authorId: userAId,
        teamId: 'team_A',
        isPublic: false,
      );

      final publicLog = LogModel(
        id: 'pub_A',
        username: userAId,
        title: 'Catatan Publik',
        date: DateTime(2026, 3, 2),
        description: 'Semua bisa lihat',
        category: 'Pekerjaan',
        authorId: userAId,
        teamId: 'team_A',
        isPublic: true,
      );

      final userAController = LogController(
        userRole: 'Anggota',
        userId: userAId,
        teamId: 'team_A',
        mongoService: mockMongo,
        connectivityStream: const Stream.empty(),
        hiveBox: testBox,
      );
      userAController.logsNotifier.value = [privateLog, publicLog];

      // User A harus melihat KEDUA catatan (milik sendiri + public)
      final visibleToUserA = userAController.getVisibleLogs(userAId);

      expect(
        visibleToUserA.length,
        2,
        reason:
            'Pemilik harus dapat melihat semua catatannya sendiri (Private & Public)',
      );

      userAController.dispose();
    });

    test('Ketua Tim TIDAK BISA melihat log Private milik anggota', () {
      const userAId = 'user_A';
      const ketuaId = 'ketua_01';

      final privateLog = LogModel(
        id: 'priv_anggota',
        username: userAId,
        title: 'Catatan Sangat Rahasia',
        date: DateTime(2026, 3, 1),
        description: 'Rahasia anggota',
        category: 'Pribadi',
        authorId: userAId, // milik User A
        teamId: 'team_A',
        isPublic: false, // Private
      );

      final ketuaController = LogController(
        userRole: 'Ketua',
        userId: ketuaId,
        teamId: 'team_A',
        mongoService: mockMongo,
        connectivityStream: const Stream.empty(),
        hiveBox: testBox,
      );
      ketuaController.logsNotifier.value = [privateLog];

      final visibleToKetua = ketuaController.getVisibleLogs(ketuaId);

      // Ketua TIDAK BOLEH melihat log Private milik anggota
      expect(
        visibleToKetua.length,
        0,
        reason:
            'SOVEREIGNTY VIOLATION: Ketua tidak boleh melihat log Private '
            'milik anggota. Role "Ketua" tidak memberikan hak baca log Private orang lain.',
      );

      ketuaController.dispose();
    });
  });
}
