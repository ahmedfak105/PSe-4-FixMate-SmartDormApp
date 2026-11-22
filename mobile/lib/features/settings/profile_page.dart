import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/resident_profile.dart';
import '../../l10n/gen/app_localizations.dart';
import 'locale_cubit.dart';
import 'edit_profile_page.dart';
import 'my_profile_avatar.dart';
import '../support/fixmate_support_page.dart';
import '../notifications/fixmate_push_service.dart';
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
  bool _pushEnabled = false;
  bool _pushBusy = false;
  String? _pushMessage;

  bool get _supportsPush => widget.profile != null &&
      widget.profile!.role == 'resident' &&
      FixMatePushService.instance.supported;

  @override
  void initState() {
    super.initState();
    if (_supportsPush) _refreshPush();
  }

  Future<void> _refreshPush() async {
    final profile = widget.profile;
    if (profile == null || !_supportsPush) return;
    final client = Supabase.instance.client;
    try {
      await FixMatePushService.instance.restoreIfEnabled(client, profile.id);
      final optedIn = await FixMatePushService.instance.isOptedIn(profile.id);
      if (mounted) setState(() => _pushEnabled = optedIn);
    } catch (_) {
      // A missing server extension leaves the opt-in controls available
      // for a later approved deployment; never invent a success status.
    }
  }

  Future<void> _togglePush(bool enabled) async {
    final profile = widget.profile;
    if (_pushBusy || profile == null || !_supportsPush) return;
    setState(() {
      _pushBusy = true;
      _pushMessage = null;
    });
    try {
      final service = FixMatePushService.instance;
      final client = Supabase.instance.client;
      if (enabled) {
        await service.enableForResident(client);
      } else {
        await service.disable(client, profile.id);
      }
      if (!mounted) return;
      setState(() {
        _pushEnabled = enabled;
        _pushMessage = enabled
            ? 'Push notifications enabled on this Android device.'
            : 'Push notifications disabled on this Android device.';
      });
    } on PostgrestException {
      if (mounted) setState(() => _pushMessage =
          'Push notifications are not enabled on this server yet.');
    } on StateError {
      if (mounted) setState(() => _pushMessage =
          'Cannot enable notifications. Check your device permission and connection.');
    } catch (_) {
      if (mounted) setState(() => _pushMessage =
          'Could not change push notifications. Please retry.');
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }


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
      // Revoke the previous resident's FCM token before the Supabase
      // session disappears. The service never blocks sign-out on FCM errors.
      if (_supportsPush) {
        await FixMatePushService.instance.disable(
          Supabase.instance.client, widget.profile!.id);
      }
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
      appBar: AppBar(title: FixMateText(l10n.tabProfile),
        actions: const [FixMateLanguageButton(), FixMateSupportMenu()]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        profile == null
            ? const CircleAvatar(radius: 36, child: Icon(Icons.person_outline, size: 36))
            : Center(child: MyProfileAvatar(
                key: ValueKey('avatar-${profile.id}-$_avatarRevision'),
                userId: profile.id, name: profile.fullName)),
        const SizedBox(height: 12),
        Center(
          child: FixMateText(
            profile?.fullName ?? l10n.demoResident,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 20),
        if (profile == null) ...[
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: FixMateText(l10n.authNotConnected),
            subtitle: FixMateText(l10n.demoNotice),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const FixMateText('Edit personal information'),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const FixMateText('Email'),
            subtitle: FixMateText(email ?? 'Not available'),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const FixMateText('Role'),
            subtitle: FixMateText(profile.role),
          ),
          ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: const FixMateText('Building'),
            subtitle: FixMateText(profile.building?.trim().isNotEmpty == true
                ? profile.building!
                : 'Not set'),
          ),
          ListTile(
            leading: const Icon(Icons.meeting_room_outlined),
            title: const FixMateText('Room number'),
            subtitle: FixMateText(profile.roomNumber?.trim().isNotEmpty == true
                ? profile.roomNumber!
                : 'Not set'),
          ),
        ],
        if (_supportsPush) ...[
          const Divider(),
          SwitchListTile(
            key: const Key('resident_push_opt_in'),
            contentPadding: EdgeInsets.zero,
            title: const FixMateText('Push notifications'),
            subtitle: const FixMateText(
              'Receive Android alerts when your maintenance report status changes.'),
            value: _pushEnabled,
            onChanged: _pushBusy || !FixMatePushService.instance.ready
                ? null : _togglePush,
          ),
          if (!FixMatePushService.instance.ready)
            const FixMateText('Firebase is not available on this device.'),
          if (_pushBusy) const LinearProgressIndicator(),
          if (_pushMessage != null)
            FixMateText(_pushMessage!, style:
              Theme.of(context).textTheme.bodySmall),
        ],
        const Divider(),
        FixMateText(l10n.language, style: Theme.of(context).textTheme.titleMedium),
        ListTile(
          title: const FixMateText('English'),
          onTap: () => localeCubit.setLocale(const Locale('en')),
        ),
        ListTile(
          title: const FixMateText('Lietuvių'),
          onTap: () => localeCubit.setLocale(const Locale('lt')),
        ),
        if (profile != null) ...[
          const Divider(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: FixMateText(_signingOut ? 'Signing out...' : 'Sign out'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            FixMateText(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ]),
    );
  }
}
