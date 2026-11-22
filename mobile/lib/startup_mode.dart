/// Startup paths are deliberately distinct: an unconfigured installed app
/// cannot silently fall into the in-memory lecturer/demo repository.
enum FixMateStartupMode {
  connected,
  operationsConnection,
  offlineDemo,
  connectionRequired,
}

FixMateStartupMode resolveFixMateStartupMode({
  required bool hasPublicBackendConfig,
  required bool operationsWeb,
  required bool explicitlyAllowOfflineDemo,
}) {
  if (hasPublicBackendConfig) return FixMateStartupMode.connected;
  if (operationsWeb) return FixMateStartupMode.operationsConnection;
  return explicitlyAllowOfflineDemo
      ? FixMateStartupMode.offlineDemo
      : FixMateStartupMode.connectionRequired;
}
