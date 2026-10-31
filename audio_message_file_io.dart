import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readFileBytes(String path) async {
  return await File(path).readAsBytes();
}

Future<bool> deleteFileIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
    return true;
  }
  return false;
}
