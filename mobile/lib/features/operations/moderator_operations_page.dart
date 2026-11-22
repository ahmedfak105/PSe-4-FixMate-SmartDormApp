import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/resident_profile.dart';
import '../settings/edit_profile_page.dart';
import '../settings/my_profile_avatar.dart';

/// Keep historical decisions visible after Staff changes a reviewed report
/// to in_progress or resolved. Only unassigned NEW reports can be reviewed.
List<Map<String, dynamic>> visibleModeratorReports({
  required List<Map<String, dynamic>> reports,
  required Map<int, Map<String, dynamic>> decisions,
  required bool reviewedOnly,
}) {
  return reports.where((report) {
    final id = (report['id'] as num).toInt();
    final reviewed = decisions.containsKey(id);
    if (reviewedOnly) return reviewed;
    return !reviewed &&
        report['status'] == 'new' &&
        report['assigned_to'] == null;
  }).toList(growable: false);
}

/// Task #39: Flutter Web moderator review, restricted by DB RLS and RPC.
///
/// IMPORTANT: Review table/RPC are proposed on local/staging Supabase only.
/// On the original six-table live database, the screen explains what is
/// missing instead of pretending a review was saved.
class ModeratorOperationsPage extends StatefulWidget {
  const ModeratorOperationsPage({super.key, required this.profile, this.client});
  final ResidentProfile profile;
  final SupabaseClient? client;

  @override
  State<ModeratorOperationsPage> createState() => _ModeratorOperationsPageState();
}

class _ModeratorOperationsPageState extends State<ModeratorOperationsPage> {
  late final SupabaseClient _client;
  List<Map<String, dynamic>> _reports = [];
  Map<int, String> _categories = {};
  Map<int, Map<String, dynamic>> _decisions = {};
  Map<int, List<Map<String, dynamic>>> _photos = {};
  bool _loading = false;
  bool _busy = false;
  ResidentProfile? _editedProfile;
  int _avatarRevision = 0;

  Future<void> _editOwnProfile() async {
    final updated = await Navigator.of(context).push<ResidentProfile>(
      MaterialPageRoute(builder: (_) => EditProfilePage(
        profile: _editedProfile ?? widget.profile)),
    );
    if (updated != null && mounted) {
      setState(() { _editedProfile = updated; _avatarRevision++; });
    }
  }

  bool _reviewedOnly = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? Supabase.instance.client;
    _refresh();
  }

  bool get _authorized => _client.auth.currentUser?.id == widget.profile.id &&
      const ['moderator', 'system_admin']
          .contains(widget.profile.role.trim().toLowerCase());

  Future<void> _refresh() async {
    if (!_authorized) {
      setState(() => _error = 'Moderator session is not authorized.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      // Fetch reports across statuses so the Reviewed tab retains audit
      // decisions after a valid report is claimed and later resolved.
      // _canReview still restricts NEW decisions to unassigned 'new' reports.
      final reports = await _client.from('maintenance_reports')
          .select('id,title,description,location,status,assigned_to,category_id,created_at')
          .order('created_at', ascending: false).limit(500);
      final ids = reports.map((r) => (r['id'] as num).toInt()).toList();
      final categories = await _client.from('maintenance_categories')
          .select('id,name').limit(200);
      // If this is missing, the proposed Moderator migration has not been
      // deployed. Deliberately show an actionable error to the operator.
      final decisions = await _client.from('report_reviews')
          .select('report_id,outcome,reason,reviewer_id,reviewed_at')
          .inFilter('report_id', ids.isEmpty ? [-1] : ids);
      final photos = await _client.from('report_attachments')
          .select('id,report_id,storage_path')
          .inFilter('report_id', ids.isEmpty ? [-1] : ids);
      if (!mounted) return;
      if (!_authorized) throw StateError('Moderator session changed.');
      final photoMap = <int, List<Map<String, dynamic>>>{};
      for (final item in photos) {
        final reportId = (item['report_id'] as num).toInt();
        (photoMap[reportId] ??= []).add(Map<String, dynamic>.from(item));
      }
      setState(() {
        _reports = reports.map((r) => Map<String, dynamic>.from(r)).toList();
        _categories = {for (final c in categories)
          (c['id'] as num).toInt(): c['name'] as String};
        _decisions = {for (final d in decisions)
          (d['report_id'] as num).toInt(): Map<String, dynamic>.from(d)};
        _photos = photoMap;
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Moderator data unavailable: $error. '
          'Verify that the proposed review migration, table grants and RLS '
          'are installed on an approved staging project.';
      });
    }
  }

  bool _canReview(Map<String, dynamic> report) =>
      report['status'] == 'new' &&
      report['assigned_to'] == null &&
      !_decisions.containsKey((report['id'] as num).toInt());

  Future<void> _showPhoto(String path) async {
    if (!_authorized) return;
    final download = _client.storage.from('report-photos').download(path);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Private report photo'),
        content: SizedBox(
          width: 540,
          height: 350,
          child: FutureBuilder<Uint8List>(
            future: download,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Photo unavailable: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Image.memory(snapshot.data!, fit: BoxFit.contain);
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _review(Map<String, dynamic> report) async {
    if (!_authorized || _busy || !_canReview(report)) return;
    String outcome = 'valid';
    final reason = TextEditingController();
    try {
      final submitted = await showDialog<(String, String)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: Text('Review report #${report['id']}'),
            content: SizedBox(
              width: 460,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: outcome,
                  decoration: const InputDecoration(labelText: 'Review outcome'),
                  items: const [
                    DropdownMenuItem(value: 'valid', child: Text('Valid')),
                    DropdownMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    DropdownMenuItem(value: 'inappropriate', child: Text('Inappropriate')),
                  ],
                  onChanged: (value) {
                    if (value != null) update(() => outcome = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: outcome == 'valid'
                        ? 'Review note (optional)' : 'Reason (required)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final trimmed = reason.text.trim();
                  if (outcome != 'valid' && trimmed.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('A rejection reason is required.')),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, (outcome, trimmed));
                },
                child: const Text('Save decision'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || submitted == null) return;
      setState(() { _busy = true; _notice = null; _error = null; });
      String? actionError;
      try {
        if (!_authorized) throw StateError('Moderator session changed.');
        final response = await _client.rpc('review_maintenance_report', params: {
          'p_report_id': report['id'],
          'p_outcome': submitted.$1,
          'p_reason': submitted.$2,
        });
        if (response is! bool) throw StateError('Unexpected review response.');
        if (!mounted) return;
        setState(() => _notice = response
            ? 'Review saved for report #${report['id']}: ${submitted.$1}.'
            : 'Report #${report['id']} was already reviewed or assigned.');
      } catch (error) {
        actionError = 'Could not save review for #${report['id']}: $error';
      } finally {
        if (mounted) setState(() => _busy = false);
        await _refresh();
        if (mounted && actionError != null) {
          setState(() => _error = actionError);
        }
      }
    } finally {
      reason.dispose();
    }
  }

  Future<void> _logout() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not sign out: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleModeratorReports(
      reports: _reports,
      decisions: _decisions,
      reviewedOnly: _reviewedOnly,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('FixMate · Review Center'),
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
          IconButton(tooltip: 'Refresh reviews', onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Sign out', onPressed: _logout,
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1020),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Report review',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Signed in as ${(_editedProfile ?? widget.profile).fullName} '
                    '(${widget.profile.role}). Review only new, unassigned reports.'),
                const SizedBox(height: 14),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Awaiting review'),
                        icon: Icon(Icons.pending_actions_outlined)),
                    ButtonSegment(value: true, label: Text('Reviewed'),
                        icon: Icon(Icons.fact_check_outlined)),
                  ],
                  selected: {_reviewedOnly},
                  onSelectionChanged: (value) =>
                      setState(() => _reviewedOnly = value.first),
                ),
                if (_loading) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 10),
                  Text(_notice!, style: TextStyle(
                      color: Theme.of(context).colorScheme.primary)),
                ],
                if (!_loading && _error == null && visible.isEmpty)
                  const Padding(padding: EdgeInsets.all(30),
                      child: Text('No reports in this review category.')),
                for (final report in visible) ...[
                  const SizedBox(height: 9),
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${report['id']}  ${report['title']}',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text('${_categories[(report['category_id'] as num).toInt()] ?? 'Other'}'
                            ' · ${report['location'] ?? 'No location'}'),
                        const SizedBox(height: 8),
                        Text(report['description'] as String? ?? ''),
                        if (_decisions.containsKey((report['id'] as num).toInt())) ...[
                          const SizedBox(height: 8),
                          Text('Decision: ${_decisions[(report['id'] as num).toInt()]?['outcome']}'
                              ' · ${_decisions[(report['id'] as num).toInt()]?['reason']}'),
                        ],
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (_canReview(report))
                            FilledButton.icon(
                              onPressed: _busy ? null : () => _review(report),
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('Review report'),
                            ),
                          for (final photo in _photos[(report['id'] as num).toInt()] ?? [])
                            OutlinedButton.icon(
                              onPressed: () => _showPhoto(photo['storage_path'] as String),
                              icon: const Icon(Icons.photo_outlined),
                              label: const Text('View private photo'),
                            ),
                        ]),
                      ]),
                  )),
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
