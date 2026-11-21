import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';

/// Shown for an unknown route name (Barbora: `PageNotFound`).
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.routeName});

  final String? routeName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off, size: 48),
              const SizedBox(height: 12),
              Text(l10n.pageNotFound, style: Theme.of(context).textTheme.titleMedium),
              if (routeName != null) Text(routeName!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
