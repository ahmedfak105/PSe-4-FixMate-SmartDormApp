import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Android-only opt-in Firebase Cloud Messaging integration.
///
/// Firebase sender credentials never belong in this application. Device
/// tokens are sent to owner-scoped Supabase storage over the signed-in
/// user's normal session. Remote delivery still needs the audited server
/// sender and an approved hosted migration (release gate #47).
class FixMatePushService {
  FixMatePushService._();
  static final FixMatePushService instance = FixMatePushService._();

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool _ready = false;
  bool get ready => supported && _ready;

  StreamSubscription<String>? _refreshSubscription;

  String _preferenceKey(String userId) => 'fixmate_push_opted_in_$userId';

  Future<void> initialize() async {
    if (!supported || _ready) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
      // Consent comes from the user's explicit "Enable notifications" action.
      // This also prevents automatic registration for shared test devices.
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(false);
    } catch (_) {
      // Android without Google Play Services, incomplete config or offline
      // demos continue to run without push. No token or credential is logged.
      _ready = false;
    }
  }

  Future<bool> isOptedIn(String userId) async {
    if (!ready) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_preferenceKey(userId)) == true;
  }

  Future<void> _registerToken(
      SupabaseClient client, String ownerId, String token) async {
    if (client.auth.currentUser?.id != ownerId) return;
    await client.from('push_device_tokens').upsert({
      'token': token,
      'user_id': ownerId,
      'platform': 'android',
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  void _observeTokenRefresh(SupabaseClient client, String ownerId) {
    _refreshSubscription?.cancel();
    _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        if (client.auth.currentUser?.id != ownerId) return;
        if (!await isOptedIn(ownerId)) return;
        try {
          await _registerToken(client, ownerId, token);
        } catch (_) {
          // Token rotation can retry on the next profile opening. Do not log
          // tokens or let a transient server problem block the resident UI.
        }
      },
    );
  }

  Future<void> enableForResident(SupabaseClient client) async {
    if (!ready) throw StateError('Firebase is not available on this device.');
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in before enabling notifications.');

    final row = await client.from('profiles')
        .select('role').eq('id', userId).single();
    if (row['role'] != 'resident') {
      throw StateError('Only residents can enable report notifications.');
    }

    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError('Notification permission was not granted.');
    }

    await messaging.setAutoInitEnabled(true);
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('This device did not return an FCM token.');
    }

    try {
      await _registerToken(client, userId, token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_preferenceKey(userId), true);
      _observeTokenRefresh(client, userId);
    } catch (_) {
      // A missing (not yet deployed) Supabase table is not a successful
      // subscription. Invalidate the token and keep permission state separate.
      await messaging.deleteToken();
      await messaging.setAutoInitEnabled(false);
      rethrow;
    }
  }

  Future<void> restoreIfEnabled(SupabaseClient client, String userId) async {
    if (!ready || client.auth.currentUser?.id != userId) return;
    if (!await isOptedIn(userId)) return;
    try {
      final role = await client.from('profiles')
          .select('role').eq('id', userId).single();
      if (role['role'] != 'resident') {
        await disable(client, userId);
        return;
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      final token = await messaging.getToken();
      if (token != null) await _registerToken(client, userId, token);
      _observeTokenRefresh(client, userId);
    } catch (_) {
      // Retry only from a signed-in screen; no background writes without
      // knowing the current authenticated account.
    }
  }

  /// Invalidate the local token even if the network/server is unavailable.
  /// Called BEFORE Supabase signOut to prevent a shared phone continuing to
  /// receive the previous resident's alerts.
  Future<void> disable(SupabaseClient client, String userId) async {
    if (!ready) return;
    _refreshSubscription?.cancel();
    _refreshSubscription = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_preferenceKey(userId));

    final messaging = FirebaseMessaging.instance;
    try {
      final token = await messaging.getToken();
      if (token != null && client.auth.currentUser?.id == userId) {
        await client.from('push_device_tokens')
            .delete().eq('token', token).eq('user_id', userId);
      }
    } catch (_) {
      // Firebase invalidates the local token below even if server revocation
      // cannot be reached. The sender must purge invalid/stale tokens too.
    } finally {
      try {
        await messaging.deleteToken();
        await messaging.setAutoInitEnabled(false);
      } catch (_) {
        // Never block signing out because the FCM service is unavailable.
      }
    }
  }
}
