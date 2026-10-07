import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_api.dart';

// ─── Colores corporativos ───────────────────────────────────────────────────
const _kBlue = Color(0xFF1565C0);
const _kGreen = Color(0xFF2E7D32);
const _kOrange = Color(0xFFEF6C00);
const _kBlueBg = Color(0xFFE3ECFB);

// ─── Áreas disponibles ──────────────────────────────────────────────────────
const _kAreas = [
  'Poscosecha',
  'Producción',
  'Hidroponía',
];

// ─── Pruebas: orden, nombre e ícono ─────────────────────────────────────────
const _kOrdenPruebas = [
  'pin_board',
  'destreza_fina',
  'speed_stack',
  'fit_brain',
  'habilidad_motora_gruesa',
  'prueba_campo',
  'concentracion_conteo',
];

const _kNombrePrueba = {
  'pin_board': 'Pin Board',
  'destreza_fina': 'Destreza Fina',
  'speed_stack': 'Speed Stack',
  'fit_brain': 'Fit Brain',
  'habilidad_motora_gruesa': 'Habilidad Motora Gruesa',
  'prueba_campo': 'Prueba de Campo',
  'concentracion_conteo': 'Concentración y Conteo',
};

const _kIconoPrueba = {
  'pin_board': Icons.grid_on_outlined,
  'destreza_fina': Icons.back_hand_outlined,
  'speed_stack': Icons.speed_outlined,
  'fit_brain': Icons.psychology_outlined,
  'habilidad_motora_gruesa': Icons.directions_run_outlined,
  'prueba_campo': Icons.grass_outlined,
  'concentracion_conteo': Icons.calculate_outlined,
};

/// Pruebas fijas + grupo de pruebas alternativas (se aplica UNA de ellas).
class _ReglaPruebas {
  final List<String> fijas;
  final List<String> alternativas;
  const _ReglaPruebas(this.fijas, this.alternativas);
}

/// Reglas del Área de Selección:
/// * Poscosecha: Destreza Fina, Speed Stack o Fit Brain, Concentración y
///   Conteo, Prueba de Campo. Hombre: + Habilidad Motora Gruesa.
/// * Producción (cultivo): Pin Board, Destreza Fina, Speed Stack o Fit Brain o
///   Concentración y Conteo, Prueba de Campo. Hombre: + Habilidad Motora Gruesa.
/// * Hidroponía (solo hombres): Pin Board, Speed Stack o Fit Brain o
///   Concentración y Conteo, Habilidad Motora Gruesa, Prueba de Campo.
/// Mujer: siempre 4 pruebas. Hombre: 5 (4 en Hidroponía).
_ReglaPruebas? _reglasPruebas(String area, String genero) {
  final hombre = genero == 'Hombre';
  switch (area) {
    case 'Poscosecha':
      return _ReglaPruebas([
        'destreza_fina',
        'concentracion_conteo',
        'prueba_campo',
        if (hombre) 'habilidad_motora_gruesa',
      ], const ['speed_stack', 'fit_brain']);
    case 'Producción':
      return _ReglaPruebas([
        'pin_board',
        'destreza_fina',
        'prueba_campo',
        if (hombre) 'habilidad_motora_gruesa',
      ], const ['speed_stack', 'fit_brain', 'concentracion_conteo']);
    case 'Hidroponía':
      if (!hombre) return null;
      return const _ReglaPruebas([
        'pin_board',
        'habilidad_motora_gruesa',
        'prueba_campo',
      ], ['speed_stack', 'fit_brain', 'concentracion_conteo']);
  }
  return null;
}

// ─── Competencias a evaluar por prueba ──────────────────────────────────────
const _kCompetencias = [
  'Seguimiento de instrucciones',
  'Comunicación Efectiva',
  'Atención al detalle',
  'Flexibilidad',
  'Orientación al logro',
  'Tolerancia a la presión',
];

// ─── Formateador de tiempo mm:ss ───────────────────────────────────────────
class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final capped =
        digits.length > 4 ? digits.substring(digits.length - 4) : digits;
    final padded = capped.padLeft(4, '0');
    final mm = padded.substring(0, 2);
    final ss = padded.substring(2, 4);
    final formatted = '$mm:$ss';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

double? _parseTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (clean.isEmpty) return null;
  final padded = clean.padLeft(4, '0');
  final digits = padded.length > 4 ? padded.substring(0, 4) : padded;
  final mm = int.tryParse(digits.substring(0, 2)) ?? 0;
  final ss = int.tryParse(digits.substring(2, 4)) ?? 0;
  return (mm * 60 + ss).toDouble();
}

/// Texto con coma o punto → número.
double? _decimal(String? t) {
  final v = (t ?? '').trim().replaceAll(',', '.');
  return v.isEmpty ? null : double.tryParse(v);
}

/// Prueba de campo: minutos con decimales (ej. "12,5") → segundos.
double? _minutosASegundos(String? t) {
  final m = _decimal(t);
  return m == null ? null : m * 60;
}

/// Segundos → minutos con decimales para mostrar (ej. 750 → "12,5").
String _segundosAMinutos(double? s) {
  if (s == null) return '';
  final m = s / 60;
  var txt = m.toStringAsFixed(2);
  txt = txt.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return txt.replaceAll('.', ',');
}

String _formatTime(double? seconds) {
  if (seconds == null) return '';
  final totalSec = seconds.round();
  final mm = (totalSec ~/ 60).toString().padLeft(2, '0');
  final ss = (totalSec % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Estado de diligenciamiento de un registro
// ─────────────────────────────────────────────────────────────────────────────
const _kVerdeClaro = Color(0xFFE8F5E9);
const _kNaranjaClaro = Color(0xFFFFF3E0);
const _kRojo = Color(0xFFD32F2F);

bool _tieneValor(dynamic v) => (v?.toString() ?? '').trim().isNotEmpty;

/// Cuántas pruebas alternativas se pueden elegir: dos solo en Hidroponía,
/// una en las demás áreas.
int _maxAlternativas(String? area) => area == 'Hidroponía' ? 2 : 1;

/// Deduce qué pruebas alternativas se aplicaron según los datos guardados
/// (pueden ser hasta dos).
Set<String> _alternativasDe(Map<String, dynamic> r) {
  bool tiene(List<String> campos) => campos.any((c) => _tieneValor(r[c]));
  return {
    if (tiene(['speed_stack_destreza_t1', 'speed_stack_destreza_t2'])) 'speed_stack',
    if (tiene(['fit_brain_velocidad_t1', 'fit_brain_velocidad_t2'])) 'fit_brain',
    if (tiene(['concentracion_conteo_destreza_t1']) &&
        r['area']?.toString() != 'Poscosecha')
      'concentracion_conteo',
  };
}

/// Campos obligatorios de cada prueba (nombre visible → columna).
const _kCamposPrueba = <String, Map<String, String>>{
  'pin_board': {
    'Destreza T1': 'pin_board_destreza_t1',
    'Destreza T2': 'pin_board_destreza_t2',
    'Calidad T1': 'pin_board_calidad_t1',
    'Calidad T2': 'pin_board_calidad_t2',
  },
  'destreza_fina': {
    'Destreza T1': 'destreza_fina_destreza_t1',
    'Destreza T2': 'destreza_fina_destreza_t2',
    'Calidad T1': 'destreza_fina_calidad_t1',
    'Calidad T2': 'destreza_fina_calidad_t2',
  },
  'speed_stack': {
    'Destreza T1': 'speed_stack_destreza_t1',
    'Destreza T2': 'speed_stack_destreza_t2',
    'Calidad T1': 'speed_stack_calidad_t1',
    'Calidad T2': 'speed_stack_calidad_t2',
  },
  'fit_brain': {
    'Velocidad T1': 'fit_brain_velocidad_t1',
    'Velocidad T2': 'fit_brain_velocidad_t2',
    '% Acierto T1': 'fit_brain_porcentaje_acierto_t1',
    '% Acierto T2': 'fit_brain_porcentaje_acierto_t2',
  },
  'habilidad_motora_gruesa': {
    'Destreza': 'habilidad_motora_gruesa_destreza_t1',
    'Calidad': 'habilidad_motora_gruesa_calidad_t1',
  },
  'prueba_campo': {
    'Destreza': 'prueba_campo_destreza_t1',
    'Calidad': 'prueba_campo_calidad_t1',
  },
  'concentracion_conteo': {
    'Destreza': 'concentracion_conteo_destreza_t1',
    'Calidad': 'concentracion_conteo_calidad_t1',
    'Suma': 'suma',
    'Resta': 'resta',
    'Multiplicación': 'multiplicacion',
    'División': 'division',
  },
};

class _EstadoRegistro {
  final bool campoCompleto;
  final List<String> faltantes;
  const _EstadoRegistro(this.campoCompleto, this.faltantes);
  bool get completo => faltantes.isEmpty;
}

_EstadoRegistro _estadoRegistro(Map<String, dynamic> r) {
  final faltantes = <String>[];
  const identificacion = {
    'Nombre': 'nombre',
    'Apellido': 'apellido',
    'Cédula': 'cedula',
    'Área': 'area',
    'Género': 'genero',
  };
  identificacion.forEach((label, col) {
    if (!_tieneValor(r[col])) faltantes.add(label);
  });

  final area = r['area']?.toString() ?? '';
  final genero = r['genero']?.toString() ?? '';
  final regla = _reglasPruebas(area, genero);
  final pruebas = <String>[];
  if (regla != null) {
    pruebas.addAll(regla.fijas);
    final alts = _alternativasDe(r).where(regla.alternativas.contains).toList();
    if (alts.isNotEmpty) {
      pruebas.addAll(alts);
    } else {
      faltantes.add(
        'Prueba a aplicar (${regla.alternativas.map((k) => _kNombrePrueba[k]).join(' / ')})',
      );
    }
  } else if (_tieneValor(area) && _tieneValor(genero)) {
    faltantes.add('Combinación de área y género no válida');
  }

  final competencias = r['competencias'];
  for (final k in _kOrdenPruebas) {
    if (!pruebas.contains(k)) continue;
    final nombre = _kNombrePrueba[k]!;
    _kCamposPrueba[k]!.forEach((label, col) {
      if (!_tieneValor(r[col])) faltantes.add('$nombre: $label');
    });
    final comp = competencias is Map ? competencias[k] : null;
    final calificadas = comp is Map
        ? _kCompetencias.where((c) => _tieneValor(comp[c])).length
        : 0;
    if (calificadas < _kCompetencias.length) {
      faltantes.add(
        '$nombre: competencias (${_kCompetencias.length - calificadas} sin calificar)',
      );
    }
  }

  final campoCompleto = _tieneValor(r['prueba_campo_destreza_t1']) &&
      _tieneValor(r['prueba_campo_calidad_t1']);
  return _EstadoRegistro(campoCompleto, faltantes);
}

// ─────────────────────────────────────────────────────────────────────────────
//  DatosPage – historial de resultados (filtros + paginación)
// ─────────────────────────────────────────────────────────────────────────────
class DatosPage extends StatefulWidget {
  const DatosPage({super.key});
  @override
  State<DatosPage> createState() => _DatosPageState();
}

class _DatosPageState extends State<DatosPage> {
  static const _tamPagina = 20;

  final _scroll = ScrollController();
  final _cedulaCtrl = TextEditingController();
  Timer? _debounce;

  final List<Map<String, dynamic>> _rows = [];
  int _total = 0;
  int _completos = 0;
  int _pendientes = 0;
  bool _loading = true;
  bool _cargandoMas = false;
  String? _error;
  int _consulta = 0; // evita mezclar respuestas de filtros viejos

  DateTimeRange? _rango;
  String? _estadoCampo; // 'completo' | 'pendiente' | null

  bool get _canAdd =>
      AppApi.esAdmin || AppApi.permisos['registrar_datos'] == true;
  bool get _canEdit =>
      AppApi.esAdmin || AppApi.permisos['editar_datos'] == true;
  bool get _hayMas => _rows.length < _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        _cargarMas();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _cedulaCtrl.dispose();
    super.dispose();
  }

  Future<PaginaResultados> _pedir(int offset) => AppApi.resultadosPaginados(
        desde: _rango?.start,
        hasta: _rango?.end,
        cedula: _cedulaCtrl.text,
        estadoCampo: _estadoCampo,
        limite: _tamPagina,
        offset: offset,
      );

  /// Recarga desde la primera página (al abrir, filtrar o refrescar).
  Future<void> _load() async {
    final consulta = ++_consulta;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pagina = await _pedir(0);
      if (!mounted || consulta != _consulta) return;
      _rows
        ..clear()
        ..addAll(pagina.filas);
      _total = pagina.total;
      _completos = pagina.completos;
      _pendientes = pagina.pendientes;
    } catch (e) {
      if (consulta != _consulta) return;
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted && consulta == _consulta) setState(() => _loading = false);
  }

  /// Trae la siguiente página al llegar al final de la lista.
  Future<void> _cargarMas() async {
    if (_loading || _cargandoMas || !_hayMas) return;
    final consulta = _consulta;
    setState(() => _cargandoMas = true);
    try {
      final pagina = await _pedir(_rows.length);
      if (!mounted || consulta != _consulta) return;
      _rows.addAll(pagina.filas);
      _total = pagina.total;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
    if (mounted) setState(() => _cargandoMas = false);
  }

  void _onCedulaChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _load);
    setState(() {}); // muestra/oculta el botón de limpiar
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
    _load();
  }

  void _toggleEstado(String estado) {
    setState(() => _estadoCampo = _estadoCampo == estado ? null : estado);
    _load();
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ResultadoFormPage(record: row)),
    );
    if (ok == true) _load();
  }

  void _verFaltantes(Map<String, dynamic> row, _EstadoRegistro estado) {
    showDialog<void>(
      context: context,
      builder: (context) => _DialogoFaltantes(
        nombre: '${row['nombre'] ?? ''} ${row['apellido'] ?? ''}'.trim(),
        cedula: row['cedula']?.toString() ?? '',
        estado: estado,
        puedeEditar: _canEdit,
        onCompletar: () {
          Navigator.pop(context);
          _edit(row);
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _filtros() {
    final hayFiltros =
        _rango != null || _cedulaCtrl.text.isNotEmpty || _estadoCampo != null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _cedulaCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onCedulaChanged,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'N.º de documento',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    suffixIcon: _cedulaCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _cedulaCtrl.clear();
                              _load();
                            },
                          ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _elegirRango,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _rango == null
                      ? 'Filtrar por fecha'
                      : '${_fmt(_rango!.start)} – ${_fmt(_rango!.end)}',
                ),
              ),
              if (_rango != null)
                IconButton(
                  tooltip: 'Quitar filtro de fecha',
                  onPressed: () {
                    setState(() => _rango = null);
                    _load();
                  },
                  icon: const Icon(Icons.event_busy_outlined),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _EstadoBoton(
                  label: 'Completo',
                  cantidad: _completos,
                  icon: Icons.check_circle_outline,
                  color: _kGreen,
                  fondo: _kVerdeClaro,
                  activo: _estadoCampo == 'completo',
                  onTap: () => _toggleEstado('completo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EstadoBoton(
                  label: 'Campo',
                  cantidad: _pendientes,
                  icon: Icons.grass_outlined,
                  color: _kOrange,
                  fondo: _kNaranjaClaro,
                  activo: _estadoCampo == 'pendiente',
                  onTap: () => _toggleEstado('pendiente'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _loading ? 'Buscando…' : 'Mostrando ${_rows.length} de $_total',
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12.5),
              ),
              const Spacer(),
              if (hayFiltros)
                TextButton(
                  onPressed: () {
                    _cedulaCtrl.clear();
                    setState(() {
                      _rango = null;
                      _estadoCampo = null;
                    });
                    _load();
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
    final estado = _estadoRegistro(row);
    final nombre = '${row['nombre'] ?? ''} ${row['apellido'] ?? ''}'.trim();
    final acento = estado.campoCompleto ? _kGreen : _kOrange;
    final resultado = row['resultado']?.toString();
    final promedio = double.tryParse(row['promedio']?.toString() ?? '');
    final colorRes = resultado == 'Aprobado'
        ? _kGreen
        : resultado == 'Reprobado'
            ? _kRojo
            : Colors.blueGrey;
    return Material(
      color: estado.campoCompleto ? _kVerdeClaro : _kNaranjaClaro,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _verFaltantes(row, estado),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: acento, width: 5)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        child: Text(
                          _inicialesNombre(nombre),
                          style: TextStyle(color: acento, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Tooltip(
                          message: estado.completo
                              ? 'Todo diligenciado'
                              : '${estado.faltantes.length} campo(s) por diligenciar',
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: estado.completo ? _kGreen : _kRojo,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                      ],
                    ),
                  ),
                  if (resultado != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colorRes.withValues(alpha: .5)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            resultado == 'Aprobado' ? 'Aprobado' : 'Desaprobado',
                            style: TextStyle(
                              color: colorRes,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                          if (promedio != null)
                            Text(
                              promedio.toStringAsFixed(2).replaceAll('.', ','),
                              style: TextStyle(color: colorRes, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if ((row['area'] ?? '').toString().isNotEmpty)
                    _ChipInfo(Icons.place_outlined, row['area'].toString(), _kBlue),
                  if ((row['fecha'] ?? '').toString().isNotEmpty)
                    _ChipInfo(Icons.event_outlined, row['fecha'].toString(), _kBlue),
                  if ((row['genero'] ?? '').toString().isNotEmpty)
                    _ChipInfo(Icons.wc_outlined, row['genero'].toString(), _kBlue),
                  _ChipInfo(
                    Icons.grass_outlined,
                    estado.campoCompleto ? 'Campo diligenciado' : 'Campo pendiente',
                    acento,
                  ),
                  _ChipInfo(
                    estado.completo ? Icons.check_circle_outline : Icons.error_outline,
                    estado.completo ? 'Completo' : 'Faltan ${estado.faltantes.length}',
                    estado.completo ? _kGreen : _kRojo,
                  ),
                ],
              ),
              if (_canEdit)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _edit(row),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                )
              else
                const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No hay resultados con estos filtros.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
        itemCount: _rows.length + 1,
        separatorBuilder: (_, _i) => const SizedBox(height: 9),
        itemBuilder: (context, i) {
          if (i < _rows.length) return _tarjeta(_rows[i]);
          if (_cargandoMas) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_hayMas) {
            return Center(
              child: TextButton.icon(
                onPressed: _cargarMas,
                icon: const Icon(Icons.expand_more),
                label: const Text('Cargar más'),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text(
                'Fin del historial',
                style: TextStyle(color: Colors.blueGrey.shade400),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Resultados de Pruebas'),
          actions: [
            IconButton(
              onPressed: _load,
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: _canAdd
            ? FloatingActionButton.extended(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo Registro'),
              )
            : null,
        body: Column(
          children: [
            _filtros(),
            if (_loading && _rows.isNotEmpty) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _cuerpo()),
          ],
        ),
      );
}

/// Botón de filtro por estado de la Prueba de Campo.
class _EstadoBoton extends StatelessWidget {
  final String label;
  final int cantidad;
  final IconData icon;
  final Color color;
  final Color fondo;
  final bool activo;
  final VoidCallback onTap;
  const _EstadoBoton({
    required this.label,
    required this.cantidad,
    required this.icon,
    required this.color,
    required this.fondo,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: activo ? color : fondo,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: activo ? Colors.white : color),
                const SizedBox(width: 8),
                Text(
                  '$label ($cantidad)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: activo ? Colors.white : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pantalla completa del formulario
// ─────────────────────────────────────────────────────────────────────────────
class ResultadoFormPage extends StatefulWidget {
  final Map<String, dynamic>? record;
  const ResultadoFormPage({super.key, this.record});
  @override
  State<ResultadoFormPage> createState() => _ResultadoFormPageState();
}

class _ResultadoFormPageState extends State<ResultadoFormPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Identificación ──
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _cedula = TextEditingController();
  String? _area;
  String? _genero;
  /// Pruebas alternativas elegidas (hasta dos).
  final Set<String> _alternativas = {};
  late final String _fecha;
  late final String _formador;
  late final String _liderPrueba;
  final String _proceso = 'Selección';

  // ── Pin Board — Destreza (tiempo) ──
  final _pbDestrezaT1 = TextEditingController();
  final _pbDestrezaT2 = TextEditingController();
  // ── Pin Board — Calidad (toggle: null / ok / 1) ──
  String? _pbCalidadT1;
  String? _pbCalidadT2;

  // ── Destreza Fina — Destreza (tiempo) ──
  final _dfDestrezaT1 = TextEditingController();
  final _dfDestrezaT2 = TextEditingController();
  // ── Destreza Fina — Calidad (toggle: null / ok / 1) ──
  String? _dfCalidadT1;
  String? _dfCalidadT2;

  // ── Speed Stack — Destreza (tiempo) ──
  final _ssDestrezaT1 = TextEditingController();
  final _ssDestrezaT2 = TextEditingController();
  // ── Speed Stack — Calidad (toggle: null / ok / 1) ──
  String? _ssCalidadT1;
  String? _ssCalidadT2;

  // ── Fit Brain — Velocidad (tiempo) y % Acierto (número) ──
  final _fbVelocidadT1 = TextEditingController();
  final _fbVelocidadT2 = TextEditingController();
  final _fbPorcentajeT1 = TextEditingController();
  final _fbPorcentajeT2 = TextEditingController();

  // ── Habilidad Motora Gruesa ──
  final _hmgDestrezaT1 = TextEditingController();
  String? _hmgCalidadT1;

  // ── Prueba de Campo ──
  final _pcDestrezaT1 = TextEditingController();
  String? _pcCalidadT1;

  // ── Concentración y Conteo ──
  final _ccDestrezaT1 = TextEditingController();
  String? _ccCalidadT1;

  // ── Operaciones Matemáticas (cumple/no cumple) ──
  bool? _sumaOk;
  bool? _restaOk;
  bool? _multOk;
  bool? _divOk;

  // ── Competencias evaluadas en cada prueba ──
  final Map<String, Map<String, int?>> _competencias = {
    'pin_board': {},
    'destreza_fina': {},
    'speed_stack': {},
    'fit_brain': {},
    'habilidad_motora_gruesa': {},
    'prueba_campo': {},
    'concentracion_conteo': {},
  };

  bool _saving = false;

  // ── Helpers ──
  double? _toDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  bool? _toBool(dynamic v) {
    if (v == null) return null;
    final d = double.tryParse(v.toString());
    if (d == null) return null;
    return d >= 1.0;
  }

  String? _parseCalidad(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    if (lower == 'ok' || lower == 'true') return 'ok';
    if (lower == '1' || lower == '1.0') return '1';
    return lower;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fecha =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final nombreUsuario =
        (AppApi.usuario?['nombre'] as String? ?? '').trim();
    _formador = nombreUsuario;
    _liderPrueba = nombreUsuario;

    final r = widget.record;
    if (r != null) {
      _nombre.text = r['nombre']?.toString() ?? '';
      _apellido.text = r['apellido']?.toString() ?? '';
      _cedula.text = r['cedula']?.toString() ?? '';
      _area = r['area']?.toString();
      final genero = r['genero']?.toString();
      _genero = genero == 'Hombre' || genero == 'Mujer' ? genero : null;
      _alternativas.addAll(_alternativasDe(r));

      _pbDestrezaT1.text = _formatTime(_toDouble(r['pin_board_destreza_t1']));
      _pbDestrezaT2.text = _formatTime(_toDouble(r['pin_board_destreza_t2']));
      _pbCalidadT1 = _parseCalidad(r['pin_board_calidad_t1']);
      _pbCalidadT2 = _parseCalidad(r['pin_board_calidad_t2']);

      _dfDestrezaT1.text =
          _formatTime(_toDouble(r['destreza_fina_destreza_t1']));
      _dfDestrezaT2.text =
          _formatTime(_toDouble(r['destreza_fina_destreza_t2']));
      _dfCalidadT1 = _parseCalidad(r['destreza_fina_calidad_t1']);
      _dfCalidadT2 = _parseCalidad(r['destreza_fina_calidad_t2']);

      _ssDestrezaT1.text =
          _formatTime(_toDouble(r['speed_stack_destreza_t1']));
      _ssDestrezaT2.text =
          _formatTime(_toDouble(r['speed_stack_destreza_t2']));
      _ssCalidadT1 = _parseCalidad(r['speed_stack_calidad_t1']);
      _ssCalidadT2 = _parseCalidad(r['speed_stack_calidad_t2']);

      _fbVelocidadT1.text =
          r['fit_brain_velocidad_t1']?.toString() ?? '';
      _fbVelocidadT2.text =
          r['fit_brain_velocidad_t2']?.toString() ?? '';
      _fbPorcentajeT1.text =
          r['fit_brain_porcentaje_acierto_t1']?.toString() ?? '';
      _fbPorcentajeT2.text =
          r['fit_brain_porcentaje_acierto_t2']?.toString() ?? '';

      _hmgDestrezaT1.text =
          _formatTime(_toDouble(r['habilidad_motora_gruesa_destreza_t1']));
      _hmgCalidadT1 = _parseCalidad(r['habilidad_motora_gruesa_calidad_t1']);

      _pcDestrezaT1.text = _segundosAMinutos(_toDouble(r['prueba_campo_destreza_t1']));
      _pcCalidadT1 = _parseCalidad(r['prueba_campo_calidad_t1']);

      _ccDestrezaT1.text =
          _formatTime(_toDouble(r['concentracion_conteo_destreza_t1']));
      _ccCalidadT1 = _parseCalidad(r['concentracion_conteo_calidad_t1']);

      _sumaOk = _toBool(r['suma']);
      _restaOk = _toBool(r['resta']);
      _multOk = _toBool(r['multiplicacion']);
      _divOk = _toBool(r['division']);

      final rawComp = r['competencias'];
      if (rawComp is Map) {
        rawComp.forEach((pKey, pVal) {
          if (pVal is Map) {
            _competencias[pKey.toString()] = {};
            pVal.forEach((cKey, cVal) {
              _competencias[pKey.toString()]![cKey.toString()] =
                  int.tryParse(cVal.toString());
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _cedula.dispose();
    _pbDestrezaT1.dispose();
    _pbDestrezaT2.dispose();
    _dfDestrezaT1.dispose();
    _dfDestrezaT2.dispose();
    _ssDestrezaT1.dispose();
    _ssDestrezaT2.dispose();
    _fbVelocidadT1.dispose();
    _fbVelocidadT2.dispose();
    _fbPorcentajeT1.dispose();
    _fbPorcentajeT2.dispose();
    _hmgDestrezaT1.dispose();
    _pcDestrezaT1.dispose();
    _ccDestrezaT1.dispose();
    super.dispose();
  }

  double? _boolToNum(bool? v) {
    if (v == null) return null;
    return v ? 1.0 : 0.0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_aplicaReglas && _alternativas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige la prueba a aplicar (Speed Stack, Fit Brain…).'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    // Solo se guardan las pruebas que aplican para el área y el género.
    final v = _pruebasVisibles;
    T? si<T>(String prueba, T? valor) => v.contains(prueba) ? valor : null;
    final competencias = <String, Map<String, int?>>{
      for (final e in _competencias.entries)
        if (v.contains(e.key)) e.key: e.value,
    };
    try {
      final id = await AppApi.guardarResultado(
        genero: _genero,
        id: widget.record?['id']?.toString(),
        fecha: _fecha,
        nombre: _nombre.text.trim(),
        apellido: _apellido.text.trim(),
        cedula: _cedula.text.trim(),
        area: _area,
        formador: _formador,
        proceso: _proceso,
        liderPrueba: _liderPrueba,
        pinBoardDestrezaT1: si('pin_board', _parseTime(_pbDestrezaT1.text)),
        pinBoardDestrezaT2: si('pin_board', _parseTime(_pbDestrezaT2.text)),
        pinBoardCalidadT1: si('pin_board', _pbCalidadT1),
        pinBoardCalidadT2: si('pin_board', _pbCalidadT2),
        destrezaFinaDestrezaT1: si('destreza_fina', _parseTime(_dfDestrezaT1.text)),
        destrezaFinaDestrezaT2: si('destreza_fina', _parseTime(_dfDestrezaT2.text)),
        destrezaFinaCalidadT1: si('destreza_fina', _dfCalidadT1),
        destrezaFinaCalidadT2: si('destreza_fina', _dfCalidadT2),
        speedStackDestrezaT1: si('speed_stack', _parseTime(_ssDestrezaT1.text)),
        speedStackDestrezaT2: si('speed_stack', _parseTime(_ssDestrezaT2.text)),
        speedStackCalidadT1: si('speed_stack', _ssCalidadT1),
        speedStackCalidadT2: si('speed_stack', _ssCalidadT2),
        fitBrainVelocidadT1: si('fit_brain', _decimal(_fbVelocidadT1.text)),
        fitBrainVelocidadT2: si('fit_brain', _decimal(_fbVelocidadT2.text)),
        fitBrainPorcentajeT1: si('fit_brain', _decimal(_fbPorcentajeT1.text)),
        fitBrainPorcentajeT2: si('fit_brain', _decimal(_fbPorcentajeT2.text)),
        habilidadMgrDestrezaT1: si('habilidad_motora_gruesa', _parseTime(_hmgDestrezaT1.text)),
        habilidadMgrCalidadT1: si('habilidad_motora_gruesa', _hmgCalidadT1),
        pruebaCampoDestrezaT1: si('prueba_campo', _minutosASegundos(_pcDestrezaT1.text)),
        pruebaCampoCalidadT1: si('prueba_campo', _pcCalidadT1),
        concentracionDestrezaT1: si('concentracion_conteo', _parseTime(_ccDestrezaT1.text)),
        concentracionCalidadT1: si('concentracion_conteo', _ccCalidadT1),
        suma: si('concentracion_conteo', _boolToNum(_sumaOk)),
        resta: si('concentracion_conteo', _boolToNum(_restaOk)),
        multiplicacion: si('concentracion_conteo', _boolToNum(_multOk)),
        division: si('concentracion_conteo', _boolToNum(_divOk)),
        competencias: competencias,
      );
      // Guarda también lo que muestra la pestaña Proceso (para el PDF).
      if (id != null) {
        final resumen = _resumenNiveles(
          _resultadosProceso(),
          operacionesFallidas: _operacionesFallidas,
        );
        await AppApi.guardarNiveles(
          id: id,
          niveles: resumen.json,
          promedio: resumen.promedio,
          resultado: resumen.resultado,
          pruebaCampoTipo: _pruebaCampoDeArea(_area),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  // ── Secciones plegables ──
  final Set<String> _colapsadas = {};

  List<Widget> _seccion(
    String key,
    IconData icon,
    String title,
    List<Widget> body, {
    String? nota,
  }) {
    final abierta = !_colapsadas.contains(key);
    return [
      _SectionHeader(
        icon: icon,
        title: title,
        nota: nota,
        expanded: abierta,
        onTap: () => setState(() {
          if (abierta) {
            _colapsadas.add(key);
          } else {
            _colapsadas.remove(key);
          }
        }),
      ),
      if (abierta) ...body,
    ];
  }

  // ── Reglas de pruebas según área y género ──
  _ReglaPruebas? get _reglaActual =>
      _area == null || _genero == null
          ? null
          : _reglasPruebas(_area!, _genero!);

  /// true cuando el área y el género definen qué pruebas se aplican.
  bool get _aplicaReglas => _reglaActual != null;

  /// Pruebas que se muestran y se guardan.
  Set<String> get _pruebasVisibles {
    final regla = _reglaActual;
    if (regla == null) {
      // Registros antiguos (sin género o con un área anterior): todo visible.
      return widget.record != null ? _kOrdenPruebas.toSet() : <String>{};
    }
    return {
      ...regla.fijas,
      ..._alternativas.where(regla.alternativas.contains),
    };
  }

  /// Si la prueba alternativa elegida ya no aplica, se limpia.
  void _ajustarAlternativa() {
    if (_area == 'Hidroponía' && _genero == 'Mujer') _genero = null;
    final regla = _reglaActual;
    if (regla == null) return;
    _alternativas.removeWhere((a) => !regla.alternativas.contains(a));
    // Si cambió a un área con una sola prueba alternativa, deja solo una.
    while (_alternativas.length > _maxAlternativas(_area)) {
      _alternativas.remove(_alternativas.last);
    }
  }



  /// true si alguna operación matemática (suma, resta, multiplicación o
  /// división) quedó como "No cumple": la persona queda desaprobada.
  bool get _operacionesFallidas =>
      _pruebasVisibles.contains('concentracion_conteo') &&
      [_sumaOk, _restaOk, _multOk, _divOk].any((v) => v == false);

  /// Mejor (menor) tiempo entre los intentos, en segundos.
  double? _mejorTiempo(String t1, [String? t2]) {
    final a = _parseTime(t1);
    final b = t2 == null ? null : _parseTime(t2);
    if (a == null) return b;
    if (b == null) return a;
    return a <= b ? a : b;
  }

  /// Mejor valor decimal entre dos intentos (menor o mayor).
  double? _mejorDecimal(String t1, String t2, {required bool menor}) {
    double? p(String t) => double.tryParse(t.trim().replaceAll(',', '.'));
    final a = p(t1);
    final b = p(t2);
    if (a == null) return b;
    if (b == null) return a;
    return menor ? (a <= b ? a : b) : (a >= b ? a : b);
  }

  List<Widget> _cuerpoPrueba(String key) {
    switch (key) {
      case 'pin_board':
        return [
            const SizedBox(height: 10),
            _ColumnHeader(),
            const SizedBox(height: 6),
            _TrialRow(
              label: 'T1',
              destrezaCtrl: _pbDestrezaT1,
              calidadOk: _pbCalidadT1,
              onCalidadChanged: (v) => setState(() => _pbCalidadT1 = v),
              onDestrezaChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _TrialRow(
              label: 'T2',
              destrezaCtrl: _pbDestrezaT2,
              calidadOk: _pbCalidadT2,
              onCalidadChanged: (v) => setState(() => _pbCalidadT2 = v),
              onDestrezaChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _BestRow(
              t1Time: _pbDestrezaT1.text,
              t2Time: _pbDestrezaT2.text,
              t1Calidad: _pbCalidadT1,
              t2Calidad: _pbCalidadT2,
            ),
            _CompetenciasSection(
              values: _competencias['pin_board'] ?? {},
              onChanged: (comp, score) =>
                  setState(() => _competencias['pin_board']![comp] = score),
            ),
        ];
      case 'destreza_fina':
        return [
            const SizedBox(height: 10),
            _ColumnHeader(),
            const SizedBox(height: 6),
            _TrialRow(
              label: 'T1',
              destrezaCtrl: _dfDestrezaT1,
              calidadOk: _dfCalidadT1,
              onCalidadChanged: (v) => setState(() => _dfCalidadT1 = v),
              onDestrezaChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _TrialRow(
              label: 'T2',
              destrezaCtrl: _dfDestrezaT2,
              calidadOk: _dfCalidadT2,
              onCalidadChanged: (v) => setState(() => _dfCalidadT2 = v),
              onDestrezaChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _BestRow(
              t1Time: _dfDestrezaT1.text,
              t2Time: _dfDestrezaT2.text,
              t1Calidad: _dfCalidadT1,
              t2Calidad: _dfCalidadT2,
            ),
            _CompetenciasSection(
              values: _competencias['destreza_fina'] ?? {},
              onChanged: (comp, score) => setState(
                  () => _competencias['destreza_fina']![comp] = score),
            ),
        ];
      case 'speed_stack':
        return [
            const SizedBox(height: 10),
            _ColumnHeader(),
            const SizedBox(height: 6),
            _TrialRow(
              label: 'T1',
              destrezaCtrl: _ssDestrezaT1,
              calidadOk: _ssCalidadT1,
              onCalidadChanged: (v) => setState(() => _ssCalidadT1 = v),
              onDestrezaChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _TrialRow(
              label: 'T2',
              destrezaCtrl: _ssDestrezaT2,
              calidadOk: _ssCalidadT2,
              onCalidadChanged: (v) => setState(() => _ssCalidadT2 = v),
              onDestrezaChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _BestRow(
              t1Time: _ssDestrezaT1.text,
              t2Time: _ssDestrezaT2.text,
              t1Calidad: _ssCalidadT1,
              t2Calidad: _ssCalidadT2,
            ),
            _CompetenciasSection(
              values: _competencias['speed_stack'] ?? {},
              onChanged: (comp, score) => setState(
                  () => _competencias['speed_stack']![comp] = score),
            ),
        ];
      case 'fit_brain':
        return [
            const SizedBox(height: 10),
            _ColumnHeader(col2Label: 'VELOCIDAD', col3Label: '% ACIERTO'),
            const SizedBox(height: 6),
            _FitBrainRow(
              label: 'T1',
              velocidadCtrl: _fbVelocidadT1,
              porcentajeCtrl: _fbPorcentajeT1,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
            _FitBrainRow(
              label: 'T2',
              velocidadCtrl: _fbVelocidadT2,
              porcentajeCtrl: _fbPorcentajeT2,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
            _FitBrainBestRow(
              t1Velocidad: _fbVelocidadT1.text,
              t2Velocidad: _fbVelocidadT2.text,
              t1Porcentaje: _fbPorcentajeT1.text,
              t2Porcentaje: _fbPorcentajeT2.text,
            ),
            _CompetenciasSection(
              values: _competencias['fit_brain'] ?? {},
              onChanged: (comp, score) => setState(
                  () => _competencias['fit_brain']![comp] = score),
            ),
        ];
      case 'habilidad_motora_gruesa':
        return [
            const SizedBox(height: 10),
            _ColumnHeader(),
            const SizedBox(height: 6),
            _TrialRow(
              label: 'T1',
              destrezaCtrl: _hmgDestrezaT1,
              calidadOk: _hmgCalidadT1,
              onCalidadChanged: (v) => setState(() => _hmgCalidadT1 = v),
              onDestrezaChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _BestRow(
              t1Time: _hmgDestrezaT1.text,
              t1Calidad: _hmgCalidadT1,
            ),
            _CompetenciasSection(
              values: _competencias['habilidad_motora_gruesa'] ?? {},
              onChanged: (comp, score) => setState(() =>
                  _competencias['habilidad_motora_gruesa']![comp] = score),
            ),
        ];
      case 'prueba_campo':
        final campo = _pruebaCampoDeArea(_area);
        return [
            if (campo != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.grass_outlined, size: 16, color: _kGreen),
                  const SizedBox(width: 6),
                  Text(
                    campo,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _kGreen,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            _ColumnHeader(),
            const SizedBox(height: 6),
            _TrialRow(
              minutos: true,
              label: 'T1',
              destrezaCtrl: _pcDestrezaT1,
              calidadOk: _pcCalidadT1,
              onCalidadChanged: (v) => setState(() => _pcCalidadT1 = v),
              onDestrezaChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _BestRow(
              minutos: true,
              t1Time: _pcDestrezaT1.text,
              t1Calidad: _pcCalidadT1,
            ),
            _CompetenciasSection(
              values: _competencias['prueba_campo'] ?? {},
              onChanged: (comp, score) => setState(
                  () => _competencias['prueba_campo']![comp] = score),
            ),
        ];
      case 'concentracion_conteo':
        return [
            const SizedBox(height: 10),
            _ColumnHeader(),
            const SizedBox(height: 6),
            _TrialRow(
              label: 'T1',
              destrezaCtrl: _ccDestrezaT1,
              calidadOk: _ccCalidadT1,
              onCalidadChanged: (v) => setState(() => _ccCalidadT1 = v),
              onDestrezaChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _BestRow(
              t1Time: _ccDestrezaT1.text,
              t1Calidad: _ccCalidadT1,
            ),
            _CompetenciasSection(
              values: _competencias['concentracion_conteo'] ?? {},
              onChanged: (comp, score) => setState(() =>
                  _competencias['concentracion_conteo']![comp] = score),
            ),
        ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
      appBar: AppBar(
        title: Text(
            widget.record == null ? 'Nuevo Resultado' : 'Editar Resultado'),
        bottom: const TabBar(
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontWeight: FontWeight.w800),
          tabs: [
            Tab(icon: Icon(Icons.edit_note_outlined), text: 'Formulario'),
            Tab(icon: Icon(Icons.insights_outlined), text: 'Proceso'),
          ],
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: TabBarView(
        children: [
      _MantenerVivo(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            ..._seccion(
              'info',
              Icons.person_outline,
              'Información General',
              [
            const SizedBox(height: 12),
            _ReadonlyField(label: 'Fecha', value: _fecha),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _TextInput(
                      ctrl: _nombre, label: 'Nombre', required: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _TextInput(
                      ctrl: _apellido, label: 'Apellido', required: true)),
            ]),
            const SizedBox(height: 12),
            _TextInput(
              ctrl: _cedula,
              label: 'Cédula',
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                if (int.tryParse(v.trim()) == null) {
                  return 'Solo números enteros';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            FormField<String>(
              initialValue: _genero,
              validator:
                  (_) =>
                      _genero == null && widget.record == null
                          ? 'Selecciona el género'
                          : null,
              builder: (field) => _AreaSelector(
                titulo: 'Género',
                icono: Icons.wc_outlined,
                opciones: const ['Hombre', 'Mujer'],
                value: _genero,
                errorText: field.errorText,
                deshabilitadas: {if (_area == 'Hidroponía') 'Mujer'},
                ayuda:
                    _area == 'Hidroponía'
                        ? 'En Hidroponía solo se evalúan hombres.'
                        : null,
                onChanged: (v) {
                  setState(() {
                    _genero = v;
                    _ajustarAlternativa();
                  });
                  field.didChange(v);
                },
              ),
            ),
            const SizedBox(height: 12),
            // Área: botones unidos (mismo estilo que los demás).
            FormField<String>(
              initialValue: _area,
              validator: (_) => _area == null ? 'Selecciona un área' : null,
              builder: (field) => _AreaSelector(
                // Un área antigua que ya no está en la lista se muestra igual
                // para no perder el dato.
                opciones: [
                  ..._kAreas,
                  if (_area != null && !_kAreas.contains(_area)) _area!,
                ],
                value: _area,
                errorText: field.errorText,
                deshabilitadas: {
                  if (_genero == 'Mujer') 'Hidroponía',
                },
                ayuda:
                    _genero == 'Mujer'
                        ? 'Hidroponía solo aplica para hombres.'
                        : null,
                onChanged: (v) {
                  setState(() {
                    _area = v;
                    _ajustarAlternativa();
                  });
                  field.didChange(v);
                },
              ),
            ),
            const SizedBox(height: 12),
            _ReadonlyField(label: 'Formador', value: _formador),
            const SizedBox(height: 12),
            _ReadonlyField(label: 'Proceso', value: _proceso),
            const SizedBox(height: 12),
            _ReadonlyField(label: 'Líder de Prueba', value: _liderPrueba),
              ],
            ),
            if (_aplicaReglas) ...[
              const SizedBox(height: 16),
              _ResumenPruebas(
                area: _area!,
                genero: _genero!,
                cantidad: _pruebasVisibles.length,
                total: _reglaActual!.fijas.length +
                    (_alternativas.isEmpty ? 1 : _alternativas.length),
              ),
              const SizedBox(height: 12),
              _AlternativasSelector(
                opciones: _reglaActual!.alternativas,
                seleccion: _alternativas,
                maximo: _maxAlternativas(_area),
                onChanged: (k) => setState(() {
                  final max = _maxAlternativas(_area);
                  if (_alternativas.contains(k)) {
                    _alternativas.remove(k);
                  } else if (max == 1) {
                    // Fuera de Hidroponía se elige solo una: reemplaza.
                    _alternativas
                      ..clear()
                      ..add(k);
                  } else if (_alternativas.length < max) {
                    _alternativas.add(k);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('En Hidroponía puedes elegir máximo 2 pruebas. Quita una para cambiarla.'),
                      ),
                    );
                  }
                }),
              ),
            ] else if (widget.record == null) ...[
              const SizedBox(height: 16),
              const _AvisoSeleccion(),
            ],
            for (final k in _kOrdenPruebas)
              if (_pruebasVisibles.contains(k)) ...[
                const SizedBox(height: 24),
                ..._seccion(
                  k,
                  _kIconoPrueba[k]!,
                  _kNombrePrueba[k]!,
                  _cuerpoPrueba(k),
                  nota: k == 'prueba_campo' ? 'Se llena después' : null,
                ),
              ],

            // Operaciones Matemáticas va ligada a Concentración y Conteo.
            if (_pruebasVisibles.contains('concentracion_conteo')) ...[
            const SizedBox(height: 24),
            ..._seccion(
              'operaciones',
              Icons.functions_outlined,
              'Operaciones Matemáticas',
              [
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _CumpleToggle(
                  label: 'Suma',
                  value: _sumaOk,
                  onChanged: (v) => setState(() => _sumaOk = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CumpleToggle(
                  label: 'Resta',
                  value: _restaOk,
                  onChanged: (v) => setState(() => _restaOk = v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _CumpleToggle(
                  label: 'Multiplicación',
                  value: _multOk,
                  onChanged: (v) => setState(() => _multOk = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CumpleToggle(
                  label: 'División',
                  value: _divOk,
                  onChanged: (v) => setState(() => _divOk = v),
                ),
              ),
            ]),
              ],
            ),
            ],

            const SizedBox(height: 32),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar Resultado',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
      ),
      Builder(
        builder: (context) => _ProcesoView(
          nombre: '${_nombre.text.trim()} ${_apellido.text.trim()}'.trim(),
          area: _area,
          genero: _genero,
          resultados: _resultadosProceso(),
          operacionesFallidas: _operacionesFallidas,
        ),
      ),
        ],
      ),
      ),
    );
  }

  /// Arma los datos de la vista Proceso con lo diligenciado en el formulario.
  List<_ResultadoProceso> _resultadosProceso() {
    String? calidad(String? c1, [String? c2]) {
      if (c1 == '1' || c2 == '1') return '1';
      if (c1 == 'ok' || c2 == 'ok') return 'ok';
      return null;
    }

    int? actitud(String prueba) {
      final valores = (_competencias[prueba] ?? const {})
          .values
          .whereType<int>()
          .toList();
      if (valores.isEmpty) return null;
      return valores.fold<int>(0, (a, b) => a + b);
    }

    final lista = <_ResultadoProceso>[];
    for (final k in _kOrdenPruebas) {
      if (!_pruebasVisibles.contains(k)) continue;
      switch (k) {
        case 'pin_board':
          lista.add(_ResultadoProceso(
            prueba: k,
            area: _area,
            tiempo: _mejorTiempo(_pbDestrezaT1.text, _pbDestrezaT2.text),
            calidad: calidad(_pbCalidadT1, _pbCalidadT2),
            actitudPuntos: actitud(k),
          ));
        case 'destreza_fina':
          lista.add(_ResultadoProceso(
            prueba: k,
            area: _area,
            tiempo: _mejorTiempo(_dfDestrezaT1.text, _dfDestrezaT2.text),
            calidad: calidad(_dfCalidadT1, _dfCalidadT2),
            actitudPuntos: actitud(k),
          ));
        case 'speed_stack':
          lista.add(_ResultadoProceso(
            prueba: k,
            area: _area,
            tiempo: _mejorTiempo(_ssDestrezaT1.text, _ssDestrezaT2.text),
            calidad: calidad(_ssCalidadT1, _ssCalidadT2),
            actitudPuntos: actitud(k),
          ));
        case 'fit_brain':
          lista.add(_ResultadoProceso(
            prueba: k,
            area: _area,
            tiempo: _mejorDecimal(_fbVelocidadT1.text, _fbVelocidadT2.text, menor: true),
            acierto: _mejorDecimal(_fbPorcentajeT1.text, _fbPorcentajeT2.text, menor: false),
            actitudPuntos: actitud(k),
          ));
        case 'habilidad_motora_gruesa':
          lista.add(_ResultadoProceso(
            prueba: k,
            area: _area,
            tiempo: _mejorTiempo(_hmgDestrezaT1.text),
            calidad: calidad(_hmgCalidadT1),
            actitudPuntos: actitud(k),
          ));
        case 'prueba_campo':
          lista.add(_ResultadoProceso(
            prueba: k,
            area: _area,
            tiempo: _minutosASegundos(_pcDestrezaT1.text),
            calidad: calidad(_pcCalidadT1),
            actitudPuntos: actitud(k),
          ));
        case 'concentracion_conteo':
          lista.add(_ResultadoProceso(
            prueba: k,
            area: _area,
            tiempo: _mejorTiempo(_ccDestrezaT1.text),
            calidad: calidad(_ccCalidadT1),
            actitudPuntos: actitud(k),
          ));
      }
    }
    return lista;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

/// Encabezado de sección (barra azul)
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? nota;
  final bool expanded;
  final VoidCallback? onTap;
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.nota,
    this.expanded = true,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (nota != null)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      nota!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (onTap != null)
                  AnimatedRotation(
                    turns: expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: Colors.white,
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
}

/// Resumen: cuántas pruebas aplican según área y género.
class _ResumenPruebas extends StatelessWidget {
  final String area;
  final String genero;
  final int cantidad;
  final int total;
  const _ResumenPruebas({
    required this.area,
    required this.genero,
    required this.cantidad,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kBlueBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.fact_check_outlined, color: _kBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$area · $genero: $total pruebas',
              style: const TextStyle(
                color: Color(0xFF0D3B82),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$cantidad / $total',
            style: const TextStyle(
              color: _kBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso cuando aún no se ha elegido área y género.
class _AvisoSeleccion extends StatelessWidget {
  const _AvisoSeleccion();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCC80)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: _kOrange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Selecciona el área y el género para ver las pruebas que aplican.',
                style: TextStyle(color: Color(0xFF8A4B00)),
              ),
            ),
          ],
        ),
      );
}

/// Fila de encabezados de columnas (Intento | Destreza | Calidad)
class _ColumnHeader extends StatelessWidget {
  final String col2Label;
  final String col3Label;
  const _ColumnHeader({
    this.col2Label = 'DESTREZA',
    this.col3Label = 'CALIDAD',
  });
  @override
  Widget build(BuildContext context) => Row(
        children: [
          const SizedBox(
            width: 58,
            child: Text('INTENTO',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _kBlue)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(col2Label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _kBlue)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(col3Label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _kBlue)),
          ),
        ],
      );
}

/// Fila de un intento: Etiqueta | Campo tiempo | Botón OK calidad
class _TrialRow extends StatelessWidget {
  final String label;
  final TextEditingController destrezaCtrl;
  final String? calidadOk;
  final ValueChanged<String?> onCalidadChanged;
  final ValueChanged<String>? onDestrezaChanged;
  /// true = tiempo en minutos con decimales (prueba de campo).
  final bool minutos;

  const _TrialRow({
    required this.label,
    required this.destrezaCtrl,
    required this.calidadOk,
    required this.onCalidadChanged,
    this.onDestrezaChanged,
    this.minutos = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Etiqueta T1/T2
          SizedBox(
            width: 58,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: _kBlueBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _kBlue),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Campo de destreza (tiempo)
          Expanded(
            flex: 5,
            child: TextFormField(
              controller: destrezaCtrl,
              keyboardType: minutos
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              inputFormatters: minutos
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                  : [_TimeInputFormatter()],
              onChanged: onDestrezaChanged,
              decoration: InputDecoration(
                labelText: minutos ? 'Minutos (ej. 12,5)' : 'mm:ss',
                isDense: true,
                suffixIcon: const Icon(Icons.timer_outlined, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botón OK Calidad
          Expanded(
            flex: 3,
            child: _OkButton(
              value: calidadOk,
              onChanged: onCalidadChanged,
            ),
          ),
        ],
      );
}

/// Fila de Mejor Tiempo para pruebas con Destreza (tiempo) y Calidad
class _BestRow extends StatelessWidget {
  final String t1Time;
  final String? t2Time;
  final String? t1Calidad;
  final String? t2Calidad;
  /// true = tiempos en minutos con decimales (prueba de campo).
  final bool minutos;

  const _BestRow({
    required this.t1Time,
    this.t2Time,
    required this.t1Calidad,
    this.t2Calidad,
    this.minutos = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Mejor tiempo (el menor tiempo registrado)
    double? leer(String? t) => minutos ? _minutosASegundos(t) : _parseTime(t);
    String formatear(double s) => minutos ? '${_segundosAMinutos(s)} min' : _formatTime(s);
    final s1 = leer(t1Time);
    final s2 = (t2Time != null && t2Time!.isNotEmpty) ? leer(t2Time) : null;

    String bestTimeStr = '—';
    if (s1 != null && s2 != null) {
      final bestSec = s1 <= s2 ? s1 : s2;
      bestTimeStr = formatear(bestSec);
    } else if (s1 != null) {
      bestTimeStr = formatear(s1);
    } else if (s2 != null) {
      bestTimeStr = formatear(s2);
    }

    // 2. Calidad combinada
    // Si hay algún 1 en los intentos -> 1 (naranja)
    // Si no hay 1 y hay algún ok -> ok (verde)
    // De lo contrario -> vacío (—)
    final c1 = t1Calidad?.toLowerCase().trim();
    final c2 = t2Calidad?.toLowerCase().trim();

    String? bestCalidad;
    if (c1 == '1' || c2 == '1') {
      bestCalidad = '1';
    } else if (c1 == 'ok' || c2 == 'ok') {
      bestCalidad = 'ok';
    } else {
      bestCalidad = null;
    }

    final hasTime = bestTimeStr != '—';
    final isOk = bestCalidad == 'ok';
    final isOne = bestCalidad == '1';

    Color calidadBg = Colors.white;
    Color calidadBorder = const Color(0xFFBBD0F0);
    double calidadBorderWidth = 1;
    List<BoxShadow>? calidadShadows;

    if (isOk) {
      calidadBg = _kGreen;
      calidadBorder = _kGreen;
      calidadBorderWidth = 2;
      calidadShadows = [
        BoxShadow(
          color: _kGreen.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isOne) {
      calidadBg = _kOrange;
      calidadBorder = _kOrange;
      calidadBorderWidth = 2;
      calidadShadows = [
        BoxShadow(
          color: _kOrange.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }

    Widget calidadContent;
    if (isOk) {
      calidadContent = const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 4),
          Text(
            'OK',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      );
    } else if (isOne) {
      calidadContent = const Text(
        '1',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      );
    } else {
      calidadContent = Text(
        '—',
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 20,
          fontWeight: FontWeight.w300,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Etiqueta Mejor Tiempo
        SizedBox(
          width: 58,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MEJOR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1D4ED8),
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  'TIEMPO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Campo Mejor Tiempo (automático / sólo lectura)
        Expanded(
          flex: 5,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasTime
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFFCBD5E1),
                width: hasTime ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: hasTime
                      ? const Color(0xFF1D4ED8)
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bestTimeStr,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: hasTime
                          ? const Color(0xFF0F172A)
                          : Colors.grey.shade400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Calidad Resultante
        Expanded(
          flex: 3,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            decoration: BoxDecoration(
              color: calidadBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: calidadBorder,
                width: calidadBorderWidth,
              ),
              boxShadow: calidadShadows,
            ),
            child: Center(child: calidadContent),
          ),
        ),
      ],
    );
  }
}

/// Fila de Fit Brain: Etiqueta | Velocidad (tiempo) | % Acierto (número)
class _FitBrainRow extends StatelessWidget {
  final String label;
  final TextEditingController velocidadCtrl;
  final TextEditingController porcentajeCtrl;
  final VoidCallback? onChanged;

  const _FitBrainRow({
    required this.label,
    required this.velocidadCtrl,
    required this.porcentajeCtrl,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 58,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: _kBlueBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _kBlue),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: TextFormField(
              controller: velocidadCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => onChanged?.call(),
              decoration: const InputDecoration(
                labelText: 'Seg. (ej. 0.92)',
                isDense: true,
                suffixIcon: Icon(Icons.timer_outlined, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: porcentajeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => onChanged?.call(),
              decoration: const InputDecoration(
                labelText: '%',
                isDense: true,
                suffixText: '%',
              ),
            ),
          ),
        ],
      );
}

/// Fila de Mejor Resultado para Fit Brain (Velocidad y % Acierto)
class _FitBrainBestRow extends StatelessWidget {
  final String t1Velocidad;
  final String t2Velocidad;
  final String t1Porcentaje;
  final String t2Porcentaje;

  const _FitBrainBestRow({
    required this.t1Velocidad,
    required this.t2Velocidad,
    required this.t1Porcentaje,
    required this.t2Porcentaje,
  });

  @override
  Widget build(BuildContext context) {
    final s1 = double.tryParse(t1Velocidad.trim().replaceAll(',', '.'));
    final s2 = double.tryParse(t2Velocidad.trim().replaceAll(',', '.'));

    String seg(double v) => '${v.toStringAsFixed(2)}″';
    String bestTimeStr = '—';
    if (s1 != null && s2 != null) {
      bestTimeStr = seg(s1 <= s2 ? s1 : s2);
    } else if (s1 != null) {
      bestTimeStr = seg(s1);
    } else if (s2 != null) {
      bestTimeStr = seg(s2);
    }

    final p1 = _decimal(t1Porcentaje);
    final p2 = _decimal(t2Porcentaje);

    String bestPctStr = '—';
    if (p1 != null && p2 != null) {
      final best = p1 >= p2 ? p1 : p2;
      bestPctStr = best % 1 == 0 ? '${best.toInt()}%' : '$best%';
    } else if (p1 != null) {
      bestPctStr = p1 % 1 == 0 ? '${p1.toInt()}%' : '$p1%';
    } else if (p2 != null) {
      bestPctStr = p2 % 1 == 0 ? '${p2.toInt()}%' : '$p2%';
    }

    final hasTime = bestTimeStr != '—';
    final hasPct = bestPctStr != '—';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 58,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MEJOR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1D4ED8),
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  'TIEMPO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasTime
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFFCBD5E1),
                width: hasTime ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: hasTime
                      ? const Color(0xFF1D4ED8)
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bestTimeStr,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: hasTime
                          ? const Color(0xFF0F172A)
                          : Colors.grey.shade400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasPct
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFFCBD5E1),
                width: hasPct ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                bestPctStr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: hasPct
                      ? const Color(0xFF0F172A)
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón toggle OK (verde) / 1 (naranja) / sin marcar para campos de Calidad
class _OkButton extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _OkButton({required this.value, required this.onChanged});

  void _cycleNext() {
    final v = value?.toLowerCase().trim();
    if (v == null || v.isEmpty) {
      onChanged('ok');
    } else if (v == 'ok') {
      onChanged('1');
    } else {
      onChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = value?.toLowerCase().trim();
    final isOk = v == 'ok';
    final isOne = v == '1';

    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFBBD0F0);
    double borderWidth = 1;
    List<BoxShadow>? shadows;

    if (isOk) {
      bgColor = _kGreen;
      borderColor = _kGreen;
      borderWidth = 2;
      shadows = [
        BoxShadow(
          color: _kGreen.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isOne) {
      bgColor = _kOrange;
      borderColor = _kOrange;
      borderWidth = 2;
      shadows = [
        BoxShadow(
          color: _kOrange.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }

    Widget content;
    if (isOk) {
      content = const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 4),
          Text('OK',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
        ],
      );
    } else if (isOne) {
      content = const Text(
        '1',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      );
    } else {
      content = Text(
        '—',
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 20,
          fontWeight: FontWeight.w300,
        ),
      );
    }

    return GestureDetector(
      onTap: _cycleNext,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: shadows,
        ),
        child: Center(child: content),
      ),
    );
  }
}

/// Botón de 3 estados para operaciones matemáticas: Cumple / No Cumple / Sin marcar
class _CumpleToggle extends StatelessWidget {
  final String label;
  final bool? value; // null=sin marcar, true=cumple, false=no cumple
  final ValueChanged<bool?> onChanged;
  const _CumpleToggle(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBD0F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF0D3B82)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Cumple
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(value == true ? null : true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 42,
                    decoration: BoxDecoration(
                      color: value == true ? _kGreen : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(10)),
                      border: Border.all(
                        color: value == true
                            ? _kGreen
                            : const Color(0xFFBBD0F0),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '✓ Cumple',
                        style: TextStyle(
                          color: value == true
                              ? Colors.white
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // No Cumple
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(value == false ? null : false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 42,
                    decoration: BoxDecoration(
                      color: value == false
                          ? const Color(0xFFC62828)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(10)),
                      border: Border.all(
                        color: value == false
                            ? const Color(0xFFC62828)
                            : const Color(0xFFBBD0F0),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '✗ No cumple',
                        style: TextStyle(
                          color: value == false
                              ? Colors.white
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Selector de área con botones unidos (mismo estilo que Cumple / No cumple).
class _AreaSelector extends StatelessWidget {
  final List<String> opciones;
  final String? value;
  final String? errorText;
  final ValueChanged<String?> onChanged;
  final String titulo;
  final IconData icono;
  final Set<String> deshabilitadas;
  final String? ayuda;

  const _AreaSelector({
    required this.opciones,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.titulo = 'Área',
    this.icono = Icons.business_outlined,
    this.deshabilitadas = const {},
    this.ayuda,
  });

  @override
  Widget build(BuildContext context) {
    final hayError = errorText != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hayError ? const Color(0xFFC62828) : const Color(0xFFBBD0F0),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: _kBlue),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF0D3B82),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < opciones.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap:
                        deshabilitadas.contains(opciones[i])
                            ? null
                            : () => onChanged(opciones[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            value == opciones[i] ? _kBlue : Colors.transparent,
                        borderRadius: BorderRadius.horizontal(
                          left:
                              i == 0 ? const Radius.circular(10) : Radius.zero,
                          right:
                              i == opciones.length - 1
                                  ? const Radius.circular(10)
                                  : Radius.zero,
                        ),
                        border: Border.all(
                          color:
                              value == opciones[i]
                                  ? _kBlue
                                  : const Color(0xFFBBD0F0),
                        ),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          opciones[i],
                          style: TextStyle(
                            color:
                                value == opciones[i]
                                    ? Colors.white
                                    : deshabilitadas.contains(opciones[i])
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade600,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (ayuda != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                ayuda!,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
            ),
          if (hayError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                errorText!,
                style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Campo de solo lectura decorado
class _ReadonlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadonlyField({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFECF0FA),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFBBD0F0)),
          ),
        ),
        child:
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}

/// Campo de texto genérico con validación
class _TextInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool required;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _TextInput({
    required this.ctrl,
    required this.label,
    this.required = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator ??
            (required
                ? (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null
                : null),
        decoration: InputDecoration(labelText: label),
      );
}

/// Sección de evaluación de 6 competencias conductuales para una prueba.
/// Cada competencia va en su fila y a la derecha sus 3 botones (0, 1, 2),
/// con el mismo estilo de los botones de Operaciones Matemáticas.
class _CompetenciasSection extends StatelessWidget {
  final Map<String, int?> values;
  final void Function(String competencia, int? score) onChanged;

  const _CompetenciasSection({
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final evaluadas = _kCompetencias.where((c) => values[c] != null).length;
    final total = _kCompetencias
        .map((c) => values[c] ?? 0)
        .fold<int>(0, (a, b) => a + b);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBD0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 18, color: _kBlue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Evaluación de Competencias',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D3B82),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kBlueBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total / ${_kCompetencias.length * 2}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _kBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _leyenda('0', 'Malo', const Color(0xFFC62828)),
              const SizedBox(width: 10),
              _leyenda('1', 'Regular', _kOrange),
              const SizedBox(width: 10),
              _leyenda('2', 'Excelente', _kGreen),
              const Spacer(),
              Text(
                '$evaluadas de ${_kCompetencias.length}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _kCompetencias.length; i++) ...[
            if (i > 0) const Divider(height: 14, color: Color(0xFFE8EEF8)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${i + 1}. ${_kCompetencias[i]}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ScoreSelector(
                  value: values[_kCompetencias[i]],
                  onChanged: (v) => onChanged(_kCompetencias[i], v),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _leyenda(String n, String texto, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              n,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      );
}

/// Tres botones unidos (0 / 1 / 2), mismo estilo que Cumple / No cumple.
/// Tocar el botón activo lo desmarca.
class _ScoreSelector extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _ScoreSelector({
    required this.value,
    required this.onChanged,
  });

  static const _opciones = [
    (0, Color(0xFFC62828)),
    (1, _kOrange),
    (2, _kGreen),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _opciones.length; i++)
          _boton(
            score: _opciones[i].$1,
            color: _opciones[i].$2,
            radius: BorderRadius.horizontal(
              left: i == 0 ? const Radius.circular(10) : Radius.zero,
              right:
                  i == _opciones.length - 1
                      ? const Radius.circular(10)
                      : Radius.zero,
            ),
          ),
      ],
    );
  }

  Widget _boton({
    required int score,
    required Color color,
    required BorderRadius radius,
  }) {
    final activo = value == score;
    return GestureDetector(
      onTap: () => onChanged(activo ? null : score),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 42,
        decoration: BoxDecoration(
          color: activo ? color : Colors.transparent,
          borderRadius: radius,
          border: Border.all(
            color: activo ? color : const Color(0xFFBBD0F0),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$score',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: activo ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Niveles por tiempo (tabla "Pruebas de Carpa") – vista Proceso
// ─────────────────────────────────────────────────────────────────────────────

/// Rango de una tabla de niveles: hasta [max] (inclusive) corresponde a [nivel].
class _Banda {
  final int nivel;
  final double max;
  final String etiqueta;
  const _Banda(this.nivel, this.max, this.etiqueta);
}

/// Tiempos en segundos (Fit Brain en segundos con decimales).
const _kTablaTiempo = <String, List<_Banda>>{
  'destreza_fina': [
    _Banda(4, 35, '35″ o menos'),
    _Banda(3, 39.99, '36″–39″'),
    _Banda(2, 44.99, '40″–44″'),
    _Banda(1, double.infinity, '45″ o más'),
  ],
  'speed_stack': [
    _Banda(4, 15, '15″ o menos'),
    _Banda(3, 17.99, '16″–17″'),
    _Banda(2, 19, '18″–19″'),
    _Banda(1, double.infinity, 'Más de 19″'),
  ],
  'pin_board': [
    _Banda(4, 25, '25″ o menos'),
    _Banda(3, 28.99, '26″–28″'),
    _Banda(2, 31.99, '29″–31″'),
    _Banda(1, double.infinity, '32″ o más'),
  ],
  'concentracion_conteo': [
    _Banda(4, 42, '42″ o menos'),
    _Banda(3, 56.99, '43″–56″'),
    _Banda(2, 65.99, '57″–65″'),
    _Banda(1, double.infinity, '66″ o más'),
  ],
  'fit_brain': [
    _Banda(4, 0.85, '0,85″ o menos'),
    _Banda(3, 1.0, '0,86″–1″'),
    _Banda(2, 1.3, '1,01″–1,3″'),
    _Banda(1, double.infinity, 'Más de 1,3″'),
  ],
  // Huester
  'habilidad_motora_gruesa': [
    _Banda(4, 9, '9″ o menos'),
    _Banda(3, 14, '9,1″–14″'),
    _Banda(2, 19, '14,1″–19″'),
    _Banda(1, double.infinity, '19,1″ o más'),
  ],
};

/// Prueba de Campo según el área (tiempos en segundos; la tabla está en minutos).
const _kTablaCampo = <String, List<_Banda>>{
  // Hidroponía
  'Barridos': [
    _Banda(4, 720, '12 min o menos'),
    _Banda(3, 900, '12,1–15 min'),
    _Banda(2, 1020, '15,1–17 min'),
    _Banda(1, double.infinity, '17,1 min o más'),
  ],
  // Producción
  'Encanaste': [
    _Banda(4, 540, '7–9 min'),
    _Banda(3, 780, '9,1–13 min'),
    _Banda(2, 960, '13,1–16 min'),
    _Banda(1, double.infinity, 'Más de 16 min'),
  ],
  // Poscosecha
  'Clasificación': [
    _Banda(4, 120, '1,3–2 min'),
    _Banda(3, 138, '2,1–2,3 min'),
    _Banda(2, 180, '2,31–3 min'),
    _Banda(1, double.infinity, '3,1 min o más'),
  ],
};

/// Nombre de la prueba de campo que se aplica en cada área.
String? _pruebaCampoDeArea(String? area) => switch (area) {
      'Producción' => 'Encanaste',
      'Poscosecha' => 'Clasificación',
      'Hidroponía' => 'Barridos',
      _ => null,
    };

/// Tabla de niveles por tiempo de una prueba (la de campo depende del área).
List<_Banda>? _tablaDe(String prueba, String? area) {
  if (prueba == 'prueba_campo') {
    final campo = _pruebaCampoDeArea(area);
    return campo == null ? null : _kTablaCampo[campo];
  }
  return _kTablaTiempo[prueba];
}



int? _nivelPorTiempo(String prueba, double? segundos, [String? area]) {
  final tabla = _tablaDe(prueba, area);
  if (tabla == null || segundos == null) return null;
  for (final b in tabla) {
    if (segundos <= b.max) return b.nivel;
  }
  return 1;
}

int? _nivelAcierto(double? porcentaje) {
  if (porcentaje == null) return null;
  if (porcentaje >= 100) return 4;
  if (porcentaje >= 90) return 3;
  if (porcentaje >= 85) return 2;
  return 1;
}

Color _colorNivel(int? nivel) => switch (nivel) {
      4 => const Color(0xFF2E7D32),
      3 => const Color(0xFF1565C0),
      2 => const Color(0xFFEF6C00),
      1 => const Color(0xFFC62828),
      _ => const Color(0xFF90A4AE),
    };

String _textoNivel(int? nivel) => switch (nivel) {
      4 => 'Excelente',
      3 => 'Bueno',
      2 => 'Aceptable',
      1 => 'Bajo',
      _ => 'Sin dato',
    };





class _InsigniaNivel extends StatelessWidget {
  final int? nivel;
  final bool tieneTabla;
  const _InsigniaNivel({required this.nivel, required this.tieneTabla});

  @override
  Widget build(BuildContext context) {
    final color = _colorNivel(nivel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: nivel == null ? const Color(0xFFECEFF1) : color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            nivel == null ? (tieneTabla ? '—' : 'N/A') : 'Nivel $nivel',
            style: TextStyle(
              color: nivel == null ? Colors.blueGrey : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          if (nivel != null)
            Text(
              _textoNivel(nivel),
              style: const TextStyle(color: Colors.white, fontSize: 10.5),
            ),
        ],
      ),
    );
  }
}

class _BarraNivel extends StatelessWidget {
  final int? nivel;
  const _BarraNivel({required this.nivel});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 1; i <= 4; i++) ...[
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: nivel != null && i <= nivel!
                      ? _colorNivel(nivel)
                      : const Color(0xFFE3E8EE),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (i < 4) const SizedBox(width: 4),
          ],
        ],
      );
}

int? _nivelActitud(int? puntos) {
  if (puntos == null) return null;
  if (puntos >= 10) return 4;
  if (puntos >= 7) return 3;
  if (puntos >= 4) return 2;
  return 1;
}

/// Datos de una prueba listos para mostrar en la vista Proceso.
class _ResultadoProceso {
  final String prueba;
  final String? area;
  final double? tiempo; // mejor tiempo en segundos
  final String? calidad; // 'ok' | '1' | null
  final double? acierto; // solo Fit Brain
  final int? actitudPuntos;
  const _ResultadoProceso({
    required this.prueba,
    this.area,
    this.tiempo,
    this.calidad,
    this.acierto,
    this.actitudPuntos,
  });

  int? get nivelTiempo => _nivelPorTiempo(prueba, tiempo, area);
  int? get nivelAcierto => prueba == 'fit_brain' ? _nivelAcierto(acierto) : null;
  int? get nivelActitud => _nivelActitud(actitudPuntos);
  bool get tieneTabla => _tablaDe(prueba, area) != null;

  /// Nivel principal de la prueba (el de tiempo; Fit Brain toma el menor
  /// entre tiempo y % de acierto).
  /// La calidad en "1" baja un nivel (mínimo nivel 1).
  bool get bajaPorCalidad => calidad == '1' && nivelTiempo != null;

  int? get nivel {
    var t = nivelTiempo;
    if (t != null && bajaPorCalidad && t > 1) t = t - 1;
    final a = nivelAcierto;
    if (t != null && a != null) return t < a ? t : a;
    return t ?? a;
  }
}

String _segundosTexto(String prueba, double? s) {
  if (s == null) return '—';
  if (prueba == 'fit_brain') {
    return '${s.toStringAsFixed(2).replaceAll('.', ',')}″';
  }
  if (prueba == 'prueba_campo') {
    return '${_segundosAMinutos(s)} min';
  }
  return s % 1 == 0 ? '${s.toInt()}″  (${_formatTime(s)})' : '${s.toStringAsFixed(1)}″';
}

/// Vista "Proceso": nombre de la prueba con su nivel.
class _ProcesoView extends StatelessWidget {
  final String nombre;
  final String? area;
  final String? genero;
  final List<_ResultadoProceso> resultados;
  final bool operacionesFallidas;

  const _ProcesoView({
    required this.nombre,
    required this.area,
    required this.genero,
    required this.resultados,
    this.operacionesFallidas = false,
  });

  @override
  Widget build(BuildContext context) {
    if (resultados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swipe_left_outlined, size: 52, color: Colors.blueGrey.shade300),
              const SizedBox(height: 12),
              const Text(
                'Elige el área, el género y la prueba a aplicar en el formulario para ver los niveles.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Promedio = (niveles de las pruebas + niveles de actitud) / cantidad.
    final nivelesPruebas = [
      for (final r in resultados)
        if (r.nivel != null) r.nivel!,
    ];
    final nivelesActitud = [
      for (final r in resultados)
        if (r.nivelActitud != null) r.nivelActitud!,
    ];
    final niveles = [...nivelesPruebas, ...nivelesActitud];
    final suma = niveles.fold<int>(0, (a, b) => a + b);
    final promedio = niveles.isEmpty ? null : suma / niveles.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final columnas = ancho >= 1000 ? 3 : (ancho >= 620 ? 2 : 1);
        const separacion = 12.0;
        final anchoTarjeta = (ancho.clamp(0, 1200) - 32 - separacion * (columnas - 1)) / columnas;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                _ResumenProceso(
                  nombre: nombre,
                  area: area,
                  genero: genero,
                  promedio: promedio,
                  suma: suma,
                  cantidad: niveles.length,
                  evaluadas: nivelesPruebas.length,
                  total: resultados.length,
                  operacionesFallidas: operacionesFallidas,
                ),
                const SizedBox(height: 12),
                const _LeyendaNiveles(),
                const SizedBox(height: 12),
                Wrap(
                  spacing: separacion,
                  runSpacing: separacion,
                  children: [
                    for (final r in resultados)
                      SizedBox(width: anchoTarjeta, child: _TarjetaNivel(r: r)),
                  ],
                ),
                const SizedBox(height: 16),
                _ActitudProceso(resultados: resultados),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResumenProceso extends StatelessWidget {
  final String nombre;
  final String? area;
  final String? genero;
  final double? promedio;
  final int suma;
  final int cantidad;
  final int evaluadas;
  final int total;
  final bool operacionesFallidas;
  const _ResumenProceso({
    required this.nombre,
    required this.area,
    required this.genero,
    required this.promedio,
    required this.suma,
    required this.cantidad,
    required this.evaluadas,
    required this.total,
    this.operacionesFallidas = false,
  });

  @override
  Widget build(BuildContext context) {
    // Aprobado si el promedio es 3 o más y no falló ninguna operación.
    final aprobado = promedio != null && promedio! >= 3 && !operacionesFallidas;
    final color = (promedio == null && !operacionesFallidas)
        ? const Color(0xFF90A4AE)
        : (aprobado ? const Color(0xFF2E7D32) : const Color(0xFFC62828));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre.isEmpty ? 'Aspirante sin nombre' : nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (area != null) area!,
                    if (genero != null) genero!,
                    '$evaluadas de $total pruebas con nivel',
                  ].join('  •  '),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (cantidad > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Suma $suma ÷ $cantidad niveles (pruebas + actitud)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
                if (operacionesFallidas) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC62828),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Desaprobado: no cumplió una operación matemática',
                      style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 96,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  promedio == null ? '—' : promedio!.toStringAsFixed(1).replaceAll('.', ','),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const Text(
                  'Promedio',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (promedio == null && !operacionesFallidas)
                        ? 'Sin datos'
                        : (aprobado ? 'APROBADO' : 'DESAPROBADO'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaNivel extends StatelessWidget {
  final _ResultadoProceso r;
  const _TarjetaNivel({required this.r});

  @override
  Widget build(BuildContext context) {
    final nivel = r.nivel;
    final color = _colorNivel(nivel);
    final tabla = _tablaDe(r.prueba, r.area);
    final campo = r.prueba == 'prueba_campo' ? _pruebaCampoDeArea(r.area) : null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .45), width: 1.4),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _kBlueBg,
                child: Icon(_kIconoPrueba[r.prueba], size: 19, color: _kBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.prueba == 'habilidad_motora_gruesa'
                          ? 'Huester (Hab. Motora Gruesa)'
                          : _kNombrePrueba[r.prueba]!,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                    if (campo != null)
                      Text(
                        campo,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _kGreen,
                        ),
                      ),
                  ],
                ),
              ),
              _InsigniaNivel(nivel: nivel, tieneTabla: r.tieneTabla),
            ],
          ),
          const SizedBox(height: 12),
          if (r.tieneTabla) _BarraNivel(nivel: nivel),
          if (r.bajaPorCalidad) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.arrow_downward_rounded, size: 15, color: _kOrange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    r.nivelTiempo == 1
                        ? 'Calidad en 1: ya está en el nivel más bajo.'
                        : 'Por tiempo era Nivel ${r.nivelTiempo}; baja 1 nivel por calidad en 1.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kOrange,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Dato(
                icono: Icons.timer_outlined,
                texto: 'Mejor tiempo: ${_segundosTexto(r.prueba, r.tiempo)}',
                color: r.tiempo == null ? null : _colorNivel(r.nivelTiempo),
              ),
              if (r.prueba == 'fit_brain')
                _Dato(
                  icono: Icons.percent,
                  texto: r.acierto == null
                      ? 'Acierto: —'
                      : 'Acierto: ${r.acierto!.toStringAsFixed(r.acierto! % 1 == 0 ? 0 : 1)}% · N${r.nivelAcierto}',
                  color: _colorNivel(r.nivelAcierto),
                )
              else
                _Dato(
                  icono: r.calidad == 'ok'
                      ? Icons.check_circle_outline
                      : r.calidad == '1'
                          ? Icons.error_outline
                          : Icons.help_outline,
                  texto: r.calidad == 'ok'
                      ? 'Calidad: cumple'
                      : r.calidad == '1'
                          ? 'Calidad: con novedad'
                          : 'Calidad: —',
                  color: r.calidad == 'ok'
                      ? _kGreen
                      : r.calidad == '1'
                          ? _kOrange
                          : null,
                ),
            ],
          ),
          if (tabla != null) ...[
            const SizedBox(height: 10),
            Text(
              campo == null ? 'Tabla de tiempos' : 'Tabla de tiempos · $campo',
              style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade500, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in tabla)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: b.nivel == r.nivelTiempo
                          ? _colorNivel(b.nivel)
                          : _colorNivel(b.nivel).withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'N${b.nivel}  ${b.etiqueta}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: b.nivel == r.nivelTiempo ? Colors.white : _colorNivel(b.nivel),
                      ),
                    ),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              r.prueba == 'prueba_campo'
                  ? 'Elige el área para saber qué prueba de campo aplica.'
                  : 'Esta prueba no tiene tabla de niveles por tiempo.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color? color;
  const _Dato({required this.icono, required this.texto, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.blueGrey.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: c),
          const SizedBox(width: 5),
          Text(texto, style: TextStyle(fontSize: 12.5, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LeyendaNiveles extends StatelessWidget {
  const _LeyendaNiveles();

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 14,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final n in [4, 3, 2, 1])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: _colorNivel(n), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text('Nivel $n · ${_textoNivel(n)}', style: const TextStyle(fontSize: 12)),
              ],
            ),
        ],
      );
}

/// Mantiene vivo el formulario al deslizar a la vista Proceso.
class _MantenerVivo extends StatefulWidget {
  final Widget child;
  const _MantenerVivo({required this.child});
  @override
  State<_MantenerVivo> createState() => _MantenerVivoState();
}

class _MantenerVivoState extends State<_MantenerVivo>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Actitud (evaluación de competencias): suma de las 6 competencias de cada
/// prueba (máx. 12) → 10–12 N4 · 7–9 N3 · 4–6 N2 · menos de 4 N1.
class _ActitudProceso extends StatelessWidget {
  final List<_ResultadoProceso> resultados;
  const _ActitudProceso({required this.resultados});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBD0F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_people_outlined, color: _kBlue, size: 20),
                SizedBox(width: 8),
                Text(
                  'Actitud',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Evaluación de competencias · 10–12 N4 · 7–9 N3 · 4–6 N2 · menos de 4 N1',
              style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade500),
            ),
            const SizedBox(height: 6),
            for (final r in resultados)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE6ECF5))),
                ),
                child: Row(
                  children: [
                    Icon(_kIconoPrueba[r.prueba], size: 18, color: _kBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.prueba == 'habilidad_motora_gruesa'
                            ? 'Huester (Hab. Motora Gruesa)'
                            : _kNombrePrueba[r.prueba]!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      r.actitudPuntos == null ? '—' : '${r.actitudPuntos}/12',
                      style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 78,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: r.nivelActitud == null
                            ? const Color(0xFFECEFF1)
                            : _colorNivel(r.nivelActitud),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        r.nivelActitud == null ? 'Sin dato' : 'Nivel ${r.nivelActitud}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: r.nivelActitud == null ? Colors.blueGrey : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

/// Resumen de niveles (lo mismo que muestra la pestaña Proceso) listo para
/// guardarse en Supabase y usarse luego en la plantilla PDF.
class _ResumenNiveles {
  final Map<String, dynamic> json;
  final double? promedio;
  final String? resultado;
  const _ResumenNiveles(this.json, this.promedio, this.resultado);
}

_ResumenNiveles _resumenNiveles(
  List<_ResultadoProceso> resultados, {
  bool operacionesFallidas = false,
}) {
  final niveles = <int>[
    for (final r in resultados)
      if (r.nivel != null) r.nivel!,
    for (final r in resultados)
      if (r.nivelActitud != null) r.nivelActitud!,
  ];
  final suma = niveles.fold<int>(0, (a, b) => a + b);
  final promedio = niveles.isEmpty ? null : suma / niveles.length;
  // Si no cumplió alguna operación matemática queda desaprobado sin importar
  // el promedio.
  final resultado = operacionesFallidas
      ? 'Reprobado'
      : (promedio == null ? null : (promedio >= 3 ? 'Aprobado' : 'Reprobado'));

  final pruebas = <String, dynamic>{
    for (final r in resultados)
      r.prueba: {
        'nombre': r.prueba == 'prueba_campo'
            ? (_pruebaCampoDeArea(r.area) ?? _kNombrePrueba[r.prueba])
            : _kNombrePrueba[r.prueba],
        'tiempo_segundos': r.tiempo,
        'nivel_tiempo': r.nivelTiempo,
        'calidad': r.calidad,
        'baja_por_calidad': r.bajaPorCalidad,
        if (r.prueba == 'fit_brain') 'acierto': r.acierto,
        if (r.prueba == 'fit_brain') 'nivel_acierto': r.nivelAcierto,
        'nivel': r.nivel,
        'actitud_puntos': r.actitudPuntos,
        'nivel_actitud': r.nivelActitud,
      },
  };

  return _ResumenNiveles(
    {
      'pruebas': pruebas,
      'orden': [for (final r in resultados) r.prueba],
      'suma': suma,
      'cantidad': niveles.length,
      'operaciones_no_cumplidas': operacionesFallidas,
      'promedio': promedio,
      'resultado': resultado,
      'calculado_en': DateTime.now().toIso8601String(),
    },
    promedio,
    resultado,
  );
}

String _inicialesNombre(String n) {
  final p = n.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.length == 1 ? p.first[0] : p.first[0] + p[1][0]).toUpperCase();
}

/// Etiqueta pequeña con ícono para las tarjetas del historial.
class _ChipInfo extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  const _ChipInfo(this.icono, this.texto, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              texto,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      );
}

/// Ventana con los campos que faltan por diligenciar, agrupados por prueba.
class _DialogoFaltantes extends StatelessWidget {
  final String nombre;
  final String cedula;
  final _EstadoRegistro estado;
  final bool puedeEditar;
  final VoidCallback onCompletar;
  const _DialogoFaltantes({
    required this.nombre,
    required this.cedula,
    required this.estado,
    required this.puedeEditar,
    required this.onCompletar,
  });

  /// Agrupa "Pin Board: Destreza T1" → {"Pin Board": ["Destreza T1"]}.
  Map<String, List<String>> get _grupos {
    final g = <String, List<String>>{};
    for (final f in estado.faltantes) {
      final i = f.indexOf(': ');
      final grupo = i > 0 ? f.substring(0, i) : 'Datos generales';
      final campo = i > 0 ? f.substring(i + 2) : f;
      g.putIfAbsent(grupo, () => []).add(campo);
    }
    return g;
  }

  @override
  Widget build(BuildContext context) {
    final completo = estado.completo;
    final color = completo ? _kGreen : _kRojo;
    final grupos = _grupos;
    final alto = MediaQuery.of(context).size.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: alto * .82),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              color: color.withValues(alpha: .07),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: color,
                    child: Icon(
                      completo ? Icons.task_alt_rounded : Icons.playlist_remove_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          completo ? 'Registro completo' : 'Campos por diligenciar',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [if (nombre.isNotEmpty) nombre, if (cedula.isNotEmpty) 'C.C. $cedula']
                              .join(' · '),
                          style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Contenido
            Flexible(
              child: completo
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Todos los campos de este registro están diligenciados.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _kRojo.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Faltan ${estado.faltantes.length} campo(s) en ${grupos.length} sección(es).',
                            style: const TextStyle(color: _kRojo, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final e in grupos.entries) ...[
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _kBlue,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                ),
                              ),
                              Text(
                                '${e.value.length}',
                                style: TextStyle(
                                  color: Colors.blueGrey.shade500,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final campo in e.value)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F7FA),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE3E8EE)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.radio_button_unchecked, size: 13, color: _kRojo),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(campo, style: const TextStyle(fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
            ),
            // Botones
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ),
                  if (puedeEditar && !completo) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                        onPressed: onCompletar,
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Completar'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selector de pruebas alternativas: se pueden marcar hasta dos.
class _AlternativasSelector extends StatelessWidget {
  final List<String> opciones;
  final Set<String> seleccion;
  final int maximo;
  final ValueChanged<String> onChanged;
  const _AlternativasSelector({
    required this.opciones,
    required this.seleccion,
    required this.maximo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccion.isEmpty ? const Color(0xFFEF6C00) : const Color(0xFFBBD0F0),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.alt_route_outlined, size: 18, color: _kBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    maximo > 1 ? 'Pruebas a aplicar' : 'Prueba a aplicar',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF0D3B82),
                    ),
                  ),
                ),
                Text(
                  '${seleccion.length} / $maximo',
                  style: const TextStyle(color: _kBlue, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              maximo > 1 ? 'Elige una o dos pruebas.' : 'Elige una prueba.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in opciones)
                  FilterChip(
                    avatar: Icon(
                      _kIconoPrueba[k],
                      size: 18,
                      color: seleccion.contains(k) ? Colors.white : _kBlue,
                    ),
                    label: Text(_kNombrePrueba[k]!),
                    selected: seleccion.contains(k),
                    showCheckmark: false,
                    selectedColor: _kBlue,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: seleccion.contains(k) ? Colors.white : const Color(0xFF0D3B82),
                    ),
                    side: BorderSide(
                      color: seleccion.contains(k) ? _kBlue : const Color(0xFFBBD0F0),
                    ),
                    onSelected: (_) => onChanged(k),
                  ),
              ],
            ),
          ],
        ),
      );
}
