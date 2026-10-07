import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_api.dart';
import 'backup_file_saver.dart';

const _kAzul = Color(0xFF1565C0);
const _kVerde = Color(0xFF2E7D32);
const _kRojo = Color(0xFFC62828);

/// Módulo Respaldo: descarga una copia (JSON) de los resultados de pruebas,
/// permite eliminarlos de Supabase (solo después de respaldar) y cargar un
/// respaldo JSON para recuperar la información.
class RespaldoPage extends StatefulWidget {
  const RespaldoPage({super.key});
  @override
  State<RespaldoPage> createState() => _RespaldoPageState();
}

class _RespaldoPageState extends State<RespaldoPage> {
  bool _trabajando = false;
  int? _total;
  String? _error;
  Map<String, dynamic>? _alm;

  /// Respaldos hechos en esta sesión (para habilitar la eliminación).
  final List<({String tipo, String ruta, int registros})> _hechos = [];

  bool get _permitido => AppApi.esAdmin || AppApi.permisos['respaldar_datos'] == true;
  bool get _respaldoListo => _hechos.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _contar();
  }

  Future<void> _contar() async {
    try {
      final p = await AppApi.resultadosPaginados(limite: 1);
      if (mounted) setState(() => _total = p.total);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
    try {
      final a = await AppApi.almacenamiento();
      if (mounted) setState(() => _alm = a);
    } catch (_) {}
  }

  String _tam(num bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2).replaceAll('.', ',')} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _miles(num n) {
    final s = n.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  Widget _almacenamiento() {
    final a = _alm;
    if (a == null) {
      return const Card(
        elevation: 0,
        margin: EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Consultando almacenamiento…'),
            ],
          ),
        ),
      );
    }
    final limite = (a['limite_bytes'] as num?)?.toDouble() ?? 1;
    final usado = (a['usado_bytes'] as num?)?.toDouble() ?? 0;
    final disponible = (a['disponible_bytes'] as num?)?.toDouble() ?? 0;
    final resBytes = (a['resultados_bytes'] as num?)?.toDouble() ?? 0;
    final porRegistro = (a['bytes_por_resultado'] as num?)?.toDouble() ?? 0;
    final pct = (usado / limite).clamp(0.0, 1.0);
    final color = pct < .7
        ? _kVerde
        : pct < .9
            ? const Color(0xFFEF6C00)
            : _kRojo;
    // Estimado: cada resultado ocupa ~3 veces su tamaño (índices y control).
    final caben = porRegistro > 0 ? disponible / (porRegistro * 3) : null;

    Widget fila(String t, String v, {Color? c}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(child: Text(t, style: TextStyle(color: Colors.blueGrey.shade700))),
              Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: c)),
            ],
          ),
        );

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFBBD0F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.storage_outlined, color: _kAzul),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Almacenamiento en Supabase',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kAzul.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Plan ${a['plan'] ?? ''}',
                    style: const TextStyle(color: _kAzul, fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _tam(disponible),
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('disponibles de ${_tam(limite)}',
                      style: TextStyle(color: Colors.blueGrey.shade600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct < .01 ? .01 : pct,
                minHeight: 12,
                backgroundColor: const Color(0xFFE3E8EE),
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(pct * 100).toStringAsFixed(1).replaceAll('.', ',')} % usado',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
            ),
            const SizedBox(height: 6),
            fila('Usado por toda la base de datos', _tam(usado)),
            fila('Ocupado por los resultados', _tam(resBytes)),
            if (caben != null)
              fila('Caben aprox. otros', '${_miles(caben)} resultados', c: _kVerde),
          ],
        ),
      ),
    );
  }

  String _sello() {
    final n = DateTime.now();
    String d(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${d(n.month)}${d(n.day)}_${d(n.hour)}${d(n.minute)}';
  }

  void _mensaje(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? _kRojo : null),
    );
  }

  // ─── Respaldo JSON ─────────────────────────────────────────────────────
  Future<void> _respaldoJson() async {
    await _ejecutar('JSON', (rows) async {
      final data = {
        'aplicacion': 'SELECCIOM - Cultivos La Planicie',
        'fecha_respaldo': DateTime.now().toIso8601String(),
        'tabla': 'resultados_pruebas',
        'registros': rows.length,
        'datos': rows,
      };
      final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
      return saveBackupBytes(bytes, 'respaldo_resultados_${_sello()}.json');
    });
  }

  Future<void> _ejecutar(
    String tipo,
    Future<String?> Function(List<Map<String, dynamic>> rows) guardar,
  ) async {
    if (!_permitido || _trabajando) return;
    setState(() => _trabajando = true);
    try {
      final rows = await AppApi.respaldoRegistros();
      if (rows.isEmpty) {
        _mensaje('No hay resultados para respaldar.');
        return;
      }
      final ruta = await guardar(rows);
      if (ruta == null) {
        _mensaje('Guardado cancelado.');
        return;
      }
      if (mounted) {
        setState(() => _hechos.insert(0, (tipo: tipo, ruta: ruta, registros: rows.length)));
      }
      _mensaje('Respaldo guardado (${rows.length} resultados).');
    } catch (e) {
      _mensaje('No se pudo respaldar: ${e.toString().replaceFirst('Exception: ', '')}', error: true);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  // ─── Cargar respaldo (recuperar) ───────────────────────────────────────
  Future<void> _cargarJson() async {
    if (!_permitido || _trabajando) return;
    FilePickerResult? pick;
    try {
      pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
    } catch (e) {
      _mensaje('No se pudo abrir el archivo: $e', error: true);
      return;
    }
    final archivo = pick?.files.single;
    if (archivo == null) return;
    final bytes = archivo.bytes;
    if (bytes == null) {
      _mensaje('No se pudo leer el archivo seleccionado.', error: true);
      return;
    }

    List<dynamic> datos;
    String? fechaRespaldo;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map && decoded['datos'] is List) {
        datos = decoded['datos'] as List;
        fechaRespaldo = decoded['fecha_respaldo']?.toString();
      } else if (decoded is List) {
        datos = decoded;
      } else {
        throw const FormatException();
      }
      if (datos.any((r) => r is! Map || r['id'] == null)) throw const FormatException();
    } catch (_) {
      _mensaje('El archivo no es un respaldo válido de SELECCIOM.', error: true);
      return;
    }
    if (datos.isEmpty) {
      _mensaje('El respaldo no tiene resultados.');
      return;
    }
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmarCarga(
        archivo: archivo.name,
        registros: datos.length,
        fecha: fechaRespaldo,
      ),
    );
    if (ok != true) return;

    setState(() => _trabajando = true);
    try {
      final r = await AppApi.restaurarRegistros(datos);
      final ins = (r['insertados'] as num?)?.toInt() ?? 0;
      final omi = (r['omitidos'] as num?)?.toInt() ?? 0;
      _mensaje(omi > 0
          ? 'Respaldo cargado: $ins resultados recuperados, $omi ya existían.'
          : 'Respaldo cargado: $ins resultados recuperados.');
      await _contar();
    } catch (e) {
      _mensaje('No se pudo cargar el respaldo: ${e.toString().replaceFirst('Exception: ', '')}',
          error: true);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  // ─── Eliminación ───────────────────────────────────────────────────────
  Future<void> _eliminar() async {
    if (!_respaldoListo || _trabajando) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmarEliminar(total: _total),
    );
    if (ok != true) return;
    setState(() => _trabajando = true);
    try {
      await AppApi.eliminarRegistros();
      _mensaje('Resultados eliminados. El respaldo quedó guardado.');
      await _contar();
    } catch (e) {
      _mensaje('No se pudo eliminar: ${e.toString().replaceFirst('Exception: ', '')}', error: true);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  // ─── UI ────────────────────────────────────────────────────────────────
  Widget _paso(
    int n,
    String titulo,
    String texto,
    Widget accion, {
    bool listo = false,
    bool bloqueado = false,
  }) =>
      Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: listo ? _kVerde.withValues(alpha: .5) : const Color(0xFFBBD0F0),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: listo
                        ? _kVerde
                        : bloqueado
                            ? Colors.grey.shade400
                            : _kAzul,
                    child: listo
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('$n',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(titulo,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(texto, style: TextStyle(color: Colors.blueGrey.shade700, height: 1.35)),
              const SizedBox(height: 12),
              accion,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_permitido) {
      return Scaffold(
        appBar: AppBar(title: const Text('Respaldo')),
        body: const Center(child: Text('Tu cuenta no tiene acceso al módulo de respaldo.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Respaldo y eliminación'),
        actions: [
          IconButton(onPressed: _contar, tooltip: 'Actualizar', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.white, size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resultados guardados en Supabase',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text(
                            _total == null ? (_error ?? 'Contando…') : '$_total resultados',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_trabajando)
                      const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      ),
                  ],
                ),
              ),
              _almacenamiento(),
              _paso(
                1,
                'Descargar respaldo',
                'Guarda una copia completa de todos los resultados (archivo JSON). '
                    'Tú eliges dónde guardarlo (Descargas, Drive, USB…).',
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  onPressed: _trabajando ? null : _respaldoJson,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Descargar respaldo'),
                ),
                listo: _respaldoListo,
              ),
              if (_hechos.isNotEmpty)
                Card(
                  elevation: 0,
                  color: _kVerde.withValues(alpha: .06),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      for (final h in _hechos)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.data_object, color: _kVerde),
                          title: Text('Respaldo · ${h.registros} resultados'),
                          subtitle: Text(h.ruta, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
              _paso(
                2,
                'Eliminar resultados',
                _respaldoListo
                    ? 'Ya tienes un respaldo. Puedes limpiar los resultados de Supabase; se pide confirmación.'
                    : 'Se habilita después de descargar un respaldo en esta sesión.',
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kRojo,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: _respaldoListo && !_trabajando && (_total ?? 0) > 0 ? _eliminar : null,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Eliminar resultados'),
                ),
                bloqueado: !_respaldoListo,
              ),
              _paso(
                3,
                'Cargar respaldo',
                'Recupera la información desde un archivo JSON descargado antes. '
                    'Solo se agregan los resultados que no existen; los que ya están no se duplican.',
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: _kAzul,
                    side: const BorderSide(color: _kAzul, width: 1.4),
                  ),
                  onPressed: _trabajando ? null : _cargarJson,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Cargar respaldo JSON'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmación escribiendo ELIMINAR.
class _ConfirmarEliminar extends StatefulWidget {
  final int? total;
  const _ConfirmarEliminar({required this.total});
  @override
  State<_ConfirmarEliminar> createState() => _ConfirmarEliminarState();
}

class _ConfirmarEliminarState extends State<_ConfirmarEliminar> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: _kRojo, size: 40),
        title: const Text('Eliminar resultados'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se eliminarán ${widget.total ?? 'todos los'} resultados de pruebas de Supabase. '
              'Ya guardaste un respaldo; esta acción no se puede deshacer.',
            ),
            const SizedBox(height: 14),
            const Text('Escribe ELIMINAR para confirmar:',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _texto,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(isDense: true, hintText: 'ELIMINAR'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kRojo),
            onPressed: _texto.text.trim().toUpperCase() == 'ELIMINAR'
                ? () => Navigator.pop(context, true)
                : null,
            child: const Text('Eliminar'),
          ),
        ],
      );
}

/// Confirmación antes de cargar un respaldo.
class _ConfirmarCarga extends StatelessWidget {
  final String archivo;
  final int registros;
  final String? fecha;
  const _ConfirmarCarga({required this.archivo, required this.registros, this.fecha});

  String? get _fechaTexto {
    final d = DateTime.tryParse(fecha ?? '');
    if (d == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    Widget fila(IconData i, String t, String v) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(i, size: 18, color: _kAzul),
              const SizedBox(width: 8),
              Text('$t: ', style: TextStyle(color: Colors.blueGrey.shade700)),
              Expanded(
                child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
    return AlertDialog(
      icon: const Icon(Icons.upload_file_outlined, color: _kAzul, size: 40),
      title: const Text('Cargar respaldo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fila(Icons.description_outlined, 'Archivo', archivo),
          if (_fechaTexto != null) fila(Icons.event_outlined, 'Fecha del respaldo', _fechaTexto!),
          fila(Icons.data_object, 'Resultados', '$registros'),
          const SizedBox(height: 14),
          Text(
            'Se agregarán a Supabase los resultados que no existan. '
            'Los que ya están guardados no se modifican ni se duplican.',
            style: TextStyle(color: Colors.blueGrey.shade700, height: 1.35),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.upload),
          label: const Text('Cargar'),
        ),
      ],
    );
  }
}
