import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/features/auth/login_controller.dart';

void main() {
  group('Module 2 - Authentication (attemptLogin)', () {
    late LoginController controller;

    setUp(() {
      controller = LoginController();
    });

    test('TC01 - gagal jika username kosong', () {
      final result = controller.attemptLogin('', '123');

      expect(result.status, LoginActionStatus.error);
      expect(result.message, 'Username tidak boleh kosong!');
    });

    test('TC02 - login valid harus mengembalikan role admin', () {
      final result = controller.attemptLogin('admin', '123');

      expect(result.status, LoginActionStatus.success);
      expect(result.role, 'admin');
    });

    test('TC03 - lock setelah 3x gagal', () {
      controller.attemptLogin('admin', 'x');
      controller.attemptLogin('admin', 'y');
      final result = controller.attemptLogin('admin', 'z');

      expect(result.status, LoginActionStatus.error);
      expect(result.shouldStartCountdown, true);
      expect(result.message, 'Terlalu banyak percobaan! Tunggu 10 detik.');
      expect(controller.isLoginDisabled, true);
      expect(controller.countdown, 10);
    });
  });
}
