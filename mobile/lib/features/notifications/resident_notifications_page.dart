import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/fixmate_i18n.dart';

class ResidentNotificationsPage extends StatefulWidget {
  const ResidentNotificationsPage({super.key, this.client});
  final SupabaseClient? client;

  @override
  State<ResidentNotificationsPage> createState() =>
      _ResidentNotificationsPageState();
}

class _ResidentNotificationsPageState
    extends State<ResidentNotificationsPage> {
  late final SupabaseClient _client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _unavailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? Supabase.instance.client;
    _load();
  }

  Future<void> _load() async {
    final accountId = _client.auth.currentUser?.id;
    if (accountId == null) {
      setState(() {
        _loading = false;
        _error = 'Please sign in to view notifications.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; _unavailable = false; });
    try {
      // No explicit owner filter: server-side RLS must enforce ownership.
      final rows = await _client.from('report_notifications')
          .select('id,report_id,new_status,created_at,read_at')
          .order('created_at', ascending: false).limit(100);
      if (!mounted) return;
      if (_client.auth.currentUser?.id != accountId) {
        throw StateError('Session changed.');
      }
      setState(() {
        _items = rows.map((r) => Map<String, dynamic>.from(r))
            .toList(growable: false);
        _loading = false;
      });
    } on PostgrestException {
      if (mounted) setState(() {
        _loading = false;
        _unavailable = true;
      });
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Could not load notifications. Please retry.';
      });
    }
  }

  Future<void> _markRead(int notificationId) async {
    if (_client.auth.currentUser == null) return;
    try {
      await _client.from('report_notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notificationId);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) setState(() =>
        _error = 'Could not update notification. Please retry.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const FixMateText('Notifications'),
      actions: [
        const FixMateLanguageButton(),
        IconButton(
          tooltip: fmTr(context, 'Refresh'),
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_loading) const LinearProgressIndicator(),
        if (_unavailable)
          const Card(child: Padding(
            padding: EdgeInsets.all(18),
            child: FixMateText('Notifications are not enabled on this server yet.'),
          )),
        if (_error != null) ...[
          FixMateText(_error!, style: TextStyle(
              color: Theme.of(context).colorScheme.error)),
          TextButton(onPressed: _load,
            child: const FixMateText('Retry')),
        ],
        if (!_loading && !_unavailable && _error == null && _items.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: FixMateText('No notifications yet.'),
          )),
        for (final row in _items)
          Card(child: ListTile(
            leading: Icon(row['read_at'] == null
                ? Icons.notifications_active_outlined
                : Icons.notifications_none_outlined,
                color: row['read_at'] == null
                    ? const Color(0xFF127F76)
                    : Theme.of(context).colorScheme.outline),
            title: FixMateText('Report #${row['report_id']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${fmTr(context, 'Status')}: '
                    '${fmTr(context, row['new_status'] as String)}'),
                const SizedBox(height: 4),
                Text((row['created_at'] ?? '').toString()),
              ],
            ),
            trailing: row['read_at'] == null ? IconButton(
              key: Key('mark_notification_${row['id']}'),
              tooltip: fmTr(context, 'Mark as read'),
              onPressed: () => _markRead((row['id'] as num).toInt()),
              icon: const Icon(Icons.done),
            ) : null,
          )),
      ]),
    ),
  );
}
