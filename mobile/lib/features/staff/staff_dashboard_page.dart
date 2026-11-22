import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/resident_profile.dart';
import '../settings/edit_profile_page.dart';
import '../settings/my_profile_avatar.dart';
import '../../data/models/staff_report.dart';
import '../../data/repositories/staff_reports_repository.dart';
import '../../data/repositories/staff_notes_repository.dart';
import 'staff_notes_dialog.dart';
import 'staff_report_filters.dart';

/// Staff-only Flutter Web dashboard. The user's role is checked by AuthGate;
/// PostgreSQL RLS and role-aware RPC functions remain the source of truth.
class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({
    super.key,
    required this.profile,
    required this.repository,
  });

  final ResidentProfile profile;
  final StaffReportsRepository repository;

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  late final StaffNotesRepository _notesRepository;
  List<StaffReport> _reports = const [];
  bool _loading = true;
  ResidentProfile? _editedProfile;
  int _avatarRevision = 0;

  Future<void> _editOwnProfile() async {
    final updated = await Navigator.of(context).push<ResidentProfile>(
      MaterialPageRoute(builder: (_) => EditProfilePage(
        profile: _editedProfile ?? widget.profile)),
    );
    if (updated != null && mounted) setState(() { _editedProfile = updated; _avatarRevision++; });
  }

  final _filterSearchController = TextEditingController();
  String _filterQuery = '';
  String _filterStatus = 'all';
  String _filterCategory = 'all';
  String _filterDate = 'all';

  void _clearReportFilters() {
    _filterSearchController.clear();
    setState(() {
      _filterQuery = '';
      _filterStatus = 'all';
      _filterCategory = 'all';
      _filterDate = 'all';
    });
  }

  @override
  void dispose() {
    _filterSearchController.dispose();
    super.dispose();
  }

  bool _showMyJobs = false;
  int? _busyReportId;
  bool _signingOut = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _notesRepository = StaffNotesRepository(
      client: Supabase.instance.client,
      staffId: widget.profile.id,
    );
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.listVisibleReports();
      if (!mounted) return;
      setState(() {
        _reports = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load reports: $error';
      });
    }
  }

  Future<void> _handleAction(StaffReport report, {required bool resolve}) async {
    if (_busyReportId != null) return;
    setState(() {
      _busyReportId = report.id;
      _error = null;
      _notice = null;
    });
    try {
      final success = resolve
          ? await widget.repository.resolveReport(report.id)
          : await widget.repository.claimReport(report.id);
      if (!mounted) return;
      if (success) {
        setState(() {
          _notice = resolve
              ? 'Report #${report.id} marked resolved.'
              : 'Report #${report.id} claimed successfully.';
          if (!resolve) _showMyJobs = true;
        });
      } else {
        setState(() => _notice =
            'Report #${report.id} was not changed. It may have been taken '
            'or updated by another staff member.');
      }
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      await _refresh();
      if (mounted) {
        setState(() => _error = 'Could not update report #${report.id}: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busyReportId = null);
        // Confirmation must remain visible even after the refreshed ListView
        // scrolls to an item below its initial viewport. A note placed only
        // at the top of a lazily built list can be absent from the viewport.
        final feedback = _error ?? _notice;
        if (feedback != null) {
          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.hideCurrentSnackBar();
          messenger?.showSnackBar(
            SnackBar(content: Text(feedback), duration: const Duration(seconds: 6)),
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not sign out: $error');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffId = widget.profile.id;
    final available = _reports.where((r) => r.canClaim(staffId)).toList();
    final mine = _reports.where((r) => r.isAssignedTo(staffId)).toList();
    final displayed = filterStaffVisibleReports(
      _showMyJobs ? mine : available,
      query: _filterQuery,
      status: _filterStatus,
      category: _filterCategory,
      dateRange: _filterDate,
    );
    final categoryIds = _reports.map((r) => r.categoryId).toSet().toList()
      ..sort();
    final name = (_editedProfile ?? widget.profile).fullName.trim().isNotEmpty
        ? (_editedProfile ?? widget.profile).fullName.trim()
        : 'Maintenance Staff';

    return Scaffold(
      appBar: AppBar(
        title: const Text('FixMate · Maintenance Workspace'),
        actions: [
          Tooltip(
            message: 'My profile',
            child: InkWell(
              onTap: _editOwnProfile,
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: MyProfileAvatar(
                  key: ValueKey('my-avatar-${widget.profile.id}-$_avatarRevision'),
                  userId: widget.profile.id,
                  name: (_editedProfile ?? widget.profile).fullName,
                  radius: 17,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh reports',
            icon: const Icon(Icons.refresh),
            onPressed: _loading || _busyReportId != null ? null : _refresh,
          ),
          TextButton.icon(
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: Text(_signingOut ? 'Signing out...' : 'Sign out'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Welcome, $name',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                const Text('Available reports can be claimed. Only reports '
                    'assigned to you can be marked resolved.'),
                const SizedBox(height: 20),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _SummaryCard(
                      label: 'Available to claim',
                      count: available.length,
                      icon: Icons.assignment_outlined),
                  _SummaryCard(
                      label: 'My jobs',
                      count: mine.length,
                      icon: Icons.engineering_outlined),
                  _SummaryCard(
                      label: 'In progress',
                      count: mine.where((r) => r.status == 'in_progress').length,
                      icon: Icons.handyman_outlined),
                ]),
                const SizedBox(height: 20),
                Wrap(spacing: 8, children: [
                  ChoiceChip(
                    label: Text('Available (${available.length})'),
                    selected: !_showMyJobs,
                    onSelected: (_) => setState(() => _showMyJobs = false),
                  ),
                  ChoiceChip(
                    label: Text('My jobs (${mine.length})'),
                    selected: _showMyJobs,
                    onSelected: (_) => setState(() => _showMyJobs = true),
                  ),
                ]),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('staff_filter_search'),
                  controller: _filterSearchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search reports',
                    hintText: 'Title, location, description or report ID',
                  ),
                  onChanged: (v) => setState(() => _filterQuery = v),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  SizedBox(width: 190, child: DropdownButtonFormField<String>(
                    key: const Key('staff_filter_status'),
                    initialValue: _filterStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All statuses')),
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                      DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    ],
                    onChanged: (v) =>
                        setState(() => _filterStatus = v ?? 'all'),
                  )),
                  SizedBox(width: 190, child: DropdownButtonFormField<String>(
                    key: const Key('staff_filter_category'),
                    initialValue: _filterCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(value: 'all',
                        child: Text('All categories')),
                      for (final id in categoryIds)
                        DropdownMenuItem(value: '$id',
                          child: Text('Category #$id')),
                    ],
                    onChanged: (v) =>
                        setState(() => _filterCategory = v ?? 'all'),
                  )),
                  SizedBox(width: 190, child: DropdownButtonFormField<String>(
                    key: const Key('staff_filter_date'),
                    initialValue: _filterDate,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Submitted'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Any date')),
                      DropdownMenuItem(value: 'last7', child: Text('Last 7 days')),
                      DropdownMenuItem(value: 'last30', child: Text('Last 30 days')),
                    ],
                    onChanged: (v) =>
                        setState(() => _filterDate = v ?? 'all'),
                  )),
                  TextButton.icon(
                    onPressed: _clearReportFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear filters'),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('${displayed.length} matching reports',
                    style: Theme.of(context).textTheme.bodySmall),
                if (_loading) ...[
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ],
                if (!_loading && _error == null && displayed.isEmpty) ...[
                  const SizedBox(height: 40),
                  Center(
                      child: Text(_showMyJobs
                          ? 'No jobs assigned to you yet.'
                          : 'No available reports right now.')),
                ],
                for (final report in displayed) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              Text('#${report.id}  ${report.title}',
                                  style: Theme.of(context).textTheme.titleMedium),
                              Chip(label: Text(report.status.replaceAll('_', ' '))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Location: ${report.location.isEmpty ? 'Not set' : report.location}'),
                          Text('Submitted: ${report.createdAt.toLocal().toString().substring(0, 16)}'),
                          Text('Last status update: ${report.lastStatusUpdatedAt == null
                              ? 'Not recorded or not available'
                              : report.lastStatusUpdatedAt!.toLocal().toString().substring(0, 16)}'),
                          Text('Category ID: ${report.categoryId}'),
                          if (report.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(report.description),
                          ],
                          const SizedBox(height: 12),
                          if (report.canClaim(staffId))
                            FilledButton.icon(
                              onPressed: _busyReportId != null || _loading
                                  ? null
                                  : () => _handleAction(report, resolve: false),
                              icon: const Icon(Icons.assignment_turned_in_outlined),
                              label: Text(_busyReportId == report.id
                                  ? 'Claiming...' : 'Claim report'),
                            )
                          else if (report.canResolve(staffId))
                            FilledButton.icon(
                              onPressed: _busyReportId != null || _loading
                                  ? null
                                  : () => _handleAction(report, resolve: true),
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(_busyReportId == report.id
                                  ? 'Resolving...' : 'Mark resolved'),
                            )
                          else
                            const Text('No status action available for this report.'),
                          if (report.isAssignedTo(staffId)) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.note_alt_outlined),
                              label: const Text('Internal notes'),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => StaffNotesDialog(
                                  reportId: report.id,
                                  repository: _notesRepository,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.count, required this.icon});
  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$count', style: Theme.of(context).textTheme.headlineSmall),
                    Text(label, softWrap: true),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}
