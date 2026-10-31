import 'dart:typed_data';

/// Stub pour les plateformes non-web
/// readBlobUrl() n'existe que sur web
Future<Uint8List> readBlobUrl(String blobUrl) async {
  throw UnsupportedError('readBlobUrl is only supported on web');
}
