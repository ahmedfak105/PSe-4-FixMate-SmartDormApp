import 'fixmate_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'startup_mode.dart';
import 'features/operations/operations_connection_page.dart';
import 'features/auth/password_recovery_links.dart';
import 'features/notifications/fixmate_push_service.dart';
import 'features/settings/locale_cubit.dart';
import 'l10n/gen/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture the dedicated recovery marker before Supabase initializes and
  // consumes the query parameters from an emailed auth callback.
  final initialRecoveryLink = kIsWeb && isFixMateRecoveryLanding(Uri.base);

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final isConfigured = supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
  const operationsOnly = bool.fromEnvironment('FIXMATE_OPERATIONS_WEB', defaultValue: false);
  // Public GitHub Pages hosts all four roles; restricted operations mode
  // remains the default unless this explicit web-only flag is enabled.
  const residentWebFlag = bool.fromEnvironment('FIXMATE_RESIDENT_WEB', defaultValue: false);
  final allowResidentWeb = kIsWeb && operationsOnly && residentWebFlag;
  final startupMode = resolveFixMateStartupMode(
    hasPublicBackendConfig: isConfigured,
    operationsWeb: operationsOnly,
  );


  // No connected Flutter build (Android or Web) may embed privileged keys.
  if (isConfigured) {
    final problem = validateOperationsPublicConnection(supabaseUrl, supabaseKey);
    if (problem != null) {
      runApp(MaterialApp(home: Scaffold(body: Center(
        child: const Text('FixMate connection settings are invalid. Contact your administrator.'),
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
    // Firebase messaging only initializes on supported connected Android devices.
    await FixMatePushService.instance.initialize();
  } else {
    debugPrint('FixMate: No connected backend configured');
  }

  // Operations Web can configure a public connection at runtime.
  // Android and ordinary Web installations require a configured backend.
  if (operationsOnly && !kIsWeb) {
    runApp(const MaterialApp(home: Scaffold(body: Center(
      child: Text('Operations-only mode requires a Flutter Web browser.'),
    ))));
    return;
  }
  if (startupMode == FixMateStartupMode.operationsConnection) {
    // Runtime public configuration lets the same compiled web bundle be
    // deployed to staging without hardcoding or leaking server credentials.
    runApp(_OperationsConnectApp(initialRecoveryLink: initialRecoveryLink,
        allowResidentWeb: allowResidentWeb));
    return;
  }
  if (startupMode == FixMateStartupMode.connectionRequired) {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: FixMateTheme.light,
      home: Scaffold(
        appBar: AppBar(title: const Text('FixMate')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_outlined, size: 54),
                  SizedBox(height: 16),
                  Text('Unable to connect to FixMate',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text('This installation needs the connected FixMate release. '
                      'Please contact your administrator.',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    return;
  }
  runApp(FixMateApp(requireLogin: true,
      operationsOnly: operationsOnly,
      initialRecoveryLink: initialRecoveryLink,
      allowResidentWeb: allowResidentWeb));
}

class _OperationsConnectApp extends StatefulWidget {
  const _OperationsConnectApp({required this.initialRecoveryLink,
      required this.allowResidentWeb});
  final bool initialRecoveryLink;
  final bool allowResidentWeb;

  @override
  State<_OperationsConnectApp> createState() => _OperationsConnectAppState();
}

class _OperationsConnectAppState extends State<_OperationsConnectApp> {
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    if (_connected) {
      return FixMateApp(requireLogin: true, operationsOnly: true,
          initialRecoveryLink: widget.initialRecoveryLink,
          allowResidentWeb: widget.allowResidentWeb);
    }
    return BlocProvider(
      create: (_) => LocaleCubit(),
      child: BlocBuilder<LocaleCubit, Locale?>(
        builder: (context, locale) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: FixMateTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: OperationsConnectionPage(
            onConnected: () {
              if (mounted) setState(() => _connected = true);
            },
          ),
        ),
      ),
    );
  }
}
