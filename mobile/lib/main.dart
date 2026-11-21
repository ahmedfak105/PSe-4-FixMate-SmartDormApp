import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'features/operations/operations_connection_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final isConfigured = supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
  const operationsOnly = bool.fromEnvironment('FIXMATE_OPERATIONS_WEB', defaultValue: false);

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
    runApp(const _OperationsConnectApp());
    return;
  }
  runApp(FixMateApp(requireLogin: isConfigured,
      operationsOnly: operationsOnly));
}

class _OperationsConnectApp extends StatefulWidget {
  const _OperationsConnectApp();

  @override
  State<_OperationsConnectApp> createState() => _OperationsConnectAppState();
}

class _OperationsConnectAppState extends State<_OperationsConnectApp> {
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    if (_connected) {
      return const FixMateApp(requireLogin: true, operationsOnly: true);
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF146B70)),
        useMaterial3: true,
      ),
      home: OperationsConnectionPage(
        onConnected: () {
          if (mounted) setState(() => _connected = true);
        },
      ),
    );
  }
}
