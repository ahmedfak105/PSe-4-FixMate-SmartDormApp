/// Select only authenticated Supabase connection paths.
/// An unconfigured installation never opens synthetic maintenance data.
enum FixMateStartupMode {
  connected,
  operationsConnection,
  connectionRequired,
}

FixMateStartupMode resolveFixMateStartupMode({
  required bool hasPublicBackendConfig,
  required bool operationsWeb,
}) {
  if (hasPublicBackendConfig) return FixMateStartupMode.connected;
  if (operationsWeb) return FixMateStartupMode.operationsConnection;
  return FixMateStartupMode.connectionRequired;
}
