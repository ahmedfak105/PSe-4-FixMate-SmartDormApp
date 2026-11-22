import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fixmate_theme.dart';

/// Client-side input validation; PostgreSQL repeats the same constraints.
String? validateCategoryName(String? input) {
  final name = input?.trim() ?? '';
  if (name.length < 2 || name.length > 80) {
    return 'Name must be between 2 and 80 characters.';
  }
  return null;
}

class _Category {
  const _Category({required this.id, required this.name, required this.active});
  final int id;
  final String name;
  final bool active;

  factory _Category.fromJson(Map<String, dynamic> row) => _Category(
        id: (row['id'] as num).toInt(),
        name: row['name'] as String,
        active: row['is_active'] == true,
      );
}

class _CategoryDraft {
  const _CategoryDraft({required this.name, required this.active});
  final String name;
  final bool active;
}

/// System Admin category workspace. The backend RPC verifies role from
/// public.profiles on *every write*. Flutter widgets are not an auth boundary.
class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({
    super.key,
    required this.client,
    required this.adminId,
  });

  final SupabaseClient client;
  final String adminId;

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  List<_Category> _categories = [];
  bool _loading = true;
  bool _busy = false;
  bool _managementEnabled = false;
  String? _error;
  String? _notice;

  bool get _sameSession =>
      widget.client.auth.currentUser?.id == widget.adminId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (!_sameSession) {
      setState(() {
        _loading = false;
        _managementEnabled = false;
        _error = 'Administrator session changed. Sign in again.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      // This RPC is missing on older hosted databases. If absent, fail
      // closed and show read-only categories instead of broken edit buttons.
      var enabled = false;
      try {
        enabled = await widget.client
            .rpc('can_manage_maintenance_categories') == true;
      } on PostgrestException {
        enabled = false;
      }

      final rows = await widget.client
          .from('maintenance_categories')
          .select('id,name,is_active')
          .order('name');

      if (!mounted) return;
      if (!_sameSession) throw StateError('Administrator session changed.');
      setState(() {
        _managementEnabled = enabled;
        _categories = rows
            .map((row) => _Category.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _managementEnabled = false;
        _error = 'Could not load categories. Check your connection and retry.';
      });
    }
  }

  Future<_CategoryDraft?> _editDialog({_Category? existing}) =>
      showDialog<_CategoryDraft>(
        context: context,
        builder: (_) => _CategoryEditorDialog(existing: existing),
      );

  Future<void> _manage({_Category? existing}) async {
    if (_busy || !_managementEnabled || !_sameSession) return;
    final draft = await _editDialog(existing: existing);
    if (draft == null || !mounted) return;
    await _save(existing: existing, name: draft.name, active: draft.active);
  }

  Future<void> _save({
    _Category? existing,
    required String name,
    required bool active,
  }) async {
    if (_busy || !_managementEnabled || !_sameSession) return;
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await widget.client.rpc('manage_maintenance_category', params: {
        'p_category_id': existing?.id,
        'p_name': name,
        'p_is_active': active,
      });
      if (!mounted) return;
      if (!_sameSession) throw StateError('Administrator session changed.');
      // Admin receives the new category version after a name change.
      await _reload();
      if (mounted) setState(() {
        _notice = existing == null
            ? 'Category created.'
            : 'Category updated. Existing report history was preserved.';
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == '23505'
            ? 'A category with that name already exists.'
            : 'Category could not be saved. Check permissions or retry.';
      });
    } catch (_) {
      if (mounted) setState(() => _error =
          'Category could not be saved. Check permissions or retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(_Category category) async {
    if (_busy || !_managementEnabled || !_sameSession) return;
    if (category.active) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deactivate category?'),
          content: Text(
            '“${category.name}” will no longer be available for new reports. '
            'Existing reports will retain their category.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    await _save(existing: category, name: category.name,
      active: !category.active);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        spacing: 14,
        runSpacing: 12,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Maintenance categories',
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            const Text('Choose which issues residents can report.'),
          ]),
          FilledButton.icon(
            key: const Key('add_category'),
            onPressed: _managementEnabled && !_busy && !_loading
                ? () => _manage() : null,
            icon: const Icon(Icons.add),
            label: const Text('Add category'),
          ),
        ],
      ),
      if (_loading) const Padding(
        padding: EdgeInsets.symmetric(vertical: 15),
        child: LinearProgressIndicator(),
      ),
      if (!_loading && !_managementEnabled) ...[
        const SizedBox(height: 12),
        const Card(child: Padding(
          padding: EdgeInsets.all(15),
          child: Row(children: [
            Icon(Icons.lock_outline, color: FixMateTheme.teal),
            SizedBox(width: 12),
            Expanded(child: Text(
              'Category editing is not enabled on this server yet. '
              'You can view active categories, but changes are disabled.',
            )),
          ]),
        )),
      ],
      if (_error != null) Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(_error!, style: TextStyle(
          color: Theme.of(context).colorScheme.error)),
      ),
      if (_notice != null) Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(_notice!, style: const TextStyle(
          color: FixMateTheme.teal)),
      ),
      if (!_loading && _categories.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 25),
          child: Text('No categories found.'),
        ),
      const SizedBox(height: 14),
      for (final category in _categories)
        Card(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: FixMateTheme.mint,
              child: const Icon(Icons.category_outlined,
                color: FixMateTheme.teal),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name, style:
                  Theme.of(context).textTheme.titleMedium),
                Text(category.active ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    color: category.active
                        ? const Color(0xFF127F76)
                        : const Color(0xFF6B7F8D),
                  )),
              ],
            )),
            IconButton(
              key: Key('edit_category_${category.id}'),
              tooltip: 'Edit category',
              onPressed: _managementEnabled && !_busy
                  ? () => _manage(existing: category) : null,
              icon: const Icon(Icons.edit_outlined),
            ),
            Switch(
              key: Key('toggle_category_${category.id}'),
              value: category.active,
              onChanged: _managementEnabled && !_busy
                  ? (_) => _toggle(category) : null,
            ),
          ]),
        )),
    ],
  );
}

/// Dialog owns its TextEditingController throughout route animations.
class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({this.existing});
  final _Category? existing;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _active = widget.existing?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add category' : 'Edit category'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: const Key('category_name'),
              controller: _name,
              maxLength: 80,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Category name'),
              validator: validateCategoryName,
            ),
            SwitchListTile(
              key: const Key('category_active'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for new reports'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            if (widget.existing != null)
              const Text(
                'Renaming creates a new category. Existing reports '
                'retain their original category.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7F8D)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('save_category'),
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          Navigator.pop(context, _CategoryDraft(
            name: _name.text.trim(),
            active: _active,
          ));
        },
        child: const Text('Save'),
      ),
    ],
  );
}
