import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/maintenance_report.dart';
import '../../data/repositories/report_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../navigation/app_tab.dart';
import '../bottom_tabs/bottom_tabs_cubit.dart';
import '../reports/reports_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = context.read<BottomTabsCubit>();
    final isDemo = context.read<ReportsCubit>().repository is InMemoryReportRepository;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: BlocBuilder<ReportsCubit, ReportsState>(builder: (context, state) {
        final active = state.items
            .where((report) => report.status != MaintenanceStatus.resolved)
            .length;
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text(l10n.homeWelcome, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(l10n.homeIntro),
          const SizedBox(height: 16),
          if (state.loading && state.items.isEmpty)
            const LinearProgressIndicator(),
          if (state.error != null) ...[
            Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: context.read<ReportsCubit>().load,
                child: Text(l10n.retry)),
          ],
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${state.items.length}', style: Theme.of(context).textTheme.displaySmall),
              Text(l10n.totalReports),
              const SizedBox(height: 12),
              Text('$active ${l10n.activeReports}'),
            ],
          ))),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('home_new_report'),
            onPressed: () => tabs.selectTab(AppTab.newReport),
            icon: const Icon(Icons.add), label: Text(l10n.tabNewReport),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => tabs.selectTab(AppTab.myReports),
            icon: const Icon(Icons.assignment_outlined),
            label: Text(l10n.tabMyReports),
          ),
          if (isDemo) ...[
            const SizedBox(height: 24),
            Text(l10n.demoNotice, style: Theme.of(context).textTheme.bodySmall),
          ],
        ]);
      }),
    );
  }
}
