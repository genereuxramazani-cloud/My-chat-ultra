dynamic get globalThis =>
    throw UnsupportedError('JS interop not supported on this platform');

T allowInterop<T>(T function) => function;

dynamic callMethod(dynamic object, String method, List<dynamic> args) {
  throw UnsupportedError(
      'JS interop callMethod is not supported on this platform');
}
