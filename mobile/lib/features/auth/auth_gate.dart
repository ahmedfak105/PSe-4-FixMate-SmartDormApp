import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/resident_profile.dart';
import '../../data/repositories/resident_profile_repository.dart';
import 'login_page.dart';
import '../operations/operations_role.dart';

/// Checks the Supabase session and loads the user's real profile before
/// allowing entry to Resident screens. The database must still enforce RLS.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.builder, this.operationsOnly = false});

  final bool operationsOnly;

  final Widget Function(ResidentProfile profile) builder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final SupabaseClient _client;
  late final ResidentProfileRepository _repository;
  StreamSubscription<AuthState>? _subscription;
  String? _userId;
  Future<ResidentProfile>? _profileFuture;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _repository = ResidentProfileRepository(_client);
    _userId = _client.auth.currentUser?.id;
    if (_userId != null) _profileFuture = _repository.getCurrent();
    _subscription = _client.auth.onAuthStateChange.listen(
      (event) {
        if (!mounted) return;
        final nextId = event.session?.user.id;
        if (_userId == nextId) return;
        setState(() {
          _userId = nextId;
          _authError = null;
          _profileFuture = nextId == null ? null : _repository.getCurrent();
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (mounted) {
          setState(() => _authError =
              'Authentication connection error. Check your connection.');
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _retry() {
    setState(() => _profileFuture = _repository.getCurrent());
  }

  Future<void> _signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please retry.')),
      );
    }
  }

  Widget _message({
    required String heading,
    required String description,
    bool allowRetry = false,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('FixMate')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.manage_accounts_outlined, size: 50),
                const SizedBox(height: 16),
                Text(heading, style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(description, textAlign: TextAlign.center),
                if (allowRetry) ...[
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _retry, child: const Text('Retry')),
                ],
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _signOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return LoginPage(connectionError: _authError);

    return FutureBuilder<ResidentProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          debugPrint('FixMate profile read failed: ${snapshot.error}');
          return _message(
            heading: 'Profile not available',
            description: 'The account signed in, but FixMate could not read '
                'its profile from Supabase. Check the profiles row, Data API '
                'access, and RLS permissions.',
            allowRetry: true,
          );
        }
        final profile = snapshot.data!;
        if (workspaceForRole(profile.role,
                operationsOnly: widget.operationsOnly) == FixMateWorkspace.denied) {
          return _message(
            heading: 'Account role not permitted in this workspace',
            description: widget.operationsOnly
                ? 'This Flutter Web operations workspace is for Maintenance Staff, '
                    'Moderators and System Admins only. The signed-in role is ${profile.role}.'
                : 'This Flutter mobile application supports Resident and Maintenance Staff '
                    'accounts. The signed-in role is ${profile.role}. '
                    'Use the Operations Web application for Moderator and Admin access.',
          );
        }
        return widget.builder(profile);
      },
    );
  }
}
