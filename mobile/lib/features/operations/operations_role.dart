/// Central role-routing helper for the FixMate Flutter operations build.
///
/// This function only controls navigation. Database RLS and RPC permission
/// checks are the security boundary, never role-based widget visibility.
enum FixMateWorkspace { resident, maintenanceStaff, moderator, systemAdmin, denied }

FixMateWorkspace workspaceForRole(String role, {required bool operationsOnly}) {
  switch (role.trim().toLowerCase()) {
    case 'resident':
      return operationsOnly ? FixMateWorkspace.denied : FixMateWorkspace.resident;
    case 'maintenance_staff':
      return FixMateWorkspace.maintenanceStaff;
    case 'moderator':
      return operationsOnly ? FixMateWorkspace.moderator : FixMateWorkspace.denied;
    case 'system_admin':
      return operationsOnly ? FixMateWorkspace.systemAdmin : FixMateWorkspace.denied;
    default:
      return FixMateWorkspace.denied;
  }
}
