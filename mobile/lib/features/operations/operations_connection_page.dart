import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Validate only the *public* connection details allowed in a browser build.
/// Server-side service_role and sb_secret keys must never enter this form.
String? validateOperationsPublicConnection(String url, String key) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasAuthority || uri.userInfo.isNotEmpty ||
      uri.hasQuery || uri.hasFragment || uri.path.isNotEmpty && uri.path != '/') {
    return 'Enter a Supabase project URL without a path, query or credentials.';
  }
  final hosted = uri.scheme == 'https' &&
      uri.host.endsWith('.supabase.co') &&
      uri.host.length > '.supabase.co'.length;
  final local = uri.scheme == 'http' &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1') &&
      uri.port == 54321;
  if (!hosted && !local) {
    return 'Use HTTPS *.supabase.co or local Supabase CLI on localhost:54321.';
  }
  if (key.trim().isEmpty ||
      key.trim().startsWith('sb_secret_') ||
      key.trim().startsWith('sb_service_') ||
      key.trim().startsWith('service_role')) {
    return 'Only a public publishable key or legacy anon JWT is permitted.';
  }
  final jwtParts = key.trim().split('.');
  final legacyAnon = jwtParts.length == 3 &&
      jwtParts.every((part) => part.isNotEmpty);
  if (!key.trim().startsWith('sb_publishable_') && !legacyAnon) {
    return 'Enter a Supabase publishable key or legacy anon JWT.';
  }
  return null;
}

class OperationsConnectionPage extends StatefulWidget {
  const OperationsConnectionPage({super.key, required this.onConnected});
  final VoidCallback onConnected;

  @override
  State<OperationsConnectionPage> createState() => _OperationsConnectionPageState();
}

class _OperationsConnectionPageState extends State<OperationsConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _busy = false;
  bool _showPublicKey = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final url = _url.text.trim();
    final key = _key.text.trim();
    final problem = validateOperationsPublicConnection(url, key);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      if (!mounted) return;
      widget.onConnected();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not initialize Supabase: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FixMate · Flutter Web Operations')),
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 510),
        child: Card(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.admin_panel_settings_outlined,
                    size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text('Connect your operations workspace',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'Sign in as maintenance staff, moderator or system admin. '
                  'You need the shared FixMate Supabase project URL and a '
                  'public browser API key.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                TextFormField(
                  key: const Key('operations_supabase_url'),
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Supabase project URL',
                    hintText: 'https://your-project.supabase.co',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Project URL is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('operations_supabase_key'),
                  controller: _key,
                  obscureText: !_showPublicKey,
                  decoration: InputDecoration(
                    labelText: 'Publishable / anon API key',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _showPublicKey ? 'Hide public key' : 'Show public key',
                      onPressed: () => setState(() => _showPublicKey = !_showPublicKey),
                      icon: Icon(_showPublicKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                    ),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Public API key is required' : null,
                ),
                const SizedBox(height: 10),
                const Text('Never enter a service-role or secret key. '
                    'The public key does not bypass authentication or RLS.'),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const Key('operations_connect'),
                  onPressed: _busy ? null : _connect,
                  icon: const Icon(Icons.login_outlined),
                  label: Text(_busy ? 'Connecting...' : 'Connect'),
                ),
              ]),
          ),
        )),
      ),
    )),
  );
}
