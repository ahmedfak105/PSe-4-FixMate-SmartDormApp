import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../navigation/route_generator.dart';
import 'reports_cubit.dart';
import 'status_label.dart';

class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabMyReports),
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            icon: const Icon(Icons.refresh),
            onPressed: context.read<ReportsCubit>().load,
          ),
        ],
      ),
      body: BlocBuilder<ReportsCubit, ReportsState>(builder: (context, state) {
        if (state.loading && state.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(state.error!, textAlign: TextAlign.center),
            ),
            TextButton(
              onPressed: context.read<ReportsCubit>().load,
              child: Text(l10n.retry),
            ),
          ]));
        }
        if (state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: context.read<ReportsCubit>().load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 170),
                Center(child: Text(l10n.noReports)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: context.read<ReportsCubit>().load,
          child: ListView.builder(
            key: const Key('reports_list'),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final report = state.items[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  key: Key('report_${report.id}'),
                  leading: const Icon(Icons.home_repair_service_outlined),
                  title: Text(report.title),
                  subtitle: Text(
                    '${report.id} · ${report.category} · ${statusLabel(report.status, l10n)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.reportDetails,
                    arguments: report.id,
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
