/// A pure startup decision. Authorization still comes from the server-side
/// owner session RPC or a successful staff login; no cached role grants access.
enum EntryRoute {
  recovery,
  ownerWorkspace,
  ownerStatus,
  registration,
  staffLogin,
  welcome,
}

abstract final class EntryRouter {
  static EntryRoute resolve({
    required bool recoveryRequested,
    required bool ownerAuthenticated,
    required bool ownerRegistrationExists,
    required bool ownerWorkspaceSessionAccepted,
    required bool hasDraft,
    required bool hasLockedBusiness,
  }) {
    if (recoveryRequested) return EntryRoute.recovery;
    if (ownerAuthenticated) {
      if (!ownerRegistrationExists) return EntryRoute.registration;
      return ownerWorkspaceSessionAccepted
          ? EntryRoute.ownerWorkspace
          : EntryRoute.ownerStatus;
    }
    // A saved setup draft is resumed when the person chooses Get Started.
    // It must not replace the signed-out welcome and connection choices.
    if (hasDraft) return EntryRoute.welcome;
    if (hasLockedBusiness) return EntryRoute.staffLogin;
    return EntryRoute.welcome;
  }
}
