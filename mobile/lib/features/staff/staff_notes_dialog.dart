import 'package:flutter/material.dart';

import '../../data/models/staff_note.dart';
import '../../data/repositories/staff_notes_repository.dart';

/// Notes are INTERNAL to staff, not resident-facing updates.
class StaffNotesDialog extends StatefulWidget {
  const StaffNotesDialog({
    super.key,
    required this.reportId,
    required this.repository,
  });

  final int reportId;
  final StaffNotesRepository repository;

  @override
  State<StaffNotesDialog> createState() => _StaffNotesDialogState();
}

class _StaffNotesDialogState extends State<StaffNotesDialog> {
  final TextEditingController _content = TextEditingController();
  List<StaffNote> _notes = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notes = await widget.repository.listForReport(widget.reportId);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load notes: $error';
        _loading = false;
      });
    }
  }

  Future<void> _saveNote() async {
    if (_saving) return;
    final content = _content.text;
    try {
      validateInternalNote(content);
    } on FormatException catch (error) {
      setState(() => _fieldError = error.message);
      return;
    }
    setState(() {
      _saving = true;
      _fieldError = null;
      _error = null;
    });
    try {
      await widget.repository.addNote(reportId: widget.reportId, content: content);
      if (!mounted) return;
      _content.clear();
      await _loadNotes();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save note: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Internal notes · Report #${widget.reportId}'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Only authorized maintenance staff and managers can see these notes. '
              'Residents do not see internal notes.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _notes.isEmpty
                      ? Center(child: Text(_error!))
                      : _notes.isEmpty
                          ? const Center(child: Text('No internal notes yet.'))
                          : ListView.builder(
                              itemCount: _notes.length,
                              itemBuilder: (context, index) {
                                final note = _notes[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(note.content),
                                  subtitle: Text(
                                    '${note.createdAt.toLocal()} · '
                                    '${note.authorId == widget.repository.staffId ? 'You' : 'Staff'}',
                                  ),
                                );
                              },
                            ),
            ),
            if (_error != null && _notes.isNotEmpty)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton.icon(
              onPressed: _loading || _saving ? null : _loadNotes,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh notes'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _content,
              enabled: !_saving,
              maxLength: 3000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Add an internal maintenance note',
                border: const OutlineInputBorder(),
                errorText: _fieldError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _saveNote,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save note'),
        ),
      ],
    );
  }
}
