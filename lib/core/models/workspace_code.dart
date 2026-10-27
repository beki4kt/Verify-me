/// Workspace codes are locators, never authentication credentials.
abstract final class WorkspaceCode {
  // Matches the operator console's legacy and generated code contract.
  static final RegExp _format = RegExp(r'^[A-Z0-9-]{3,32}$');

  static String? normalize(String input) {
    final value = input.trim().toUpperCase();
    return _format.hasMatch(value) ? value : null;
  }
}
