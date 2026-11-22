import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'password_recovery_links.dart';

/// Available from the sign-in screen for every role. Success text never
/// reveals whether the address belongs to a FixMate account.
class PasswordRecoveryRequestPage extends StatefulWidget {
  const PasswordRecoveryRequestPage({
    super.key,
    this.initialEmail = '',
    this.sendResetEmail,
  });

  final String initialEmail;
  /// Dependency-injection seam for free offline widget tests.
  final Future<void> Function(String email, String redirectTo)? sendResetEmail;

  @override
  State<PasswordRecoveryRequestPage> createState() =>
      _PasswordRecoveryRequestPageState();
}

class _PasswordRecoveryRequestPageState
    extends State<PasswordRecoveryRequestPage> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _email;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_key.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final address = _email.text.trim();
      final redirect = fixMatePasswordRecoveryRedirect();
      if (widget.sendResetEmail != null) {
        await widget.sendResetEmail!(address, redirect);
      } else {
        await Supabase.instance.client.auth.resetPasswordForEmail(
          address,
          redirectTo: redirect,
        );
      }
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (error) {
      // Avoid exposing whether an account exists; recoverable rate-limit and
      // delivery errors are presented identically across email addresses.
      debugPrint('FixMate password recovery request failed: ${error.statusCode}');
      if (mounted) setState(() =>
          _error = 'The request could not be processed right now. Please try again later.');
    } catch (_) {
      if (mounted) setState(() =>
          _error = 'The request could not be processed right now. Please try again later.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 450),
      child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: _sent
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.mark_email_read_outlined,
                  color: Color(0xFF127F76), size: 56),
              const SizedBox(height: 16),
              Text('Check your email',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('If an account matches that email address, '
                  'you will receive a password reset link. Check your inbox '
                  'and spam folder. The link may expire.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 22),
              OutlinedButton(onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to sign in')),
            ])
          : Form(key: _key, child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.lock_reset_outlined, size: 56,
                    color: Color(0xFF127F76)),
                const SizedBox(height: 14),
                Text('Forgot your password?',
                  style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Enter your account email to request a secure reset link.'),
                const SizedBox(height: 22),
                TextFormField(
                  key: const Key('recovery_email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => !RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$')
                      .hasMatch((v ?? '').trim())
                      ? 'Enter a valid email address' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('recovery_submit'),
                  onPressed: _busy ? null : _send,
                  child: Text(_busy ? 'Sending…' : 'Send reset link')),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Back to sign in')),
              ],
            )),
      ),
    )),
  );
}

/// The recovery link creates a short-lived authenticated recovery session.
/// This page does not allow a password update without such a session.
class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({
    super.key,
    required this.onCompleted,
    this.hasRecoverySession,
    this.updatePassword,
    this.signOut,
  });

  final VoidCallback onCompleted;
  final bool Function()? hasRecoverySession;
  final Future<void> Function(String password)? updatePassword;
  final Future<void> Function()? signOut;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _key = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _hasSession =>
      widget.hasRecoverySession?.call() ??
      Supabase.instance.client.auth.currentSession != null;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    if (_busy || !_hasSession || !_key.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (widget.updatePassword != null) {
        await widget.updatePassword!(_password.text);
      } else {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: _password.text),
        );
      }
      // Force a fresh sign-in with the new password after a successful reset.
      if (widget.signOut != null) {
        await widget.signOut!();
      } else {
        await Supabase.instance.client.auth.signOut();
      }
      if (mounted) widget.onCompleted();
    } on AuthException catch (_) {
      if (mounted) setState(() =>
          _error = 'Could not update the password. The recovery link may '
              'have expired. Request a new link and try again.');
    } catch (_) {
      if (mounted) setState(() =>
          _error = 'Could not finish the password reset. Please try again.');
    } finally {
      _password.clear();
      _confirm.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create new password')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: !_hasSession
          ? Column(children: [
              const Icon(Icons.link_off_outlined, size: 52),
              const SizedBox(height: 15),
              const Text('This password reset link is invalid or expired. '
                  'Return to sign in and request a new link.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextButton(onPressed: widget.onCompleted,
                child: const Text('Back to sign in')),
            ])
          : Form(key: _key, child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.security_outlined, size: 56,
                  color: Color(0xFF127F76)),
                const SizedBox(height: 16),
                Text('Choose a new password',
                  style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Use at least 8 characters. You will sign in again '
                    'after your password changes.'),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('recovery_new_password'),
                  controller: _password, obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) => (v ?? '').length < 8
                      ? 'Use at least 8 characters' : null),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('recovery_confirm_password'),
                  controller: _confirm, obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: Icon(Icons.lock_reset_outlined)),
                  validator: (v) => v != _password.text
                      ? 'Passwords do not match' : null),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  key: const Key('recovery_update_password'),
                  onPressed: _busy ? null : _update,
                  child: Text(_busy ? 'Saving…' : 'Update password')),
              ],
            )),
      ),
    )),
  );
}
