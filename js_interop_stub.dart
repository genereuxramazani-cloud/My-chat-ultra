dynamic get globalThis =>
    throw UnsupportedError('JS interop is not supported on this platform');

T allowInterop<T>(T function) => function;

dynamic callMethod(dynamic object, String method, List<dynamic> args) {
  throw UnsupportedError(
      'JS interop callMethod is not supported on this platform');
}

dynamic getProperty(dynamic object, dynamic property) {
  throw UnsupportedError(
      'JS interop getProperty is not supported on this platform');
}

void setProperty(dynamic object, String property, dynamic value) {
  throw UnsupportedError(
      'JS interop setProperty is not supported on this platform');
}

dynamic callConstructor(dynamic constructor, List<dynamic> args) {
  throw UnsupportedError(
      'JS interop callConstructor is not supported on this platform');
}
