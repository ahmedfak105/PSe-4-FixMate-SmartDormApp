import 'package:flutter/material.dart';
import '../../l10n/fixmate_i18n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/maintenance_report.dart';
import '../../data/repositories/report_repository.dart';
import '../../fixmate_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../navigation/app_tab.dart';
import '../bottom_tabs/bottom_tabs_cubit.dart';
import '../reports/reports_cubit.dart';
import '../notifications/resident_notifications_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = context.read<BottomTabsCubit>();
    final isDemo = context.read<ReportsCubit>().repository is InMemoryReportRepository;
    return Scaffold(
      appBar: AppBar(
        title: FixMateText(l10n.appTitle),
        actions: [
          if (!isDemo)
            IconButton(
              key: const Key('open_resident_notifications'),
              tooltip: fmTr(context, 'Notifications'),
              icon: const Icon(Icons.notifications_none_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ResidentNotificationsPage(),
                ),
              ),
            ),
        ],
      ),
      body: BlocBuilder<ReportsCubit, ReportsState>(builder: (context, state) {
        final active = state.items
            .where((report) => report.status != MaintenanceStatus.resolved).length;
        final resolved = state.items.length - active;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(23),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D675F), Color(0xFF127F76)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FixMateText('SMART DORM MAINTENANCE',
                    style: TextStyle(color: Color(0xFFCEF1E7), fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1.3)),
                  const SizedBox(height: 10),
                  FixMateText(l10n.homeWelcome,
                    style: const TextStyle(color: Colors.white, fontSize: 25,
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  FixMateText(l10n.homeIntro,
                    style: const TextStyle(color: Color(0xFFE1F6EE), fontSize: 13)),
                  const SizedBox(height: 19),
                  FilledButton.icon(
                    key: const Key('home_new_report'),
                    onPressed: () => tabs.selectTab(AppTab.newReport),
                    style: FilledButton.styleFrom(
                      foregroundColor: FixMateTheme.teal,
                      backgroundColor: Colors.white),
                    icon: const Icon(Icons.add_circle_outline),
                    label: FixMateText(l10n.tabNewReport),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (state.loading && state.items.isEmpty)
              const LinearProgressIndicator(),
            if (state.error != null) ...[
              FixMateText(state.error!, style: TextStyle(
                color: Theme.of(context).colorScheme.error)),
              TextButton(onPressed: context.read<ReportsCubit>().load,
                child: FixMateText(l10n.retry)),
            ],
            Row(children: [
              Expanded(child: _HomeStat(
                value: '${state.items.length}', label: l10n.totalReports,
                icon: Icons.description_outlined)),
              const SizedBox(width: 9),
              Expanded(child: _HomeStat(
                value: '$active', label: l10n.activeReports,
                icon: Icons.pending_actions_outlined)),
              const SizedBox(width: 9),
              Expanded(child: _HomeStat(
                value: '$resolved', label: 'Resolved',
                icon: Icons.check_circle_outline)),
            ]),
            const SizedBox(height: 24),
            FixMateText('Quick actions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: const Icon(Icons.assignment_outlined,
                  color: FixMateTheme.teal, size: 30),
                title: FixMateText(l10n.tabMyReports,
                  style: Theme.of(context).textTheme.titleMedium),
                subtitle: const FixMateText('Review updates on your maintenance requests'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => tabs.selectTab(AppTab.myReports),
              ),
            ),
            if (isDemo) ...[
              const SizedBox(height: 22),
              FixMateText(l10n.demoNotice,
                style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        );
      }),
    );
  }
}

class _HomeStat extends StatelessWidget {
  const _HomeStat({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FixMateTheme.teal, size: 20),
          const SizedBox(height: 12),
          FixMateText(value, style: const TextStyle(fontSize: 24,
            fontWeight: FontWeight.w800, color: FixMateTheme.ink)),
          const SizedBox(height: 4),
          FixMateText(label, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7F8D))),
        ],
      ),
    ),
  );
}
