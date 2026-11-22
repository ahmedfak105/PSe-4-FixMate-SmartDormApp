import 'package:flutter/foundation.dart';

/// Explicit callback so Supabase's recovery email returns to FixMate rather
/// than an unrelated Site URL. Every callback must be allowlisted in Supabase
/// Auth > URL Configuration before a hosted reset email can complete.
String fixMatePasswordRecoveryRedirect() {
  const override = String.fromEnvironment('FIXMATE_PASSWORD_RESET_REDIRECT_URL');
  if (override.isNotEmpty) return override;
  if (kIsWeb) {
    // Keep GitHub Pages' project subpath. Never include credentials from an
    // existing URL fragment or an old OAuth/recovery callback query.
    return Uri.base.replace(
      queryParameters: const {'fixmate_recovery': '1'},
      fragment: '',
    ).toString();
  }
  // Android intent filter is registered in AndroidManifest.xml. iOS has not
  // been configured and must be given an explicit override when supported.
  return 'com.fixmate.smartdorm://reset-password';
}

/// Provides a fallback for browsers in which the SDK completes a recovery
/// session during Supabase.initialize, before AuthGate mounts its listener.
/// Do not show a password form unless a real Supabase session also exists.
bool isFixMateRecoveryLanding(Uri uri) =>
    uri.queryParameters['fixmate_recovery'] == '1';
