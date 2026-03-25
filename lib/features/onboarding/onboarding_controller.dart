class OnboardingController {
  static const int totalSteps = 3;

  int _step = 1;

  int get step => _step;
  bool get isLastStep => _step >= totalSteps;

  /// Mengembalikan true jika onboarding selesai dan harus pindah ke Login.
  bool nextStep() {
    if (_step < totalSteps) {
      _step++;
      return false;
    }
    return true;
  }

  void reset() {
    _step = 1;
  }
}
