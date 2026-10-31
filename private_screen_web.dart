// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:typed_data';
import 'dart:js_util' as js_util;

/// Convertir un blob URL en bytes Uint8List
/// Le blob URL est retourné par record.stop() sur web
Future<Uint8List> readBlobUrl(String blobUrl) async {
  try {
    // 1. fetch(blobUrl) -> Promise<Response>
    final response = await js_util.promiseToFuture<dynamic>(
      js_util.callMethod(js_util.globalThis, 'fetch', [blobUrl]),
    );

    // 2. response.blob() -> Promise<Blob>
    final blob = await js_util.promiseToFuture<dynamic>(
      js_util.callMethod(response, 'blob', []),
    );

    // 3. blob.arrayBuffer() -> Promise<ArrayBuffer>
    final arrayBuffer = await js_util.promiseToFuture<dynamic>(
      js_util.callMethod(blob, 'arrayBuffer', []),
    );

    // 4. new Uint8Array(arrayBuffer)
    final uint8Array = js_util.callConstructor(
      js_util.getProperty(js_util.globalThis, 'Uint8Array'),
      [arrayBuffer],
    );

    // 5. Convertir le typed array JS en Uint8List Dart
    final length = js_util.getProperty(uint8Array, 'length') as int;
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = js_util.getProperty(uint8Array, i) as int;
    }

    return bytes;
  } catch (e) {
    print('❌ Erreur readBlobUrl: $e');
    return Uint8List(0);
  }
}
