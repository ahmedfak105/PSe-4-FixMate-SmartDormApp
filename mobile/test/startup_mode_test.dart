import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/startup_mode.dart';

void main() {
  test('connected releases require the real backend and never load fixtures', () {
    for (final operations in [false, true]) {
      for (final demo in [false, true]) {
        expect(
          resolveFixMateStartupMode(
            hasPublicBackendConfig: true,
            operationsWeb: operations,
            explicitlyAllowOfflineDemo: demo,
          ),
          FixMateStartupMode.connected,
        );
      }
    }
  });

  test('unconfigured normal app cannot silently show demo reports', () {
    expect(
      resolveFixMateStartupMode(
        hasPublicBackendConfig: false,
        operationsWeb: false,
        explicitlyAllowOfflineDemo: false,
      ),
      FixMateStartupMode.connectionRequired,
    );
  });

  test('offline demo requires an explicit build flag', () {
    expect(
      resolveFixMateStartupMode(
        hasPublicBackendConfig: false,
        operationsWeb: false,
        explicitlyAllowOfflineDemo: true,
      ),
      FixMateStartupMode.offlineDemo,
    );
  });

  test('operations browser always chooses its connection screen', () {
    for (final demo in [false, true]) {
      expect(
        resolveFixMateStartupMode(
          hasPublicBackendConfig: false,
          operationsWeb: true,
          explicitlyAllowOfflineDemo: demo,
        ),
        FixMateStartupMode.operationsConnection,
      );
    }
  });
}
