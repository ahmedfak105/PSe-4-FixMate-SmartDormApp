import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../navigation/app_tab.dart';

/// Tab icon. Place for a counter like Barbora's `CartIcon`:
/// ```dart
/// Badge(isLabelVisible: count > 0, label: Text('$count'), child: icon)
/// ```
class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.tab, required this.selected});

  final AppTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) => Icon(selected ? tab.selectedIcon : tab.icon);
}

/// Phone: Material 3 bottom bar.
class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({super.key, required this.selected, required this.onSelected});

  final AppTab selected;
  final ValueChanged<AppTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NavigationBar(
      selectedIndex: selected.index,
      onDestinationSelected: (index) => onSelected(AppTab.values[index]),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final tab in AppTab.values)
          NavigationDestination(
            key: tab.navigationKey,
            icon: _TabIcon(tab: tab, selected: false),
            selectedIcon: _TabIcon(tab: tab, selected: true),
            label: tab.label(l10n),
          ),
      ],
    );
  }
}

/// Tablet / landscape (width ≥ 600 dp): side rail with the same tabs.
class AppNavigationRail extends StatelessWidget {
  const AppNavigationRail({super.key, required this.selected, required this.onSelected});

  final AppTab selected;
  final ValueChanged<AppTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NavigationRail(
      selectedIndex: selected.index,
      onDestinationSelected: (index) => onSelected(AppTab.values[index]),
      labelType: NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Icon(Icons.home_repair_service_outlined, size: 32),
      ),
      destinations: [
        for (final tab in AppTab.values)
          NavigationRailDestination(
            icon: KeyedSubtree(key: tab.navigationKey, child: _TabIcon(tab: tab, selected: false)),
            selectedIcon: KeyedSubtree(key: tab.navigationKey, child: _TabIcon(tab: tab, selected: true)),
            label: Text(tab.label(l10n)),
          ),
      ],
    );
  }
}
