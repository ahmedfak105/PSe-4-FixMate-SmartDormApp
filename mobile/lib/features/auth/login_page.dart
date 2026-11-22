import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sign_up_page.dart';
import '../../l10n/fixmate_i18n.dart';
import '../support/fixmate_support_page.dart';
import 'password_recovery_page.dart';

/// Sign in with Supabase Auth or register a new Resident account.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.connectionError,
      this.allowResidentSignup = true, this.successMessage});

  final String? connectionError;
  final String? successMessage;
  final bool allowResidentSignup;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _passwordVisible = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // AuthGate listens to auth state and will display the app.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Unable to sign in. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const FixMateText('FixMate'),
          actions: const [FixMateLanguageButton(), FixMateSupportMenu()]),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 78, height: 78,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF127F76), Color(0xFF23B4A5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(23),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFF127F76).withValues(alpha: 0.18),
                            blurRadius: 24, offset: const Offset(0, 10),
                          )],
                        ),
                        child: const Icon(Icons.home_repair_service_rounded,
                          size: 42, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const FixMateText('SMART DORM MAINTENANCE',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF127F76),
                        fontSize: 10, letterSpacing: 1.5,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    FixMateText('Welcome to FixMate',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    FixMateText(widget.allowResidentSignup
                            ? 'Sign in or create a resident account.'
                            : 'Authorized maintenance staff, moderators and administrators only.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const Key('login_email'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty || !email.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('login_password'),
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                          icon: Icon(_passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(
                              () => _passwordVisible = !_passwordVisible),
                        ),
                      ),
                      validator: (value) => (value ?? '').isEmpty
                          ? 'Enter your password'
                          : null,
                      onFieldSubmitted: (_) => _signIn(),
                    ),
                    if (widget.successMessage != null) ...[
                      const SizedBox(height: 14),
                      FixMateText(widget.successMessage!,
                        key: const Key('reset_password_success'),
                        style: const TextStyle(color: Color(0xFF127F76))),
                    ],
                    if (_error != null || widget.connectionError != null) ...[
                      const SizedBox(height: 16),
                      FixMateText(_error ?? widget.connectionError!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('login_submit'),
                      onPressed: _busy ? null : _signIn,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const FixMateText('Sign in'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('go_to_password_recovery'),
                      onPressed: _busy ? null : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PasswordRecoveryRequestPage(
                            initialEmail: _emailController.text.trim(),
                          ),
                        ),
                      ),
                      child: const FixMateText('Forgot password?'),
                    ),
                    // Enabled after isolated local Supabase Auth + profile/RLS
                    // API tests passed. Set ENABLE_RESIDENT_SIGNUP=false
                    // to hide registration for deployments that disable signup.
                    if (widget.allowResidentSignup && const bool.fromEnvironment(
                      'ENABLE_RESIDENT_SIGNUP', defaultValue: true,
                    )) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('go_to_signup'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SignUpPage(),
                          ),
                        ),
                        child: const FixMateText('Create resident account'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const FixMateText(
                      'Residents can view and submit maintenance reports after signing in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
