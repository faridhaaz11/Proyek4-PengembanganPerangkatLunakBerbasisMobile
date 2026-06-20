import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/features/counter/counter_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CounterController', () {
    late CounterController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = CounterController();
      controller.setUsername('admin');
    });

    test('TC01 - loadLastValue default should be 0 for new user', () async {
      final value = await controller.loadLastValue();

      expect(value, 0);
      expect(controller.value, 0);
    });

    test('TC02 - setStep should change step for positive value', () {
      controller.setStep(5);

      expect(controller.step, 5);
    });

    test('TC03 - setStep should ignore negative value', () {
      controller.setStep(3);
      controller.setStep(-1);

      expect(controller.step, 3);
    });

    test('TC04 - increment should add counter by step', () async {
      controller.setStep(2);

      await controller.increment();

      expect(controller.value, 2);
      expect(
        controller.history.last.contains('menambahkan nilai sebesar 2'),
        true,
      );
    });

    test('TC05 - decrement should subtract counter by step', () async {
      controller.setStep(3);
      await controller.increment();
      await controller.increment();

      await controller.decrement();

      expect(controller.value, 3);
      expect(
        controller.history.last.contains('mengurangi nilai sebesar 3'),
        true,
      );
    });

    test(
      'TC06 - decrement allows negative counter when step exceeds value',
      () async {
        controller.setStep(2);
        await controller.increment();
        controller.setStep(5);

        await controller.decrement();

        expect(controller.value, -3);
      },
    );

    test('TC07 - reset should set counter to 0', () async {
      controller.setStep(4);
      await controller.increment();

      await controller.reset();

      expect(controller.value, 0);
      expect(controller.history.last.contains('mereset counter ke 0'), true);
    });

    test('TC08 - history should keep only latest 5 entries', () async {
      controller.setStep(1);
      await controller.increment();
      await controller.increment();
      await controller.increment();
      await controller.increment();
      await controller.increment();
      await controller.increment();

      expect(controller.history.length, 5);
    });

    test(
      'TC09 - loadHistory should trim persisted history to latest 5 items',
      () async {
        SharedPreferences.setMockInitialValues({
          'history_log_admin': ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'],
        });

        controller = CounterController();
        controller.setUsername('admin');

        await controller.loadHistory();

        expect(controller.history.length, 5);
        expect(controller.history.first, 'h2');
        expect(controller.history.last, 'h6');
      },
    );

    test(
      'TC10 - saveAllData and loadAllData should persist value and history',
      () async {
        controller.setStep(2);
        await controller.increment();
        await controller.increment();

        final reloaded = CounterController();
        reloaded.setUsername('admin');
        await reloaded.loadAllData();

        expect(reloaded.value, 4);
        expect(reloaded.history.isNotEmpty, true);
      },
    );
  });
}
