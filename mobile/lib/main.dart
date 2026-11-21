import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

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
  if (operationsOnly && (!kIsWeb || !isConfigured)) {
    runApp(const MaterialApp(home: Scaffold(body: Center(
      child: Text('Flutter Web operations requires Chrome and a Supabase '
          'URL + publishable/anon key. No offline admin access is available.'),
    ))));
    return;
  }
  runApp(FixMateApp(requireLogin: isConfigured,
      operationsOnly: operationsOnly));
}
