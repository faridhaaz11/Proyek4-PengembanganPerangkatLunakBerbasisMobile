import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/features/counter/counter_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  dynamic actual;
  dynamic expected;

  group('Module 1 - CounterController (with storage & step)', () {
    late CounterController controller;
    const username = 'admin';

    setUp(() async {
      // (1) setup (arrange, build)
      SharedPreferences.setMockInitialValues({});
      controller = CounterController();
      controller.setUsername(username);
      await controller.loadLastValue();
    });

    test('initial value should be 0', () {
      // (2) exercise (act, operate)
      actual = controller.value;
      expected = 0;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('setStep should change step value', () {
      // (2) exercise (act, operate)
      controller.setStep(5);
      actual = controller.step;
      expected = 5;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('setStep should ignore negative value', () {
      // (1) setup (arrange, build)
      controller.setStep(3);

      // (2) exercise (act, operate)
      controller.setStep(-1);
      actual = controller.step;
      expected = 3;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('increment should increase counter based on step', () async {
      // (1) setup (arrange, build)
      controller.setStep(2);

      // (2) exercise (act, operate)
      await controller.increment();
      actual = controller.value;
      expected = 2;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('decrement should decrease counter based on step', () async {
      // (1) setup (arrange, build)
      controller.setStep(2);
      await controller.increment();

      // (2) exercise (act, operate)
      await controller.decrement();
      actual = controller.value;
      expected = 0;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('decrement can go below zero in current implementation', () async {
      // (1) setup (arrange, build)
      controller.setStep(5);

      // (2) exercise (act, operate)
      await controller.decrement();
      actual = controller.value;
      expected = -5;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('reset should set counter to zero', () async {
      // (1) setup (arrange, build)
      await controller.increment();

      // (2) exercise (act, operate)
      await controller.reset();
      actual = controller.value;
      expected = 0;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('history should record actions', () async {
      // (1) setup (arrange, build)
      controller.setStep(1);

      // (2) exercise (act, operate)
      await controller.increment();
      final actual1 = controller.history.isNotEmpty;
      const expected1 = true;
      final actual2 = controller.history.first.contains('menambahkan');
      const expected2 = true;

      // (3) verify (assert, check)
      expect(
        actual1,
        expected1,
        reason: 'Expected $expected1 but got $actual1',
      );
      expect(
        actual2,
        expected2,
        reason: 'Expected $expected2 but got $actual2',
      );
    });

    test('history should not exceed 5 items', () async {
      // (1) setup (arrange, build)
      controller.setStep(1);

      // (2) exercise (act, operate)
      for (int i = 0; i < 6; i++) {
        await controller.increment();
      }
      actual = controller.history.length;
      expected = 5;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });

    test('counter should persist using SharedPreferences', () async {
      // (1) setup (arrange, build)
      controller.setStep(3);
      await controller.increment();

      // Buat instance baru (simulasi app restart)
      final newController = CounterController();
      newController.setUsername(username);

      // (2) exercise (act, operate)
      await newController.loadLastValue();
      actual = newController.value;
      expected = 3;

      // (3) verify (assert, check)
      expect(actual, expected, reason: 'Expected $expected but got $actual');
    });
  });
}
