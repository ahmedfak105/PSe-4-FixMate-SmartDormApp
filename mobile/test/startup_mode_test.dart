import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/startup_mode.dart';

void main() {
  test('all configured clients use a real authenticated backend', () {
    for (final operations in [false, true]) {
      expect(
        resolveFixMateStartupMode(
          hasPublicBackendConfig: true,
          operationsWeb: operations,
        ),
        FixMateStartupMode.connected,
      );
    }
  });

  test('unconfigured Android/general Web displays connection required', () {
    expect(
      resolveFixMateStartupMode(
        hasPublicBackendConfig: false,
        operationsWeb: false,
      ),
      FixMateStartupMode.connectionRequired,
    );
  });

  test('unconfigured operations Web opens only the public connection form', () {
    expect(
      resolveFixMateStartupMode(
        hasPublicBackendConfig: false,
        operationsWeb: true,
      ),
      FixMateStartupMode.operationsConnection,
    );
  });

  test('no offline or fixture startup mode exists', () {
    expect(
      FixMateStartupMode.values.map((mode) => mode.name),
      ['connected', 'operationsConnection', 'connectionRequired'],
    );
  });
}
