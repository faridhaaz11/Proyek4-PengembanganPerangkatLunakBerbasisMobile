import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/features/onboarding/onboarding_controller.dart';

void main() {
  group('OnboardingController', () {
    late OnboardingController controller;

    setUp(() {
      controller = OnboardingController();
    });

    test('state awal di step 1 dan belum step terakhir', () {
      expect(controller.step, 1);
      expect(controller.isLastStep, false);
    });

    test('nextStep menaikkan step sampai step terakhir', () {
      final first = controller.nextStep();
      final second = controller.nextStep();

      expect(first, false);
      expect(second, false);
      expect(controller.step, 3);
      expect(controller.isLastStep, true);
    });

    test('nextStep pada step terakhir mengembalikan true', () {
      controller.nextStep();
      controller.nextStep();

      final shouldGoToLogin = controller.nextStep();

      expect(shouldGoToLogin, true);
      expect(controller.step, 3);
      expect(controller.isLastStep, true);
    });

    test('reset mengembalikan state ke step awal', () {
      controller.nextStep();
      controller.nextStep();

      controller.reset();

      expect(controller.step, 1);
      expect(controller.isLastStep, false);
    });
  });
}
