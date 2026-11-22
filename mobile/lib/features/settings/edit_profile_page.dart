import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/resident_profile.dart';
import '../../data/repositories/resident_profile_repository.dart';
import '../../fixmate_theme.dart';

/// Shared identity editor for Resident, Maintenance Staff, Moderator and Admin.
/// Roles and account identities are intentionally not editable here.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});
  final ResidentProfile profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _building;
  late final TextEditingController _room;
  bool _saving = false;
  bool _photoBusy = false;
  String? _error;
  Uint8List? _avatar;
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _building = TextEditingController(text: widget.profile.building ?? '');
    _room = TextEditingController(text: widget.profile.roomNumber ?? '');
    _loadPhoto();
  }

  @override
  void dispose() {
    _name.dispose();
    _building.dispose();
    _room.dispose();
    super.dispose();
  }

  SupabaseClient get _client => Supabase.instance.client;

  bool get _mySession =>
      _client.auth.currentUser?.id == widget.profile.id;

  Future<void> _loadPhoto() async {
    if (!_mySession) return;
    try {
      // Photo storage is an optional, separately versioned schema extension.
      // Existing hosted installations may not have avatar_path yet.
      final row = await _client.from('profiles')
          .select('avatar_path').eq('id', widget.profile.id).single();
      final path = row['avatar_path'] as String?;
      if (path == null || path.isEmpty) return;
      final bytes = await _client.storage.from('profile-avatars').download(path);
      if (mounted && _mySession) {
        setState(() { _avatarPath = path; _avatar = bytes; });
      }
    } on PostgrestException {
      // Existing six-table production database has no avatar_path until its
      // separately reviewed additive migration is deployed.
    } on StorageException {
      // Missing optional bucket or inaccessible photo: keep initials visible.
    } catch (_) {
      // A profile remains editable even if its optional photo cannot load.
    }
  }

  Future<void> _pickPhoto() async {
    if (_photoBusy || !_mySession) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 720, maxHeight: 720, imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty || bytes.lengthInBytes > 2 * 1024 * 1024) {
      setState(() => _error = 'Choose an image smaller than 2 MB.');
      return;
    }
    final lower = picked.name.toLowerCase();
    final isPng = lower.endsWith('.png');
    final isWebp = lower.endsWith('.webp');
    final type = isPng ? 'image/png' : isWebp ? 'image/webp' : 'image/jpeg';
    final extension = isPng ? 'png' : isWebp ? 'webp' : 'jpg';
    setState(() { _photoBusy = true; _error = null; });
    String? uploadedPath;
    try {
      if (!_mySession) throw StateError('Session changed.');
      uploadedPath = '${widget.profile.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await _client.storage.from('profile-avatars').uploadBinary(
        uploadedPath, bytes,
        fileOptions: FileOptions(contentType: type, upsert: false),
      );
      if (!_mySession) throw StateError('Session changed.');
      await _client.from('profiles').update({'avatar_path': uploadedPath})
          .eq('id', widget.profile.id).select('id').single();
      if (!mounted || !_mySession) return;
      setState(() { _avatar = bytes; _avatarPath = uploadedPath; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (_) {
      // A failed upload or missing avatar migration must not block text edits.
      if (mounted) {
        setState(() => _error = 'Photo upload is not available on this server yet. '
            'Your other profile details can still be saved.');
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_mySession || !_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final updated = await ResidentProfileRepository(_client)
          .updateMyContactDetails(
        fullName: _name.text,
        building: _building.text,
        roomNumber: _room.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (_) {
      if (mounted) setState(() =>
          _error = 'Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.text.trim().isNotEmpty
        ? _name.text.trim().substring(0, 1).toUpperCase() : '?';
    final resident = widget.profile.isResident;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Stack(children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: FixMateTheme.mint,
                      backgroundImage: _avatar == null ? null : MemoryImage(_avatar!),
                      child: _avatar == null
                          ? Text(initial, style: const TextStyle(
                              color: FixMateTheme.teal,
                              fontSize: 34, fontWeight: FontWeight.w800))
                          : null,
                    ),
                    Positioned(bottom: 0, right: 0,
                      child: Material(
                        color: FixMateTheme.teal, shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Change profile photo',
                          onPressed: _photoBusy ? null : _pickPhoto,
                          icon: _photoBusy
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt_outlined,
                                  color: Colors.white, size: 19),
                        ),
                      ),
                    ),
                  ])),
                  const SizedBox(height: 15),
                  const Text('Your account', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(_client.auth.currentUser?.email ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF607B83))),
                  const SizedBox(height: 25),
                  TextFormField(
                    key: const Key('edit_profile_name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter your full name' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('edit_profile_building'),
                    controller: _building,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: resident ? 'Building' : 'Building (optional)',
                      prefixIcon: const Icon(Icons.apartment_outlined)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('edit_profile_room'),
                    controller: _room,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: resident ? 'Room number' : 'Room (optional)',
                      prefixIcon: const Icon(Icons.meeting_room_outlined)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Account role and email are managed separately '
                      'and cannot be changed here.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF607B83))),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('save_profile'),
                    onPressed: _saving || !_mySession ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save changes'),
                  ),
                ],
              ),
            ),
          )),
        ]),
      )),
    );
  }
}
