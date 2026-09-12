// Resolves the running environment without importing `dart:io` into web
// builds (conditional import picks the IO implementation only where dart:io
// exists).
export 'runtime_environment_stub.dart'
    if (dart.library.io) 'runtime_environment_io.dart';
