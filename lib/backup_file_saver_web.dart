// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// Descarga el archivo en el navegador. Devuelve el nombre del archivo.
Future<String?> saveBackupBytes(List<int> bytes, String fileName) async {
  final blob = html.Blob(<dynamic>[Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return 'Descargas del navegador / $fileName';
}
