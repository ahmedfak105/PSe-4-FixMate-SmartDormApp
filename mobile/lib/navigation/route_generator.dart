import 'package:flutter/material.dart';
import '../features/reports/report_details_page.dart';
import '../widgets/not_found_page.dart';

abstract final class AppRoutes {
  static const reportDetails = '/reports/details'; // arguments: String report id
}

class RouteGenerator {
  const RouteGenerator();
  Route<dynamic> getRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.reportDetails && settings.arguments is String) {
      final id = settings.arguments! as String;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => ReportDetailsPage(reportId: id),
      );
    }
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => NotFoundPage(routeName: settings.name),
    );
  }
}
