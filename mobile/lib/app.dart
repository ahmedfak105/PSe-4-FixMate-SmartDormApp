import 'fixmate_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/report_repository.dart';
import 'data/repositories/supabase_report_repository.dart';
import 'features/auth/auth_gate.dart';
import 'features/operations/operations_role.dart';
import 'features/operations/admin_operations_page.dart';
import 'features/operations/moderator_operations_page.dart';
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
  const FixMateApp({super.key, this.repository, this.requireLogin = false,
      this.operationsOnly = false});

  final ReportRepository? repository;
  final bool requireLogin;
  final bool operationsOnly;

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
        theme: FixMateTheme.light,
        home: requireLogin
            ? AuthGate(
                operationsOnly: operationsOnly,
                builder: (profile) => switch (workspaceForRole(profile.role,
                    operationsOnly: operationsOnly)) {
                    FixMateWorkspace.systemAdmin =>
                      AdminOperationsPage(
                        key: ValueKey('admin-${profile.id}'),
                        profile: profile,
                      ),
                    FixMateWorkspace.moderator =>
                      ModeratorOperationsPage(
                        key: ValueKey('moderator-${profile.id}'),
                        profile: profile,
                      ),
                    FixMateWorkspace.maintenanceStaff => StaffDashboardPage(
                        key: ValueKey('staff-${profile.id}'),
                        profile: profile,
                        repository: SupabaseStaffReportsRepository(
                          client: Supabase.instance.client,
                          staffId: profile.id,
                        ),
                      ),
                    FixMateWorkspace.resident => BlocProvider<ReportsCubit>(
                  key: ValueKey('reports-${profile.id}'),
                  create: (_) => ReportsCubit(
                    repository ?? SupabaseReportRepository(
                      client: Supabase.instance.client,
                      residentId: profile.id,
                    ),
                  )..load(),
                  child: BottomTabsPage(profile: profile),
                ),
                FixMateWorkspace.denied => const Scaffold(
                  body: Center(child: Text('This role cannot enter the selected workspace.')),
                ),
              },
              )
            : const BottomTabsPage(),
        // Operations build has no Resident navigation routes. Its only
        // entry point is the authenticated, role-gated AuthGate.
        onGenerateRoute: operationsOnly ? null : const RouteGenerator().getRoute,
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
