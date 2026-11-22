import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/resident_profile.dart';
import '../../l10n/gen/app_localizations.dart';
import 'locale_cubit.dart';
import 'edit_profile_page.dart';
import 'my_profile_avatar.dart';
import '../support/fixmate_support_page.dart';
import '../../l10n/fixmate_i18n.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.profile});

  /// Null only while running offline demo mode.
  final ResidentProfile? profile;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _signingOut = false;
  String? _error;
  ResidentProfile? _currentProfile;
  int _avatarRevision = 0;

  Future<void> _editProfile() async {
    final original = _currentProfile ?? widget.profile;
    if (original == null) return;
    final changed = await Navigator.of(context).push<ResidentProfile>(
      MaterialPageRoute(builder: (_) => EditProfilePage(profile: original)),
    );
    if (changed != null && mounted) {
      setState(() { _currentProfile = changed; _avatarRevision++; });
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not sign out. Please try again.');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCubit = context.read<LocaleCubit>();
    final profile = _currentProfile ?? widget.profile;
    final email = profile == null
        ? null
        : Supabase.instance.client.auth.currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabProfile),
        actions: const [FixMateLanguageButton(), FixMateSupportMenu()]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        profile == null
            ? const CircleAvatar(radius: 36, child: Icon(Icons.person_outline, size: 36))
            : Center(child: MyProfileAvatar(
                key: ValueKey('avatar-${profile.id}-$_avatarRevision'),
                userId: profile.id, name: profile.fullName)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            profile?.fullName ?? l10n.demoResident,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 20),
        if (profile == null) ...[
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.authNotConnected),
            subtitle: Text(l10n.demoNotice),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit personal information'),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(email ?? 'Not available'),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Role'),
            subtitle: Text(profile.role),
          ),
          ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Building'),
            subtitle: Text(profile.building?.trim().isNotEmpty == true
                ? profile.building!
                : 'Not set'),
          ),
          ListTile(
            leading: const Icon(Icons.meeting_room_outlined),
            title: const Text('Room number'),
            subtitle: Text(profile.roomNumber?.trim().isNotEmpty == true
                ? profile.roomNumber!
                : 'Not set'),
          ),
        ],
        const Divider(),
        Text(l10n.language, style: Theme.of(context).textTheme.titleMedium),
        ListTile(
          title: const Text('English'),
          onTap: () => localeCubit.setLocale(const Locale('en')),
        ),
        ListTile(
          title: const Text('Lietuvių'),
          onTap: () => localeCubit.setLocale(const Locale('lt')),
        ),
        if (profile != null) ...[
          const Divider(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: Text(_signingOut ? 'Signing out...' : 'Sign out'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ]),
    );
  }
}
