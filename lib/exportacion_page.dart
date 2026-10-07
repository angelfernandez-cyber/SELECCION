import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import 'app_api.dart';
import 'pdf_resultado.dart';

const _kAzul = Color(0xFF1565C0);
const _kVerde = Color(0xFF2E7D32);
const _kRojo = Color(0xFFC62828);

/// Módulo "Exportación e impresión PDF": busca resultados (por documento,
/// fecha y aprobado/desaprobado), y llena la plantilla de Pruebas de Selección
/// para uno o varios aspirantes a la vez.
class ExportacionPage extends StatefulWidget {
  const ExportacionPage({super.key});
  @override
  State<ExportacionPage> createState() => _ExportacionPageState();
}

class _ExportacionPageState extends State<ExportacionPage> {
  static const _tamPagina = 20;
  final _cedula = TextEditingController();
  Timer? _debounce;

  final List<Map<String, dynamic>> _rows = [];
  int _total = 0;
  int _aprobados = 0;
  int _desaprobados = 0;
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;
  int _consulta = 0;

  DateTimeRange? _rango;
  String? _resultado; // 'Aprobado' | 'Reprobado' | null

  /// Seleccionados: id → fila (se conservan aunque cambie el filtro).
  final Map<String, Map<String, dynamic>> _seleccion = {};
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    precargarPlantillaPdf();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cedula.dispose();
    super.dispose();
  }

  Future<PaginaResultados> _pedir(int offset) => AppApi.resultadosPaginados(
        desde: _rango?.start,
        hasta: _rango?.end,
        cedula: _cedula.text,
        resultado: _resultado,
        limite: _tamPagina,
        offset: offset,
      );

  Future<void> _cargar() async {
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pagina = await _pedir(0);
      if (!mounted || consulta != _consulta) return;
      _rows
        ..clear()
        ..addAll(pagina.filas);
      _total = pagina.total;
      _aprobados = pagina.aprobados;
      _desaprobados = pagina.desaprobados;
    } catch (e) {
      if (consulta != _consulta) return;
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted && consulta == _consulta) setState(() => _cargando = false);
  }

  Future<void> _cargarMas() async {
    if (_cargandoMas || _rows.length >= _total) return;
    final consulta = _consulta;
    setState(() => _cargandoMas = true);
    try {
      final pagina = await _pedir(_rows.length);
      if (consulta == _consulta) {
        _rows.addAll(pagina.filas);
        _total = pagina.total;
      }
    } catch (e) {
      _mensaje(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _cargandoMas = false);
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoy.year + 1, 12, 31),
      initialDateRange: _rango,
      helpText: 'Filtrar por fecha',
      saveText: 'Aplicar',
    );
    if (rango == null) return;
    setState(() => _rango = rango);
    _cargar();
  }

  void _filtrarResultado(String valor) {
    setState(() => _resultado = _resultado == valor ? null : valor);
    _cargar();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _textoResultado(String? r) => switch (r) {
        'Aprobado' => 'Aprobado',
        'Reprobado' => 'Desaprobado',
        _ => 'Sin calcular',
      };

  // ─── Selección múltiple ────────────────────────────────────────────────
  bool get _modoSeleccion => _seleccion.isNotEmpty;

  void _alternar(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    if (id == null) return;
    setState(() {
      if (_seleccion.containsKey(id)) {
        _seleccion.remove(id);
      } else {
        _seleccion[id] = row;
      }
    });
  }

  bool get _todosVisiblesSeleccionados =>
      _rows.isNotEmpty && _rows.every((r) => _seleccion.containsKey(r['id']?.toString()));

  void _seleccionarVisibles() {
    setState(() {
      if (_todosVisiblesSeleccionados) {
        for (final r in _rows) {
          _seleccion.remove(r['id']?.toString());
        }
      } else {
        for (final r in _rows) {
          final id = r['id']?.toString();
          if (id != null) _seleccion[id] = r;
        }
      }
    });
  }

  // ─── PDF ───────────────────────────────────────────────────────────────
  String _nombreArchivo(List<Map<String, dynamic>> filas) {
    if (filas.length == 1) {
      final row = filas.first;
      final cedula = (row['cedula'] ?? 'sin_cedula').toString();
      final nombre = '${row['nombre'] ?? ''}_${row['apellido'] ?? ''}'
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      return 'Pruebas_Seleccion_${cedula}_$nombre.pdf';
    }
    final hoy = DateTime.now();
    return 'Pruebas_Seleccion_${filas.length}_aspirantes_${hoy.year}${hoy.month.toString().padLeft(2, '0')}${hoy.day.toString().padLeft(2, '0')}.pdf';
  }

  Future<void> _pdf(List<Map<String, dynamic>> filas, {required bool descargar}) async {
    if (filas.isEmpty || _generando) return;
    setState(() => _generando = true);
    _mostrarProgreso(filas.length);
    var progresoAbierto = true;
    void cerrarProgreso() {
      if (progresoAbierto && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        progresoAbierto = false;
      }
    }

    try {
      // Se piden todos los resultados a la vez (no uno por uno).
      final ids = [
        for (final row in filas)
          if (row['id'] != null) row['id'].toString(),
      ];
      final datos = await Future.wait(ids.map(AppApi.resultadoPdf));
      final bytes = await generarPdfResultados(datos);
      final nombre = _nombreArchivo(filas);
      cerrarProgreso();
      if (descargar) {
        await Printing.sharePdf(bytes: bytes, filename: nombre);
      } else {
        await Printing.layoutPdf(name: nombre, onLayout: (_) async => bytes);
      }
    } catch (e) {
      cerrarProgreso();
      _mensaje('No se pudo generar el PDF: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      cerrarProgreso();
      if (mounted) setState(() => _generando = false);
    }
  }

  void _mostrarProgreso(int cantidad) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 18),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Generando PDF…',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        cantidad == 1 ? '1 aspirante' : '$cantidad aspirantes',
                        style: TextStyle(color: Colors.blueGrey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── UI ────────────────────────────────────────────────────────────────
  Widget _filtros() {
    final hayFiltros = _rango != null || _cedula.text.isNotEmpty || _resultado != null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cedula,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), _cargar);
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'N.º de documento',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    suffixIcon: _cedula.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _cedula.clear();
                              _cargar();
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Filtrar por fecha',
                onPressed: _elegirRango,
                icon: const Icon(Icons.date_range_outlined),
              ),
            ],
          ),
          if (_rango != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                avatar: const Icon(Icons.event_outlined, size: 18),
                label: Text('${_fmt(_rango!.start)} – ${_fmt(_rango!.end)}'),
                onDeleted: () {
                  setState(() => _rango = null);
                  _cargar();
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BotonFiltro(
                  texto: 'Aprobados ($_aprobados)',
                  icono: Icons.verified_outlined,
                  color: _kVerde,
                  activo: _resultado == 'Aprobado',
                  onTap: () => _filtrarResultado('Aprobado'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BotonFiltro(
                  texto: 'Desaprobados ($_desaprobados)',
                  icono: Icons.cancel_outlined,
                  color: _kRojo,
                  activo: _resultado == 'Reprobado',
                  onTap: () => _filtrarResultado('Reprobado'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                onPressed: _rows.isEmpty ? null : _seleccionarVisibles,
                icon: Icon(
                  _todosVisiblesSeleccionados ? Icons.deselect : Icons.select_all,
                  size: 18,
                ),
                label: Text(_todosVisiblesSeleccionados ? 'Quitar selección' : 'Seleccionar todos'),
              ),
              const Spacer(),
              if (hayFiltros)
                TextButton(
                  onPressed: () {
                    _cedula.clear();
                    setState(() {
                      _rango = null;
                      _resultado = null;
                    });
                    _cargar();
                  },
                  child: const Text('Quitar filtros'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final seleccionado = _seleccion.containsKey(id);
    final resultado = row['resultado']?.toString();
    final promedio = double.tryParse(row['promedio']?.toString() ?? '');
    final nombre = '${row['nombre'] ?? ''} ${row['apellido'] ?? ''}'.trim();
    final color = resultado == 'Aprobado'
        ? _kVerde
        : resultado == 'Reprobado'
            ? _kRojo
            : Colors.blueGrey;
    return Material(
      color: seleccionado ? const Color(0xFFE3ECFB) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: seleccionado ? _kAzul : const Color(0xFFE3E9F2),
          width: seleccionado ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _modoSeleccion ? () => _alternar(row) : null,
        onLongPress: () => _alternar(row),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(value: seleccionado, onChanged: (_) => _alternar(row)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre.isEmpty ? 'Sin nombre' : nombre,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'C.C. ${row['cedula'] ?? ''}',
                              style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if ((row['area'] ?? '').toString().isNotEmpty)
                                  _Info(Icons.place_outlined, row['area'].toString()),
                                if ((row['fecha'] ?? '').toString().isNotEmpty)
                                  _Info(Icons.event_outlined, row['fecha'].toString()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 92,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            resultado == 'Aprobado'
                                ? Icons.verified_outlined
                                : resultado == 'Reprobado'
                                    ? Icons.cancel_outlined
                                    : Icons.hourglass_empty,
                            color: color,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _textoResultado(resultado),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5),
                          ),
                          if (promedio != null)
                            Text(
                              promedio.toStringAsFixed(2).replaceAll('.', ','),
                              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (resultado == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 15, color: Colors.orange.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Sin niveles: ábrelo en Resultados y dale Guardar.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_modoSeleccion) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(40),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: _generando ? null : () => _pdf([row], descargar: true),
                            icon: const Icon(Icons.download_outlined, size: 18),
                            label: const Text('Descargar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(40),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: _generando ? null : () => _pdf([row], descargar: false),
                            icon: const Icon(Icons.print_outlined, size: 18),
                            label: const Text('Imprimir'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _barraSeleccion() {
    final filas = _seleccion.values.toList();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '${filas.length} seleccionado${filas.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(_seleccion.clear),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: _generando ? null : () => _pdf(filas, descargar: true),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Descargar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: _generando ? null : () => _pdf(filas, descargar: false),
                    icon: _generando
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print_outlined, size: 18),
                    label: Text(_generando ? 'Generando…' : 'Imprimir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('No hay resultados con estos filtros.'));
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: _rows.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 9),
        itemBuilder: (context, i) {
          if (i < _rows.length) return _tarjeta(_rows[i]);
          if (_rows.length >= _total) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  'Mostrando ${_rows.length} de $_total',
                  style: TextStyle(color: Colors.blueGrey.shade400),
                ),
              ),
            );
          }
          return Center(
            child: _cargandoMas
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                : TextButton.icon(
                    onPressed: _cargarMas,
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Cargar más'),
                  ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Exportación e impresión PDF'),
          actions: [
            IconButton(onPressed: _cargar, tooltip: 'Actualizar', icon: const Icon(Icons.refresh)),
          ],
        ),
        bottomNavigationBar: _modoSeleccion ? _barraSeleccion() : null,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                _filtros(),
                Expanded(child: _lista()),
              ],
            ),
          ),
        ),
      );
}

/// Botón de filtro Aprobados / Desaprobados.
class _BotonFiltro extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final bool activo;
  final VoidCallback onTap;
  const _BotonFiltro({
    required this.texto,
    required this.icono,
    required this.color,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: activo ? color : color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, size: 18, color: activo ? Colors.white : color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    texto,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: activo ? Colors.white : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Etiqueta pequeña con ícono (área, fecha).
class _Info extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Info(this.icono, this.texto);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: _kAzul),
            const SizedBox(width: 4),
            Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kAzul)),
          ],
        ),
      );
}
