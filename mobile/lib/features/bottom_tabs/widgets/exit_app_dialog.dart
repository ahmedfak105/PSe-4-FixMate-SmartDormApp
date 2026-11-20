import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

/// "Exit the app?" – shown when Android back is pressed on the first screen
/// of the first tab (Barbora: `ExitAppAlertDialog`).
Future<bool> showExitAppDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final exit = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.exitTitle),
      content: Text(l10n.exitMessage),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.exit)),
      ],
    ),
  );
  return exit ?? false;
}
