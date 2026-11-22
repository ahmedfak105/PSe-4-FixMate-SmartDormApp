import '../../data/models/maintenance_report.dart';
import '../../l10n/gen/app_localizations.dart';

String statusLabel(MaintenanceStatus status, AppLocalizations l10n) => switch (status) {
  MaintenanceStatus.newReport => l10n.statusNew,
  MaintenanceStatus.inProgress => l10n.statusInProgress,
  MaintenanceStatus.resolved => l10n.statusResolved,
  MaintenanceStatus.unknown => 'Unknown',
};
