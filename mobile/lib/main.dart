import 'fixmate_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'features/operations/operations_connection_page.dart';
import 'features/auth/password_recovery_links.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture the dedicated recovery marker before Supabase initializes and
  // consumes the query parameters from an emailed auth callback.
  final initialRecoveryLink = kIsWeb && isFixMateRecoveryLanding(Uri.base);

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final isConfigured = supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
  const operationsOnly = bool.fromEnvironment('FIXMATE_OPERATIONS_WEB', defaultValue: false);

  // Validate build-time public credentials as carefully as the runtime
  // connection screen. Legacy service_role JWTs must never reach a Web client.
  if (operationsOnly && isConfigured) {
    final problem = validateOperationsPublicConnection(supabaseUrl, supabaseKey);
    if (problem != null) {
      runApp(MaterialApp(home: Scaffold(body: Center(
        child: Text('Invalid operations Supabase configuration: $problem'),
      ))));
      return;
    }
  }

  if (isConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
    );
    debugPrint('FixMate: Supabase initialized');
  } else {
    debugPrint('FixMate: Running offline demo (Supabase not configured)');
  }

  // A browser operations build must never silently fall back to DEMO DATA.
  // Resident/Staff mobile mode retains its existing offline test/demo option.
  if (operationsOnly && !kIsWeb) {
    runApp(const MaterialApp(home: Scaffold(body: Center(
      child: Text('Operations-only mode requires a Flutter Web browser.'),
    ))));
    return;
  }
  if (operationsOnly && !isConfigured) {
    // Runtime public configuration lets the same compiled web bundle be
    // deployed to staging without hardcoding or leaking server credentials.
    runApp(_OperationsConnectApp(initialRecoveryLink: initialRecoveryLink));
    return;
  }
  runApp(FixMateApp(requireLogin: isConfigured,
      operationsOnly: operationsOnly,
      initialRecoveryLink: initialRecoveryLink));
}

class _OperationsConnectApp extends StatefulWidget {
  const _OperationsConnectApp({required this.initialRecoveryLink});
  final bool initialRecoveryLink;

  @override
  State<_OperationsConnectApp> createState() => _OperationsConnectAppState();
}

class _OperationsConnectAppState extends State<_OperationsConnectApp> {
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    if (_connected) {
      return FixMateApp(requireLogin: true, operationsOnly: true,
          initialRecoveryLink: widget.initialRecoveryLink);
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: FixMateTheme.light,
      home: OperationsConnectionPage(
        onConnected: () {
          if (mounted) setState(() => _connected = true);
        },
      ),
    );
  }
}
