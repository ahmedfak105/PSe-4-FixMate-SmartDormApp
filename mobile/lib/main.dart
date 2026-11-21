import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final isConfigured = supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  if (isConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
    );
    debugPrint('FixMate: Supabase initialized');
  } else {
    debugPrint('FixMate: Running offline demo (Supabase not configured)');
  }

  runApp(FixMateApp(requireLogin: isConfigured));
}
