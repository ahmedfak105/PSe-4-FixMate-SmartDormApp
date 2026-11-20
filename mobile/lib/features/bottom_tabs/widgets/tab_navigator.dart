import 'package:flutter/material.dart';

import '../../../navigation/route_generator.dart';

/// One tab = one Navigator (Barbora: `BottomTab.page`).
///
/// [rootPage] is the first screen of the tab. Screens opened with
/// `Navigator.of(context).pushNamed(...)` inside the tab are stacked here,
/// so the bottom bar stays visible and every tab remembers where it was.
class TabNavigator extends StatefulWidget {
  const TabNavigator({super.key, required this.navigatorKey, required this.rootPage});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget rootPage;

  @override
  State<TabNavigator> createState() => _TabNavigatorState();
}

class _TabNavigatorState extends State<TabNavigator> {
  static const _routeGenerator = RouteGenerator();

  // A nested Navigator needs its own HeroController for Hero animations.
  final HeroController _heroController = MaterialApp.createMaterialHeroController();

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HeroControllerScope(
      controller: _heroController,
      child: Navigator(
        key: widget.navigatorKey,
        onGenerateInitialRoutes: (navigator, initialRoute) => [
          MaterialPageRoute<void>(builder: (_) => widget.rootPage),
        ],
        onGenerateRoute: _routeGenerator.getRoute,
      ),
    );
  }
}
