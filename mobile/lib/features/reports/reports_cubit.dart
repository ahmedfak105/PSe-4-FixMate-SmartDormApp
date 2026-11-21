import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/maintenance_report.dart';
import '../../data/repositories/report_repository.dart';

class ReportsState {
  const ReportsState({this.items = const [], this.loading = false, this.error});
  final List<MaintenanceReport> items;
  final bool loading;
  final String? error;
}

class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit(this.repository) : super(const ReportsState());
  final ReportRepository repository;
  /// ID returned by the most recent successful insert (used for an optional photo).
  String? lastCreatedReportId;

  Future<void> load() async {
    if (isClosed) return;
    emit(ReportsState(items: state.items, loading: true));
    try {
      final reports = await repository.getMyReports();
      if (isClosed) return; // Auth user might sign out mid-fetch.
      emit(ReportsState(items: reports));
    } catch (error) {
      if (isClosed) return;
      emit(ReportsState(items: state.items, error: '$error'));
    }
  }

  Future<bool> create({
    required String title,
    required String category,
    required String location,
    required String description,
  }) async {
    if (isClosed) return false;
    lastCreatedReportId = null;
    try {
      final inserted = await repository.createReport(
        title: title.trim(),
        category: category,
        location: location.trim(),
        description: description.trim(),
      );
      if (isClosed) return false;
      lastCreatedReportId = inserted.id;
      // Creation success is separate from refreshing the list.
      // If refresh fails, keep a visible load error but don't encourage
      // another submission that could create a duplicate report.
      await load();
      return true;
    } catch (error) {
      if (!isClosed) emit(ReportsState(items: state.items, error: '$error'));
      return false;
    }
  }
}
