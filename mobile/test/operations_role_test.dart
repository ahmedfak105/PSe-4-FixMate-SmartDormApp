import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixmate_mobile/features/auth/login_page.dart';
import 'package:fixmate_mobile/features/operations/operations_role.dart';

void main() {
  testWidgets('Operations sign-in does not offer Resident registration', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: LoginPage(allowResidentSignup: false),
    ));
    expect(find.byKey(const Key('go_to_signup')), findsNothing);
    expect(find.textContaining('Authorized maintenance staff'), findsOneWidget);
  });

  group('Flutter Web operations role navigation', () {
    test('staff, moderator and system_admin route to dedicated web screens', () {
      expect(workspaceForRole('maintenance_staff', operationsOnly: true),
          FixMateWorkspace.maintenanceStaff);
      expect(workspaceForRole('moderator', operationsOnly: true),
          FixMateWorkspace.moderator);
      expect(workspaceForRole('system_admin', operationsOnly: true),
          FixMateWorkspace.systemAdmin);
    });

    test('unified web allows Resident without exposing privileged screens', () {
      expect(workspaceForRole('resident', operationsOnly: true,
          allowResidentWeb: true), FixMateWorkspace.resident);
      expect(workspaceForRole('maintenance_staff', operationsOnly: true,
          allowResidentWeb: true), FixMateWorkspace.maintenanceStaff);
      expect(workspaceForRole('moderator', operationsOnly: true,
          allowResidentWeb: true), FixMateWorkspace.moderator);
      expect(workspaceForRole('system_admin', operationsOnly: true,
          allowResidentWeb: true), FixMateWorkspace.systemAdmin);
      expect(workspaceForRole('not_a_real_role', operationsOnly: true,
          allowResidentWeb: true), FixMateWorkspace.denied);
    });

    testWidgets('unified web sign-in offers Resident registration', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginPage(allowResidentSignup: true),
      ));
      expect(find.byKey(const Key('go_to_signup')), findsOneWidget);
      expect(find.textContaining('Authorized maintenance staff'), findsNothing);
    });

    test('resident cannot access privileged Flutter Web workspace', () {
      expect(workspaceForRole('resident', operationsOnly: true),
          FixMateWorkspace.denied);
    });

    test('mobile keeps resident and maintenance staff but excludes admin roles', () {
      expect(workspaceForRole('resident', operationsOnly: false),
          FixMateWorkspace.resident);
      expect(workspaceForRole('maintenance_staff', operationsOnly: false),
          FixMateWorkspace.maintenanceStaff);
      expect(workspaceForRole('moderator', operationsOnly: false),
          FixMateWorkspace.denied);
      expect(workspaceForRole('system_admin', operationsOnly: false),
          FixMateWorkspace.denied);
    });

    test('unknown or hostile role text is denied', () {
      expect(workspaceForRole('god_mode', operationsOnly: true),
          FixMateWorkspace.denied);
      expect(workspaceForRole('', operationsOnly: true),
          FixMateWorkspace.denied);
      expect(workspaceForRole(' resident ', operationsOnly: true),
          FixMateWorkspace.denied);
    });
  });
}
