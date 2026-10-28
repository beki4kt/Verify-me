import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/session/entry_route.dart';

void main() {
  EntryRoute route({
    bool recovery = false,
    bool owner = false,
    bool registration = false,
    bool serverAccepted = false,
    bool draft = false,
    bool locked = false,
  }) => EntryRouter.resolve(
    recoveryRequested: recovery,
    ownerAuthenticated: owner,
    ownerRegistrationExists: registration,
    ownerWorkspaceSessionAccepted: serverAccepted,
    hasDraft: draft,
    hasLockedBusiness: locked,
  );

  test('server acceptance is required to enter the owner dashboard', () {
    expect(route(owner: true, registration: true), EntryRoute.ownerStatus);
    expect(
      route(owner: true, registration: true, serverAccepted: true),
      EntryRoute.ownerWorkspace,
    );
  });

  test('recovery wins over cached workspace or registration', () {
    expect(
      route(
        recovery: true,
        owner: true,
        registration: true,
        serverAccepted: true,
        locked: true,
      ),
      EntryRoute.recovery,
    );
  });

  test('a saved draft still exposes welcome and workspace connection', () {
    expect(route(draft: true, locked: true), EntryRoute.welcome);
    expect(route(draft: true), EntryRoute.welcome);
    expect(route(locked: true), EntryRoute.staffLogin);
    expect(route(), EntryRoute.welcome);
  });
}
