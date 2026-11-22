import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/resident_profile.dart';
import '../../navigation/app_tab.dart';
import '../home/home_page.dart';
import '../reports/my_reports_page.dart';
import '../reports/new_report_page.dart';
import '../settings/profile_page.dart';
import 'bottom_tabs_cubit.dart';
import 'widgets/app_navigation.dart';
import 'widgets/exit_app_dialog.dart';
import 'widgets/tab_navigator.dart';

/// Based on Tadas's independent Navigator per tab / IndexedStack skeleton.
class BottomTabsPage extends StatefulWidget {
  const BottomTabsPage({super.key, this.profile});
  /// Null only for isolated widget tests; real accounts always have profiles.
  final ResidentProfile? profile;
  static const tabletBreakpoint = 600.0;
  @override
  State<BottomTabsPage> createState() => _BottomTabsPageState();
}
class _BottomTabsPageState extends State<BottomTabsPage> {
  final Set<AppTab> _visitedTabs = {AppTab.initial};
  Widget _rootPageFor(AppTab tab) => switch (tab) {
    AppTab.home => const HomePage(),
    AppTab.myReports => const MyReportsPage(),
    AppTab.newReport => const NewReportPage(),
    AppTab.profile => ProfilePage(profile: widget.profile),
  };
  Future<void> _onBack(bool didPop, Object? result) async {
    if (didPop) return;
    final cubit = context.read<BottomTabsCubit>();
    if (await cubit.handleBack()) return;
    if (!mounted) return;
    if (await showExitAppDialog(context)) await SystemNavigator.pop();
  }
  void _onTabChanged(BuildContext context, AppTab tab) {
    if (kDebugMode) debugPrint('FixMate tab: ${tab.name}');
  }
  @override
  Widget build(BuildContext context) => BlocConsumer<BottomTabsCubit, AppTab>(
    listener: _onTabChanged,
    builder: (context, selected) {
      _visitedTabs.add(selected);
      final cubit = context.read<BottomTabsCubit>();
      final body = IndexedStack(
        index: selected.index,
        children: [for (final tab in AppTab.values)
          TickerMode(
            enabled: tab == selected,
            child: _visitedTabs.contains(tab)
              ? TabNavigator(navigatorKey: cubit.navigatorKeyFor(tab), rootPage: _rootPageFor(tab))
              : const SizedBox.shrink(),
          ),
        ],
      );
      final isWide = MediaQuery.sizeOf(context).width >= BottomTabsPage.tabletBreakpoint;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: _onBack,
        child: isWide
          ? Scaffold(body: SafeArea(child: Row(children: [
              AppNavigationRail(selected: selected, onSelected: cubit.selectTab),
              const VerticalDivider(width: 1), Expanded(child: body),
            ])))
          : Scaffold(body: body, bottomNavigationBar: AppBottomNavigationBar(
              selected: selected, onSelected: cubit.selectTab,
            )),
      );
    },
  );
}
