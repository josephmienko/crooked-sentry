import 'package:flutter_test/flutter_test.dart';
import 'package:home_dashboard/core/services/config_service.dart';

/// Test helper to load config before running widget tests.
Future<void> loadTestConfig() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (!ConfigService.isLoaded) {
    await ConfigService.load();
  }
}

/// Reset config between tests.
void resetTestConfig() {
  ConfigService.reset();
}
