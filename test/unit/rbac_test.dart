// test/unit/rbac_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// LAYER 1 — Unit Test: Validasi Logika RBAC (AccessControlService)
//
// Strategi: Contract Testing — setiap test memvalidasi satu "kontrak" perizinan.
// Tidak ada database, tidak ada UI, tidak ada koneksi internet.
// Ini adalah tes paling cepat dan paling murni dalam piramida pengujian.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/services/access_control_service.dart';

void main() {
  group('AccessControlService — Verifikasi Matrix Perizinan RBAC', () {
    // ──────────────────────────────────────────────────────────────────────
    // SKENARIO UTAMA: "Aksesibilitas Dokumentasi Private"
    //
    // Konteks: User A mengunggah log berformat Markdown.
    // Pertanyaan: Siapa yang berhak mengaksesnya?
    // ──────────────────────────────────────────────────────────────────────

    group('Skenario: Aksesibilitas Log Private', () {
      const authorId = 'user_A'; // Pemilik / Author

      test('User A (Pemilik/Author) → DIZINKAN untuk Update log miliknya', () {
        // Arrange
        const role = 'Anggota';
        const action = AccessControlService.actionUpdate;
        const isOwner = true; // Ini adalah milik User A

        // Act
        final result = AccessControlService.canPerform(
          role,
          action,
          isOwner: isOwner,
        );

        // Assert
        expect(
          result,
          isTrue,
          reason:
              'Anggota HARUS bisa mengupdate data miliknya sendiri ($authorId)',
        );
      });

      test(
        'User B (Rekan Satu Tim) → DITOLAK untuk Update log milik User A',
        () {
          // Arrange
          const role = 'Anggota';
          const action = AccessControlService.actionUpdate;
          const isOwner = false; // User B bukan pemilik log ini

          // Act
          final result = AccessControlService.canPerform(
            role,
            action,
            isOwner: isOwner,
          );

          // Assert
          expect(
            result,
            isFalse,
            reason: 'Anggota TIDAK BOLEH mengupdate data milik pengguna lain',
          );
        },
      );

      test(
        'Database (Cloud Sync / Ketua role) → WAJIB TERSIMPAN: bisa Insert',
        () {
          // Arrange — Ketua mewakili operasi sistem level tinggi
          const role = 'Ketua';
          const action = AccessControlService.actionCreate;

          // Act
          final result = AccessControlService.canPerform(role, action);

          // Assert
          expect(
            result,
            isTrue,
            reason: 'Ketua WAJIB bisa menyimpan data ke database',
          );
        },
      );
    });

    // ──────────────────────────────────────────────────────────────────────
    // MATRIX LENGKAP: Ketua
    // ──────────────────────────────────────────────────────────────────────
    group('Role: Ketua — Hak Akses (Task 5: Owner-Only untuk Edit/Hapus)', () {
      const role = 'Ketua';

      test('Bisa Create', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionCreate,
          ),
          isTrue,
        );
      });

      test('Bisa Read', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionRead,
          ),
          isTrue,
        );
      });

      test('Task 5 — TIDAK BISA Update data orang lain (isOwner: false)', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionUpdate,
            isOwner: false,
          ),
          isFalse,
          reason:
              'Task 5 Data Sovereignty: Hak Edit hanya milik pemilik data. '
              'Role Ketua tidak memberikan hak edit atas data orang lain.',
        );
      });

      test('Task 5 — TIDAK BISA Delete data orang lain (isOwner: false)', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionDelete,
            isOwner: false,
          ),
          isFalse,
          reason:
              'Task 5 Data Sovereignty: Hak Hapus hanya milik pemilik data. '
              'Role Ketua tidak memberikan hak hapus atas data orang lain.',
        );
      });

      test('Task 5 — BISA Update data MILIKNYA SENDIRI (isOwner: true)', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionUpdate,
            isOwner: true,
          ),
          isTrue,
          reason: 'Ketua tetap bisa mengedit data miliknya sendiri',
        );
      });

      test('Task 5 — BISA Delete data MILIKNYA SENDIRI (isOwner: true)', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionDelete,
            isOwner: true,
          ),
          isTrue,
          reason: 'Ketua tetap bisa menghapus data miliknya sendiri',
        );
      });
    });

    // ──────────────────────────────────────────────────────────────────────
    // MATRIX LENGKAP: Anggota
    // ──────────────────────────────────────────────────────────────────────
    group('Role: Anggota — Hak Akses Terbatas (Owner-Based RBAC)', () {
      const role = 'Anggota';

      test('Bisa Create', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionCreate,
          ),
          isTrue,
        );
      });

      test('Bisa Read', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionRead,
          ),
          isTrue,
        );
      });

      test('Bisa Update data MILIKNYA SENDIRI (isOwner: true)', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionUpdate,
            isOwner: true,
          ),
          isTrue,
        );
      });

      test('TIDAK BISA Update data milik orang lain (isOwner: false)', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionUpdate,
            isOwner: false,
          ),
          isFalse,
        );
      });

      test('Bisa Delete data MILIKNYA SENDIRI (isOwner: true)', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionDelete,
            isOwner: true,
          ),
          isTrue,
        );
      });

      test('TIDAK BISA Delete data milik orang lain (isOwner: false)', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionDelete,
            isOwner: false,
          ),
          isFalse,
        );
      });
    });

    // ──────────────────────────────────────────────────────────────────────
    // MATRIX LENGKAP: Asisten
    // ──────────────────────────────────────────────────────────────────────
    group('Role: Asisten — Hak Akses Read + Update', () {
      const role = 'Asisten';

      test('TIDAK BISA Create', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionCreate,
          ),
          isFalse,
          reason: 'Asisten tidak memiliki hak membuat log baru',
        );
      });

      test('Bisa Read', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionRead,
          ),
          isTrue,
        );
      });

      test('Task 5 — BISA Update data MILIKNYA SENDIRI', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionUpdate,
            isOwner: true,
          ),
          isTrue,
          reason: 'Asisten tetap bisa mengedit data miliknya sendiri',
        );
      });

      test('Task 5 — TIDAK BISA Update data orang lain (Owner-Only Rule)', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionUpdate,
            isOwner: false,
          ),
          isFalse,
          reason:
              'Task 5: Edit hanya boleh dilakukan pemilik, bukan berdasarkan role',
        );
      });

      test('Task 5 — TIDAK BISA Delete data orang lain (Owner-Only Rule)', () {
        expect(
          AccessControlService.canPerform(
            role,
            AccessControlService.actionDelete,
            isOwner: false,
          ),
          isFalse,
          reason:
              'Task 5: Hapus hanya boleh dilakukan pemilik, bukan berdasarkan role',
        );
      });
    });

    // ──────────────────────────────────────────────────────────────────────
    // EDGE CASE: Role tidak dikenal
    // ──────────────────────────────────────────────────────────────────────
    group('Edge Case: Role Tidak Terdaftar', () {
      test('Role tidak dikenal → semua aksi DITOLAK', () {
        const unknownRole = 'Supervisor';
        expect(
          AccessControlService.canPerform(
            unknownRole,
            AccessControlService.actionRead,
          ),
          isFalse,
          reason:
              'Role yang tidak terdaftar harus ditolak secara default (Fail-Safe)',
        );
      });
    });

    // ──────────────────────────────────────────────────────────────────────
    // UI Helper: roleBadge
    // ──────────────────────────────────────────────────────────────────────
    group('roleBadge — Label Tampilan UI', () {
      test('Ketua mendapat badge', () {
        expect(AccessControlService.roleBadge('Ketua'), contains('Ketua'));
      });

      test('Asisten mendapat badge', () {
        expect(AccessControlService.roleBadge('Asisten'), contains('Asisten'));
      });

      test('Anggota mendapat badge', () {
        expect(AccessControlService.roleBadge('Anggota'), contains('Anggota'));
      });
    });
  });
}
