import '../../fixmate_theme.dart';
import 'report_filters.dart';
import 'admin_categories_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/resident_profile.dart';
import '../settings/edit_profile_page.dart';
import '../settings/my_profile_avatar.dart';
import '../support/fixmate_support_page.dart';
import '../../l10n/fixmate_i18n.dart';

/// System-admin Flutter Web workspace (Task #38 / F06.1).
///
/// Every query runs with the current user's publishable-key session. The
/// backend's RLS and assign_maintenance_report RPC enforce privileges.
class AdminOperationsPage extends StatefulWidget {
  const AdminOperationsPage({super.key, required this.profile, this.client});
  final ResidentProfile profile;
  final SupabaseClient? client;

  @override
  State<AdminOperationsPage> createState() => _AdminOperationsPageState();
}

class _AdminOperationsPageState extends State<AdminOperationsPage> {
  late final SupabaseClient _client;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _profiles = [];
  Map<int, String> _categories = {};
  bool _loading = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  ResidentProfile? _editedProfile;
  int _avatarRevision = 0;

  Future<void> _editOwnProfile() async {
    final updated = await Navigator.of(context).push<ResidentProfile>(
      MaterialPageRoute(builder: (_) => EditProfilePage(
        profile: _editedProfile ?? widget.profile)),
    );
    if (updated != null && mounted) {
      setState(() { _editedProfile = updated; _avatarRevision++; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: FixMateText('Profile updated successfully.')),
      );
    }
  }

  int _tab = 0;
  String _query = '';
  String _statusFilter = 'all';
  String _categoryFilter = 'all';
  String _dateFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _statusFilter = 'all';
      _categoryFilter = 'all';
      _dateFilter = 'all';
    });
  }

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? Supabase.instance.client;
    _load();
  }

  bool get _authorized => _client.auth.currentUser?.id == widget.profile.id &&
      widget.profile.role.trim().toLowerCase() == 'system_admin';

  Future<void> _load() async {
    if (!_authorized) {
      setState(() => _error = 'Administrator session or role changed. Please sign in again.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final reports = await _client
          .from('maintenance_reports')
          .select('id,title,description,location,status,assigned_to,resident_id,category_id,created_at')
          .order('created_at', ascending: false).limit(500);
      final profiles = await _client.from('profiles')
          .select('id,full_name,role,building,room_number,created_at')
          .order('created_at', ascending: false).limit(500);
      final categories = await _client.from('maintenance_categories')
          .select('id,name').order('name').limit(200);
      if (!mounted) return;
      if (!_authorized) throw StateError('Administrator session changed.');
      setState(() {
        _reports = reports.map((row) => Map<String, dynamic>.from(row)).toList();
        _profiles = profiles.map((row) => Map<String, dynamic>.from(row)).toList();
        _categories = {for (final cat in categories)
          (cat['id'] as num).toInt(): cat['name'] as String};
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() {
        _error = 'Could not load admin dashboard: $error';
        _loading = false;
      });
    }
  }

  String _person(String? id) {
    if (id == null) return 'Unassigned';
    for (final profile in _profiles) {
      if (profile['id'] == id) {
        return (profile['full_name'] as String?)?.trim().isNotEmpty == true
            ? profile['full_name'] as String : profile['role'] as String;
      }
    }
    return id.length <= 12 ? id : '${id.substring(0, 8)}…';
  }

  Future<void> _assign(int reportId) async {
    if (_busy || !_authorized) return;
    final candidates = _profiles
        .where((p) => p['role'] == 'maintenance_staff').toList();
    if (candidates.isEmpty) {
      setState(() => _error = 'No maintenance_staff accounts are visible. '
          'Create a trusted staff profile before assigning reports.');
      return;
    }
    String selected = candidates.first['id'] as String;
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: FixMateText('Assign report #$reportId'),
          content: SizedBox(
            width: 420,
            child: DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              decoration: InputDecoration(labelText: fmTr(context, 'Maintenance employee')),
              items: [
                for (final person in candidates)
                  DropdownMenuItem(
                    value: person['id'] as String,
                    child: FixMateText((person['full_name'] as String?)?.trim().isNotEmpty == true
                        ? person['full_name'] as String : person['id'] as String,
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value != null) update(() => selected = value);
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const FixMateText('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, selected),
                child: const FixMateText('Assign employee')),
          ],
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    setState(() { _busy = true; _error = null; _notice = null; });
    String? actionError;
    try {
      if (!_authorized) throw StateError('Administrator session changed.');
      final response = await _client.rpc('assign_maintenance_report', params: {
        'p_report_id': reportId,
        'p_staff_id': chosen,
      });
      if (response is! bool) throw StateError('Unexpected assignment response.');
      if (!mounted) return;
      setState(() => _notice = response
          ? 'Report #$reportId assigned. Staff must claim it before work begins.'
          : 'Report #$reportId was changed by someone else. List refreshed.');
    } catch (error) {
      actionError = 'Could not assign report #$reportId: $error';
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
      if (mounted && actionError != null) {
        setState(() => _error = actionError);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      if (mounted) setState(() => _error = 'Sign out failed: $error');
    }
  }

  Widget _summary() {
    final byStatus = {
      for (final status in ['new', 'in_progress', 'resolved'])
        status: _reports.where((r) => r['status'] == status).length,
    };
    return LayoutBuilder(builder: (context, bounds) {
      final count = bounds.maxWidth >= 920 ? 4 : bounds.maxWidth >= 300 ? 2 : 1;
      final cardWidth = (bounds.maxWidth - (count - 1) * 12) / count;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: cardWidth, child: _Metric(label: 'All reports',
            count: _reports.length, icon: Icons.library_books_outlined)),
        SizedBox(width: cardWidth, child: _Metric(label: 'New',
            count: byStatus['new']!, icon: Icons.fiber_new_outlined)),
        SizedBox(width: cardWidth, child: _Metric(label: 'In progress',
            count: byStatus['in_progress']!, icon: Icons.handyman_outlined)),
        SizedBox(width: cardWidth, child: _Metric(label: 'Resolved',
            count: byStatus['resolved']!, icon: Icons.check_circle_outline)),
      ]);
    });
  }

  Widget _listReports({required bool assignmentsOnly}) {
    final rows = filterVisibleReports(
      _reports,
      categoryNames: _categories,
      assignmentsOnly: assignmentsOnly,
      text: assignmentsOnly ? '' : _query,
      status: assignmentsOnly ? 'all' : _statusFilter,
      category: assignmentsOnly ? 'all' : _categoryFilter,
      dateRange: assignmentsOnly ? 'all' : _dateFilter,
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!assignmentsOnly) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: const Key('admin_filter_query'),
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: fmTr(context, 'Search reports'),
              hintText: fmTr(context, 'Title, description, location, category or ID'),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          SizedBox(width: 190, child: DropdownButtonFormField<String>(
            key: const Key('admin_filter_status'),
            initialValue: _statusFilter,
            isExpanded: true,
            decoration: InputDecoration(labelText: fmTr(context, 'Status')),
            items: const [
              DropdownMenuItem(value: 'all', child: FixMateText('All statuses')),
              DropdownMenuItem(value: 'new', child: FixMateText('New')),
              DropdownMenuItem(value: 'in_progress', child: FixMateText('In progress')),
              DropdownMenuItem(value: 'resolved', child: FixMateText('Resolved')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
          )),
          SizedBox(width: 190, child: DropdownButtonFormField<String>(
            key: const Key('admin_filter_category'),
            initialValue: _categoryFilter,
            isExpanded: true,
            decoration: InputDecoration(labelText: fmTr(context, 'Category')),
            items: [
              const DropdownMenuItem(value: 'all', child: FixMateText('All categories')),
              for (final item in _categories.entries)
                DropdownMenuItem(
                  value: item.key.toString(),
                  child: FixMateText(item.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _categoryFilter = v ?? 'all'),
          )),
          SizedBox(width: 190, child: DropdownButtonFormField<String>(
            key: const Key('admin_filter_date'),
            initialValue: _dateFilter,
            isExpanded: true,
            decoration: InputDecoration(labelText: fmTr(context, 'Submitted')),
            items: const [
              DropdownMenuItem(value: 'all', child: FixMateText('Any date')),
              DropdownMenuItem(value: 'last7', child: FixMateText('Last 7 days')),
              DropdownMenuItem(value: 'last30', child: FixMateText('Last 30 days')),
            ],
            onChanged: (v) => setState(() => _dateFilter = v ?? 'all'),
          )),
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const FixMateText('Clear filters'),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: FixMateText('${rows.length} matching reports',
            style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
      if (rows.isEmpty)
        const Padding(padding: EdgeInsets.all(30),
            child: FixMateText('No reports found for this view.')),
      for (final row in rows)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FixMateText('#${row['id']}  ${row['title']}',
                      style: Theme.of(context).textTheme.titleMedium),
                  Chip(label: FixMateText((row['status'] as String).replaceAll('_', ' '))),
                ]),
              const SizedBox(height: 7),
              FixMateText('${_categories[(row['category_id'] as num).toInt()] ?? 'Unknown category'}'
                  ' · ${row['location'] ?? 'No location'}'),
              FixMateText('Resident: ${_person(row['resident_id'] as String?)}'),
              FixMateText('Assigned to: ${_person(row['assigned_to'] as String?)}'),
              if ((row['description'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                FixMateText(row['description'] as String),
              ],
              if (row['status'] == 'new' && row['assigned_to'] == null) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _assign((row['id'] as num).toInt()),
                  icon: const Icon(Icons.assignment_ind_outlined),
                  label: const FixMateText('Assign to maintenance staff'),
                ),
              ],
            ]),
          ),
        ),
    ]);
  }

  Widget _people() => Column(children: [
    for (final p in _profiles)
      Card(child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: FixMateText((p['full_name'] as String?)?.isNotEmpty == true
            ? p['full_name'] as String : 'Unnamed user'),
        subtitle: FixMateText('${p['role']} · ${p['building'] ?? 'No building'}'
            ' · ${p['room_number'] ?? 'No room'}'),
        trailing: const Icon(Icons.lock_outline),
      )),
    const Padding(padding: EdgeInsets.all(12),
      child: FixMateText('Roles are read-only here. Privileged role changes must '
          'use trusted operator provisioning, never browser SQL keys.')),
  ]);

  @override
  Widget build(BuildContext context) {
    const labels = ['Overview', 'All reports', 'Assignments', 'People', 'Categories'];
    final content = switch (_tab) {
      0 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _summary(),
        const SizedBox(height: 24),
        FixMateText('Recent activity',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        _listReports(assignmentsOnly: false),
      ]),
      1 => _listReports(assignmentsOnly: false),
      2 => _listReports(assignmentsOnly: true),
      3 => _people(),
      _ => AdminCategoriesPage(client: _client, adminId: widget.profile.id),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.home_repair_service_rounded, color: FixMateTheme.teal),
          SizedBox(width: 9),
          FixMateText('FixMate'),
        ]),
        actions: [
          const FixMateUtilityMenu(),
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
          IconButton(tooltip: fmTr(context, 'Refresh'), icon: const Icon(Icons.refresh),
              onPressed: _loading || _busy ? null : _load),
          IconButton(tooltip: fmTr(context, 'Sign out'), icon: const Icon(Icons.logout),
              onPressed: _logout),
        ],
      ),
      body: LayoutBuilder(builder: (context, size) => Row(children: [
        if (size.maxWidth > 760)
          NavigationRail(
            extended: size.maxWidth > 1200,
            selectedIndex: _tab,
            onDestinationSelected: (value) => setState(() => _tab = value),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined),
                  label: FixMateText('Overview')),
              NavigationRailDestination(icon: Icon(Icons.description_outlined),
                  label: FixMateText('All reports')),
              NavigationRailDestination(icon: Icon(Icons.assignment_ind_outlined),
                  label: FixMateText('Assignments')),
              NavigationRailDestination(icon: Icon(Icons.people_alt_outlined),
                  label: FixMateText('People')),
              NavigationRailDestination(icon: Icon(Icons.category_outlined),
                  label: FixMateText('Categories')),
            ],
          ),
        Expanded(child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: size.maxWidth > 760 ? 30 : 16, vertical: 24),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (size.maxWidth <= 760)
                SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (var i = 0; i < labels.length; i++)
                      Padding(padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(label: FixMateText(labels[i]),
                            selected: _tab == i,
                            onSelected: (_) => setState(() => _tab = i))),
                  ])),
              const SizedBox(height: 12),
              _WelcomePanel(name: (_editedProfile ?? widget.profile).fullName, reportCount: _reports.length),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                FixMateText(_error!, style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
              if (_notice != null)
                FixMateText(_notice!, style: TextStyle(
                    color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 16),
              content,
            ]),
          )),
        )),
      ])),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.name, required this.reportCount});
  final String name;
  final int reportCount;

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'Administrator' : name.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF07555C), Color(0xFF0B8586)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        spacing: 22, runSpacing: 15,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FixMateText('OPERATIONS OVERVIEW',
              style: TextStyle(color: Color(0xFFB9EAE2),
                letterSpacing: 1.5, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 9),
            FixMateText('Welcome back, $displayName',
              style: const TextStyle(color: Colors.white,
                fontSize: 23, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const FixMateText('Manage requests, teams and maintenance progress.',
              style: TextStyle(color: Color(0xFFE3F6F3), fontSize: 13)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0x23FFFFFF),
              borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.analytics_outlined, color: Colors.white),
              const SizedBox(width: 10),
              FixMateText('$reportCount total requests',
                style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.count, required this.icon});
  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final accent = label == 'Resolved' ? const Color(0xFF16875A)
        : label == 'New' ? const Color(0xFFB87512)
        : label == 'In progress' ? const Color(0xFF3979B4)
        : FixMateTheme.teal;
    return Card(child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 22, color: accent),
            ),
            const SizedBox(height: 15),
            FixMateText('$count', style: const TextStyle(
              fontSize: 30, color: FixMateTheme.ink,
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            FixMateText(label, style: const TextStyle(
              fontSize: 13, color: Color(0xFF617C86),
              fontWeight: FontWeight.w600)),
          ],
        ),
      ));
  }
}
