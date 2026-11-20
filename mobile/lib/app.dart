import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/report_repository.dart';
import 'data/repositories/supabase_report_repository.dart';
import 'features/auth/auth_gate.dart';
import 'features/bottom_tabs/bottom_tabs_cubit.dart';
import 'features/bottom_tabs/bottom_tabs_page.dart';
import 'features/reports/reports_cubit.dart';
import 'features/staff/staff_dashboard_page.dart';
import 'data/repositories/staff_reports_repository.dart';
import 'features/settings/locale_cubit.dart';
import 'l10n/gen/app_localizations.dart';
import 'navigation/route_generator.dart';

/// Offline tests use InMemoryReportRepository; authenticated app uses DB.
class FixMateApp extends StatelessWidget {
  const FixMateApp({super.key, this.repository, this.requireLogin = false});

  final ReportRepository? repository;
  final bool requireLogin;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => BottomTabsCubit()),
      BlocProvider(create: (_) => LocaleCubit()),
      if (!requireLogin)
        BlocProvider<ReportsCubit>(
          create: (_) => ReportsCubit(repository ?? InMemoryReportRepository())..load(),
        ),
    ],
    child: BlocBuilder<LocaleCubit, Locale?>(
      builder: (context, locale) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF146B70)),
          useMaterial3: true,
        ),
        home: requireLogin
            ? AuthGate(
                builder: (profile) => profile.role.trim().toLowerCase() == 'maintenance_staff'
                    ? StaffDashboardPage(
                        key: ValueKey('staff-${profile.id}'),
                        profile: profile,
                        repository: SupabaseStaffReportsRepository(
                          client: Supabase.instance.client,
                          staffId: profile.id,
                        ),
                      )
                    : BlocProvider<ReportsCubit>(
                  key: ValueKey('reports-${profile.id}'),
                  create: (_) => ReportsCubit(
                    repository ?? SupabaseReportRepository(
                      client: Supabase.instance.client,
                      residentId: profile.id,
                    ),
                  )..load(),
                  child: BottomTabsPage(profile: profile),
                ),
              )
            : const BottomTabsPage(),
        onGenerateRoute: const RouteGenerator().getRoute,
        builder: (context, child) => requireLogin
            ? child!
            : Banner(
                message: 'DEMO DATA',
                location: BannerLocation.topEnd,
                color: Colors.deepOrange,
                child: child!,
              ),
      ),
    ),
  );
}
