import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/features/operations/operations_connection_page.dart';

String keyForRole(String role) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
      .replaceAll('=', '');
  final claims = base64Url.encode(
    utf8.encode(jsonEncode({'role': role, 'iss': 'supabase'})),
  ).replaceAll('=', '');
  return '$header.$claims.signature';
}

void main() {
  test('accepts publishable keys for HTTPS Supabase, or local CLI', () {
    expect(validateOperationsPublicConnection(
        'https://my-demo.supabase.co', 'sb_publishable_testing'), isNull);
    expect(validateOperationsPublicConnection(
        'http://127.0.0.1:54321', 'sb_publishable_testing'), isNull);
  });

  test('accepts only legacy anon JWT, rejecting service_role JWT', () {
    expect(validateOperationsPublicConnection(
        'https://demo.supabase.co', keyForRole('anon')), isNull);
    expect(validateOperationsPublicConnection(
        'https://demo.supabase.co', keyForRole('service_role')),
        contains('anon JWT'));
    expect(validateOperationsPublicConnection(
        'https://demo.supabase.co', keyForRole('authenticated')),
        contains('anon JWT'));
  });

  test('blocks secret keys, arbitrary web endpoints and URL credentials', () {
    expect(validateOperationsPublicConnection(
        'https://demo.supabase.co', 'sb_secret_test'), isNotNull);
    expect(validateOperationsPublicConnection(
        'https://demo.supabase.co', 'abc.def.ghi'), isNotNull);
    expect(validateOperationsPublicConnection(
        'https://example.com', 'sb_publishable_test'), isNotNull);
    expect(validateOperationsPublicConnection(
        'http://remote.example:54321', 'sb_publishable_test'), isNotNull);
    expect(validateOperationsPublicConnection(
        'https://user:password@demo.supabase.co', 'sb_publishable_test'), isNotNull);
  });

  testWidgets('shows public connection form without server secrets', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OperationsConnectionPage(onConnected: () {}),
    ));
    expect(find.byKey(const Key('operations_supabase_url')), findsOneWidget);
    expect(find.byKey(const Key('operations_supabase_key')), findsOneWidget);
    expect(find.textContaining('Never enter a service-role'), findsOneWidget);
  });
}
