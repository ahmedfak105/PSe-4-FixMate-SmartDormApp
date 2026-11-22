import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';

enum AppTab {
  home(Icons.home_outlined, Icons.home),
  myReports(Icons.assignment_outlined, Icons.assignment),
  newReport(Icons.add_circle_outline, Icons.add_circle),
  profile(Icons.person_outline, Icons.person);

  const AppTab(this.icon, this.selectedIcon);
  final IconData icon;
  final IconData selectedIcon;
  static const initial = AppTab.home;
  String label(AppLocalizations l10n) => switch (this) {
    AppTab.home => l10n.tabHome,
    AppTab.myReports => l10n.tabMyReports,
    AppTab.newReport => l10n.tabNewReport,
    AppTab.profile => l10n.tabProfile,
  };
  Key get navigationKey => Key('tab_$name');
}
