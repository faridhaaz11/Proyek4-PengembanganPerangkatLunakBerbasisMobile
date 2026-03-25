import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/features/auth/login_controller.dart';

void main() {
  group('LoginController', () {
    late LoginController controller;

    setUp(() {
      controller = LoginController();
    });

    test('gagal jika username kosong', () {
      final result = controller.attemptLogin('', '123');

      expect(result.status, LoginActionStatus.error);
      expect(result.message, 'Username tidak boleh kosong!');
      expect(controller.loginAttempts, 0);
      expect(controller.isLoginDisabled, false);
    });

    test('gagal jika password kosong', () {
      final result = controller.attemptLogin('admin', '');

      expect(result.status, LoginActionStatus.error);
      expect(result.message, 'Password tidak boleh kosong!');
      expect(controller.loginAttempts, 0);
      expect(controller.isLoginDisabled, false);
    });

    test('berhasil login dan mengembalikan role', () {
      final result = controller.attemptLogin('admin', '123');

      expect(result.status, LoginActionStatus.success);
      expect(result.role, 'Ketua');
      expect(controller.loginAttempts, 0);
      expect(controller.isLoginDisabled, false);
    });

    test('lock setelah 3x gagal', () {
      controller.attemptLogin('admin', 'x');
      controller.attemptLogin('admin', 'y');
      final result = controller.attemptLogin('admin', 'z');

      expect(result.status, LoginActionStatus.error);
      expect(result.shouldStartCountdown, true);
      expect(result.message, 'Terlalu banyak percobaan! Tunggu 10 detik.');
      expect(controller.loginAttempts, 3);
      expect(controller.isLoginDisabled, true);
      expect(controller.countdown, 10);
    });

    test('saat lock, login ditolak dengan sisa countdown', () {
      controller.attemptLogin('admin', 'x');
      controller.attemptLogin('admin', 'y');
      controller.attemptLogin('admin', 'z');
      controller.tickCountdown();

      final result = controller.attemptLogin('admin', '123');

      expect(result.status, LoginActionStatus.error);
      expect(result.message, 'Terlalu banyak percobaan! Tunggu 9 detik.');
      expect(controller.isLoginDisabled, true);
      expect(controller.countdown, 9);
    });

    test('countdown selesai membuka lock dan reset attempts', () {
      controller.attemptLogin('admin', 'x');
      controller.attemptLogin('admin', 'y');
      controller.attemptLogin('admin', 'z');

      for (var i = 0; i < 10; i++) {
        controller.tickCountdown();
      }

      expect(controller.isLoginDisabled, false);
      expect(controller.countdown, 0);
      expect(controller.loginAttempts, 0);

      final result = controller.attemptLogin('admin', '123');
      expect(result.status, LoginActionStatus.success);
      expect(result.role, 'Ketua');
    });
  });
}
