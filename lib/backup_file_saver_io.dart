import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Pide al usuario dónde guardar el archivo y lo guarda.
/// Devuelve la ubicación elegida, o null si canceló.
Future<String?> saveBackupBytes(List<int> bytes, String fileName) async {
  final data = Uint8List.fromList(bytes);
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar respaldo',
    fileName: fileName,
    bytes: data,
  );
  if (path == null) return null;
  // En escritorio el selector solo devuelve la ruta: escribimos el archivo.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await File(path).writeAsBytes(data, flush: true);
  }
  return path;
}
