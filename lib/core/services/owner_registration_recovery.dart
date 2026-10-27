/// Recover an owner workspace request when the network loses the commit
/// response. The database still enforces one owner identity per workspace.
Future<Map<String, dynamic>> requestOwnerWorkspaceIdempotently({
  required Future<Map<String, dynamic>?> Function() lookup,
  required Future<Map<String, dynamic>> Function() create,
}) async {
  final existing = await lookup();
  if (existing != null) return existing;
  try {
    return await create();
  } catch (_) {
    try {
      final recovered = await lookup();
      if (recovered != null) return recovered;
    } catch (_) {
      // Preserve the original create error if the recovery read also fails.
    }
    rethrow;
  }
}
