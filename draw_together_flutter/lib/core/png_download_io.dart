import 'dart:io';
import 'dart:typed_data';

/// Writes the PNG next to the system temp directory and returns where it went,
/// which is as much as can be done without a file-picker dependency.
Future<String> downloadPng(Uint8List bytes, String fileName) async {
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
