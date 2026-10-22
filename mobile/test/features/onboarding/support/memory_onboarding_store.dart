import 'package:mobile/features/onboarding/data/onboarding_store.dart';

class MemoryOnboardingStore extends OnboardingStore {
  MemoryOnboardingStore({this.completed = false});

  bool completed;
  int reads = 0;
  int writes = 0;
  bool failWrite = false;
  Future<void> Function()? beforeWrite;

  @override
  Future<bool> hasCompleted() async {
    reads++;
    return completed;
  }

  @override
  Future<void> complete() async {
    writes++;
    await beforeWrite?.call();
    if (failWrite) throw StateError('Storage unavailable');
    completed = true;
  }
}
