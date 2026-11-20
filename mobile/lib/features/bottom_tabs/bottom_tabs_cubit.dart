import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../navigation/app_tab.dart';

/// Which tab is selected + the Navigator of every tab.
///
/// Same responsibilities as `BottomTabsBloc` + `RouterCubit` in the Barbora app:
/// * each tab has its OWN navigation stack (`GlobalKey<NavigatorState>`)
/// * tapping the selected tab again → back to the tab's first screen
/// * any screen can switch tabs or open a screen in another tab
///   (`context.read<BottomTabsCubit>().openInTab(...)`)
/// * Android back: pop inside the tab → go to the first tab → ask to exit
class BottomTabsCubit extends Cubit<AppTab> {
  BottomTabsCubit() : super(AppTab.initial);

  final Map<AppTab, GlobalKey<NavigatorState>> _navigatorKeys = {
    for (final tab in AppTab.values) tab: GlobalKey<NavigatorState>(debugLabel: 'tab_${tab.name}'),
  };

  GlobalKey<NavigatorState> navigatorKeyFor(AppTab tab) => _navigatorKeys[tab]!;

  NavigatorState? _navigatorOf(AppTab tab) => _navigatorKeys[tab]!.currentState;

  /// Called by the bottom bar / navigation rail.
  void selectTab(AppTab tab) {
    if (tab == state) {
      popToRoot(tab);
    } else {
      emit(tab);
    }
  }

  /// Back to the first screen of [tab] (default: the selected tab).
  void popToRoot([AppTab? tab]) {
    _navigatorOf(tab ?? state)?.popUntil((route) => route.isFirst);
  }

  /// Switches to [tab] and opens [routeName] there, e.g. from the Home tab:
  /// `openInTab(AppTab.screen2, AppRoutes.studentDetails, arguments: id)`.
  Future<T?> openInTab<T>(AppTab tab, String routeName, {Object? arguments}) async {
    emit(tab);
    // A tab is built the first time it is shown – wait one frame for its Navigator.
    if (_navigatorOf(tab) == null) await WidgetsBinding.instance.endOfFrame;
    final navigator = _navigatorOf(tab);
    if (navigator == null) return null;
    navigator.popUntil((route) => route.isFirst);
    return navigator.pushNamed<T>(routeName, arguments: arguments);
  }

  /// Android back button / predictive back.
  /// Returns `false` when nothing is left to go back to – the page then asks
  /// whether to exit the app.
  Future<bool> handleBack() async {
    final navigator = _navigatorOf(state);
    if (navigator != null && await navigator.maybePop()) return true;
    if (state != AppTab.initial) {
      emit(AppTab.initial);
      return true;
    }
    return false;
  }
}
