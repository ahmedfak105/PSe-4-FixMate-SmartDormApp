import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// TASK #30: resident registration only. No role chooser is present or sent.
/// The database trigger must create the resident profile securely.
/// Keep registration disabled until staging verification of that trigger.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _key = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _building = TextEditingController();
  final _room = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _building.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy || !_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {
          'full_name': _fullName.text.trim(),
          'building': _building.text.trim(),
          'room_number': _room.text.trim(),
        },
      );
      if (!mounted) return;
      if (response.user == null) {
        setState(() => _error = 'Registration was not completed. Please try again.');
      } else if (response.session != null) {
        // AuthGate listens to the new authenticated session.
        Navigator.of(context).pop();
      } else {
        setState(() => _success =
            'If your registration was accepted, check your email for a confirmation message, then sign in.');
        _password.clear();
        _confirmPassword.clear();
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not register. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create resident account')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Register for FixMate',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text('New accounts always start with the Resident role. Staff and administrator accounts are created by authorized personnel.'),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('signup_full_name'),
                      controller: _fullName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final name = (value ?? '').trim();
                        if (name.isEmpty) return 'Full name is required';
                        if (name.length > 100) return 'Maximum 100 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('signup_email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('signup_building'),
                      controller: _building,
                      decoration: const InputDecoration(
                        labelText: 'Dormitory building (optional)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value ?? '').trim().length > 80
                              ? 'Maximum 80 characters'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('signup_room'),
                      controller: _room,
                      decoration: const InputDecoration(
                        labelText: 'Room number (optional)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value ?? '').trim().length > 30
                              ? 'Maximum 30 characters'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('signup_password'),
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 8) {
                          return 'Use at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('signup_confirm_password'),
                      controller: _confirmPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value != _password.text
                              ? 'Passwords do not match'
                              : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      )),
                    ],
                    if (_success != null) ...[
                      const SizedBox(height: 16),
                      Text(_success!, style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      )),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      key: const Key('signup_submit'),
                      onPressed: _busy ? null : _register,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_busy ? 'Creating account…' : 'Create resident account'),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
