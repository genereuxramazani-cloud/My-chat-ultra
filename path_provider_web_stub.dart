// Stub for path_provider on web platform
// This file exists only to satisfy dart2js type checking on web
// The actual code will never call this on web (protected by if (!kIsWeb) checks)

Future getTemporaryDirectory() async {
  throw UnsupportedError('getTemporaryDirectory is not available on web');
}
