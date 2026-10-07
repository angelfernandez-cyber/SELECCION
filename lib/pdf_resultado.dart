import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Llena la plantilla "Pruebas de Selección" (Área de Selección) con los datos
/// de `app_resultado_pdf` y devuelve el PDF listo para imprimir o compartir.
///
/// La plantilla original está en assets/plantilla_pruebas_seleccion.jpg
/// (página carta, 612 × 792 puntos). Cada dato se escribe en su celda.
/// Se usa JPEG porque el PDF lo incrusta tal cual (sin decodificar ni
/// recomprimir), lo que hace la generación mucho más rápida.
const _kPlantilla = 'assets/plantilla_pruebas_seleccion.jpg';

/// Bytes de la plantilla en memoria (se cargan una sola vez).
Uint8List? _fondoCache;

Future<Uint8List> _fondo() async =>
    _fondoCache ??= (await rootBundle.load(_kPlantilla)).buffer.asUint8List();
const _kNegro = PdfColors.black;

const _kColumnas = [
  'pin_board',
  'destreza_fina',
  'speed_stack',
  'concentracion_conteo',
  'fit_brain',
  'habilidad_motora_gruesa',
  'prueba_campo',
];

class _Celda {
  final double x0, y0, x1, y1;
  final bool izquierda;
  const _Celda(this.x0, this.y0, this.x1, this.y1, {this.izquierda = false});
}

const _kCeldas = <String, _Celda>{
  'fecha': _Celda(95.0, 152.2, 257.0, 160.7, izquierda: true),
  'nombre': _Celda(95.0, 160.7, 257.0, 169.6, izquierda: true),
  'cedula': _Celda(95.0, 169.6, 257.0, 178.5, izquierda: true),
  'cargo': _Celda(95.0, 178.5, 257.0, 187.3, izquierda: true),
  'formador': _Celda(95.0, 187.3, 257.0, 196.2, izquierda: true),
  'nivel': _Celda(365.0, 152.2, 495.6, 170.1),
  'proceso': _Celda(365.0, 170.1, 495.6, 178.8),
  'lider': _Celda(365.0, 178.8, 495.6, 187.8),
  'aprobo': _Celda(365.0, 187.8, 495.6, 205.3),
  'pb_t1_d': _Celda(60.1, 243.1, 92.8, 250.8),
  'pb_t1_c': _Celda(92.8, 243.1, 125.8, 250.8),
  'pb_t2_d': _Celda(60.1, 250.8, 92.8, 258.5),
  'pb_t2_c': _Celda(92.8, 250.8, 125.8, 258.5),
  'pb_mt': _Celda(60.1, 258.5, 92.8, 274.1),
  'df_t1_d': _Celda(191.5, 243.1, 224.4, 250.8),
  'df_t1_c': _Celda(224.4, 243.1, 257.3, 250.8),
  'df_t2_d': _Celda(191.5, 250.8, 224.4, 258.5),
  'df_t2_c': _Celda(224.4, 250.8, 257.3, 258.5),
  'df_mt': _Celda(191.5, 258.5, 224.4, 274.1),
  'ss_t1_d': _Celda(322.9, 243.1, 364.2, 250.8),
  'ss_t1_c': _Celda(364.2, 243.1, 397.4, 250.8),
  'ss_t2_d': _Celda(322.9, 250.8, 364.2, 258.5),
  'ss_t2_c': _Celda(364.2, 250.8, 397.4, 258.5),
  'ss_mt': _Celda(322.9, 258.5, 364.2, 274.1),
  'fb_vel_t1': _Celda(463.2, 243.1, 495.8, 250.8),
  'fb_vel_t2': _Celda(495.8, 243.1, 528.8, 250.8),
  'fb_ac_t1': _Celda(463.2, 250.8, 495.8, 258.5),
  'fb_ac_t2': _Celda(495.8, 250.8, 528.8, 258.5),
  'hu_t1_d': _Celda(60.1, 314.3, 92.8, 322.1),
  'hu_t1_c': _Celda(92.8, 314.3, 125.8, 322.1),
  'hu_mt': _Celda(60.1, 322.1, 92.8, 336.3),
  'pa_prueba': _Celda(191.5, 306.8, 224.4, 314.4),
  'pa_t1_d': _Celda(191.5, 322.1, 224.4, 336.3),
  'pa_t1_c': _Celda(224.4, 322.1, 257.3, 336.3),
  'cc_t1_d': _Celda(322.9, 314.4, 364.2, 322.1),
  'cc_t1_c': _Celda(364.2, 314.4, 397.4, 322.1),
  'cc_mt': _Celda(322.9, 322.1, 364.2, 336.3),
  'suma': _Celda(486.0, 292.4, 560.0, 298.59999999999997, izquierda: true),
  'resta': _Celda(486.0, 299.9, 560.0, 306.09999999999997, izquierda: true),
  'mult': _Celda(486.0, 307.6, 560.0, 313.8, izquierda: true),
  'div': _Celda(486.0, 315.2, 560.0, 321.4, izquierda: true),
  'comp1_pin_board': _Celda(125.8, 470.0, 191.5, 492.0),
  'comp1_destreza_fina': _Celda(191.5, 470.0, 257.3, 492.0),
  'comp1_speed_stack': _Celda(257.3, 470.0, 322.8, 492.0),
  'comp1_concentracion_conteo': _Celda(322.8, 470.0, 397.4, 492.0),
  'comp1_fit_brain': _Celda(397.4, 470.0, 463.2, 492.0),
  'comp1_habilidad_motora_gruesa': _Celda(463.2, 470.0, 528.8, 492.0),
  'comp1_prueba_campo': _Celda(528.8, 470.0, 594.6, 492.0),
  'comp2_pin_board': _Celda(125.8, 492.0, 191.5, 514.0),
  'comp2_destreza_fina': _Celda(191.5, 492.0, 257.3, 514.0),
  'comp2_speed_stack': _Celda(257.3, 492.0, 322.8, 514.0),
  'comp2_concentracion_conteo': _Celda(322.8, 492.0, 397.4, 514.0),
  'comp2_fit_brain': _Celda(397.4, 492.0, 463.2, 514.0),
  'comp2_habilidad_motora_gruesa': _Celda(463.2, 492.0, 528.8, 514.0),
  'comp2_prueba_campo': _Celda(528.8, 492.0, 594.6, 514.0),
  'comp3_pin_board': _Celda(125.8, 514.0, 191.5, 536.0),
  'comp3_destreza_fina': _Celda(191.5, 514.0, 257.3, 536.0),
  'comp3_speed_stack': _Celda(257.3, 514.0, 322.8, 536.0),
  'comp3_concentracion_conteo': _Celda(322.8, 514.0, 397.4, 536.0),
  'comp3_fit_brain': _Celda(397.4, 514.0, 463.2, 536.0),
  'comp3_habilidad_motora_gruesa': _Celda(463.2, 514.0, 528.8, 536.0),
  'comp3_prueba_campo': _Celda(528.8, 514.0, 594.6, 536.0),
  'comp4_pin_board': _Celda(125.8, 536.0, 191.5, 563.0),
  'comp4_destreza_fina': _Celda(191.5, 536.0, 257.3, 563.0),
  'comp4_speed_stack': _Celda(257.3, 536.0, 322.8, 563.0),
  'comp4_concentracion_conteo': _Celda(322.8, 536.0, 397.4, 563.0),
  'comp4_fit_brain': _Celda(397.4, 536.0, 463.2, 563.0),
  'comp4_habilidad_motora_gruesa': _Celda(463.2, 536.0, 528.8, 563.0),
  'comp4_prueba_campo': _Celda(528.8, 536.0, 594.6, 563.0),
  'comp5_pin_board': _Celda(125.8, 563.0, 191.5, 585.0),
  'comp5_destreza_fina': _Celda(191.5, 563.0, 257.3, 585.0),
  'comp5_speed_stack': _Celda(257.3, 563.0, 322.8, 585.0),
  'comp5_concentracion_conteo': _Celda(322.8, 563.0, 397.4, 585.0),
  'comp5_fit_brain': _Celda(397.4, 563.0, 463.2, 585.0),
  'comp5_habilidad_motora_gruesa': _Celda(463.2, 563.0, 528.8, 585.0),
  'comp5_prueba_campo': _Celda(528.8, 563.0, 594.6, 585.0),
  'comp6_pin_board': _Celda(125.8, 585.0, 191.5, 607.0),
  'comp6_destreza_fina': _Celda(191.5, 585.0, 257.3, 607.0),
  'comp6_speed_stack': _Celda(257.3, 585.0, 322.8, 607.0),
  'comp6_concentracion_conteo': _Celda(322.8, 585.0, 397.4, 607.0),
  'comp6_fit_brain': _Celda(397.4, 585.0, 463.2, 607.0),
  'comp6_habilidad_motora_gruesa': _Celda(463.2, 585.0, 528.8, 607.0),
  'comp6_prueba_campo': _Celda(528.8, 585.0, 594.6, 607.0),
  'total_pin_board': _Celda(125.8, 607.0, 191.5, 620.0),
  'dyc_pin_board': _Celda(125.8, 635.2, 191.5, 649.1),
  'act_pin_board': _Celda(125.8, 649.1, 191.5, 663.0),
  'total_destreza_fina': _Celda(191.5, 607.0, 257.3, 620.0),
  'dyc_destreza_fina': _Celda(191.5, 635.2, 257.3, 649.1),
  'act_destreza_fina': _Celda(191.5, 649.1, 257.3, 663.0),
  'total_speed_stack': _Celda(257.3, 607.0, 322.8, 620.0),
  'dyc_speed_stack': _Celda(257.3, 635.2, 322.8, 649.1),
  'act_speed_stack': _Celda(257.3, 649.1, 322.8, 663.0),
  'total_concentracion_conteo': _Celda(322.8, 607.0, 397.4, 620.0),
  'dyc_concentracion_conteo': _Celda(322.8, 635.2, 397.4, 649.1),
  'act_concentracion_conteo': _Celda(322.8, 649.1, 397.4, 663.0),
  'total_fit_brain': _Celda(397.4, 607.0, 463.2, 620.0),
  'dyc_fit_brain': _Celda(397.4, 635.2, 463.2, 649.1),
  'act_fit_brain': _Celda(397.4, 649.1, 463.2, 663.0),
  'total_habilidad_motora_gruesa': _Celda(463.2, 607.0, 528.8, 620.0),
  'dyc_habilidad_motora_gruesa': _Celda(463.2, 635.2, 528.8, 649.1),
  'act_habilidad_motora_gruesa': _Celda(463.2, 649.1, 528.8, 663.0),
  'total_prueba_campo': _Celda(528.8, 607.0, 594.6, 620.0),
  'dyc_prueba_campo': _Celda(528.8, 635.2, 594.6, 649.1),
  'act_prueba_campo': _Celda(528.8, 649.1, 594.6, 663.0),
};

// ─── Formatos ───────────────────────────────────────────────────────────────
double? _num(dynamic v) => v == null ? null : double.tryParse(v.toString());

/// Segundos → 25" (menos de un minuto) o mm:ss.
String _tiempo(dynamic v) {
  final s = _num(v);
  if (s == null) return '';
  if (s < 60) {
    return s % 1 == 0 ? '${s.toInt()}"' : '${s.toStringAsFixed(1)}"';
  }
  return _mmss(s);
}

String _mmss(dynamic v) {
  final s = _num(v);
  if (s == null) return '';
  final total = s.round();
  return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
}

/// Segundos → minutos con decimales (prueba de campo), ej. 750 → "12,5 min".
String _minutos(dynamic v) {
  final s = _num(v);
  if (s == null) return '';
  var t = (s / 60).toStringAsFixed(2);
  t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '${t.replaceAll('.', ',')} min';
}

String _calidad(dynamic v) {
  final t = (v ?? '').toString().trim().toLowerCase();
  if (t.isEmpty) return '';
  if (t == 'ok' || t == 'true') return 'OK';
  if (t == '1' || t == '1.0') return '1';
  return t.toUpperCase();
}

String _entero(dynamic v) {
  final n = _num(v);
  return n == null ? '' : n.round().toString();
}

String _cumple(dynamic v) {
  final n = _num(v);
  if (n == null) return '';
  return n >= 1 ? 'Cumple' : 'No cumple';
}

double? _menor(dynamic a, dynamic b) {
  final x = _num(a), y = _num(b);
  if (x == null) return y;
  if (y == null) return x;
  return x <= y ? x : y;
}

String _fecha(dynamic v) {
  final d = DateTime.tryParse((v ?? '').toString());
  if (d == null) return (v ?? '').toString();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Convierte el JSON de `app_resultado_pdf` en {celda: texto}.
Map<String, String> valoresPlantilla(Map<String, dynamic> d) {
  final ig = _m(d['informacion_general']);
  final cf = _m(d['calificacion_final']);
  final pr = _m(d['pruebas']);
  final fb = _m(d['fit_brain']);
  final op = _m(d['operaciones']);
  final comp = _m(d['competencias']);
  final dyc = _m(d['destreza_y_calidad']);
  final act = _m(d['actitud']);
  final v = <String, String>{};

  v['fecha'] = _fecha(ig['fecha']);
  v['nombre'] = (ig['nombre_apellidos'] ?? '').toString();
  v['cedula'] = (ig['cedula'] ?? '').toString();
  v['cargo'] = (ig['cargo'] ?? '').toString();
  v['formador'] = (ig['formador'] ?? '').toString();

  final promedio = _num(cf['nivel']);
  v['nivel'] = promedio == null ? '' : promedio.toStringAsFixed(2).replaceAll('.', ',');
  v['proceso'] = (cf['proceso'] ?? '').toString();
  v['lider'] = (cf['lider_prueba'] ?? '').toString();
  final resultado = (cf['resultado'] ?? '').toString();
  v['aprobo'] = resultado == 'Aprobado'
      ? 'APROBADO'
      : resultado == 'Reprobado'
          ? 'DESAPROBADO'
          : '';

  void dosIntentos(String clave, String prueba) {
    final p = _m(pr[prueba]);
    v['${clave}_t1_d'] = _tiempo(p['t1_destreza']);
    v['${clave}_t1_c'] = _calidad(p['t1_calidad']);
    v['${clave}_t2_d'] = _tiempo(p['t2_destreza']);
    v['${clave}_t2_c'] = _calidad(p['t2_calidad']);
    v['${clave}_mt'] =
        _tiempo(p['mejor_tiempo'] ?? _menor(p['t1_destreza'], p['t2_destreza']));
  }

  dosIntentos('pb', 'pin_board');
  dosIntentos('df', 'destreza_fina');
  dosIntentos('ss', 'speed_stack');

  final fbv1 = _num(fb['t1_velocidad']), fbv2 = _num(fb['t2_velocidad']);
  v['fb_vel_t1'] = fbv1 == null ? '' : fbv1.toStringAsFixed(2);
  v['fb_vel_t2'] = fbv2 == null ? '' : fbv2.toStringAsFixed(2);
  final fba1 = _num(fb['t1_acierto']), fba2 = _num(fb['t2_acierto']);
  v['fb_ac_t1'] = fba1 == null ? '' : '${fba1 % 1 == 0 ? fba1.toInt() : fba1}%';
  v['fb_ac_t2'] = fba2 == null ? '' : '${fba2 % 1 == 0 ? fba2.toInt() : fba2}%';

  final hu = _m(pr['huester']);
  v['hu_t1_d'] = _tiempo(hu['t1_destreza']);
  v['hu_t1_c'] = _calidad(hu['t1_calidad']);
  v['hu_mt'] = _tiempo(hu['tiempo'] ?? hu['t1_destreza']);

  final pa = _m(pr['prueba_adicional']);
  v['pa_prueba'] = (pa['prueba'] ?? '').toString();
  v['pa_t1_d'] = _minutos(pa['t1_destreza']);
  v['pa_t1_c'] = _calidad(pa['t1_calidad']);

  final cc = _m(pr['concentracion_conteo']);
  v['cc_t1_d'] = _tiempo(cc['t1_destreza']);
  v['cc_t1_c'] = _calidad(cc['t1_calidad']);
  v['cc_mt'] = _tiempo(cc['mejor_tiempo'] ?? cc['t1_destreza']);

  v['suma'] = _cumple(op['suma']);
  v['resta'] = _cumple(op['resta']);
  v['mult'] = _cumple(op['multiplicacion']);
  v['div'] = _cumple(op['division']);

  final filas = (comp['filas'] as List?) ?? const [];
  for (var i = 0; i < filas.length && i < 6; i++) {
    final f = _m(filas[i]);
    for (final k in _kColumnas) {
      v['comp${i + 1}_$k'] = _entero(f[k]);
    }
  }
  final total = _m(comp['total']);
  for (final k in _kColumnas) {
    v['total_$k'] = _entero(total[k]);
    v['dyc_$k'] = _entero(dyc[k]);
    v['act_$k'] = _entero(act[k]);
  }
  return v;
}

/// Genera el PDF de la plantilla llena para un resultado.
Future<Uint8List> generarPdfResultado(Map<String, dynamic> datos) =>
    generarPdfResultados([datos]);

/// Genera un solo PDF con una página (plantilla llena) por cada resultado.
/// El armado se hace en segundo plano para no congelar la pantalla.
Future<Uint8List> generarPdfResultados(List<Map<String, dynamic>> lista) async {
  final fondo = await _fondo();
  return compute(_construirPdf, (fondo: fondo, lista: lista));
}

/// Precarga la plantilla (se puede llamar al abrir el módulo).
Future<void> precargarPlantillaPdf() => _fondo();

Future<Uint8List> _construirPdf(
  ({Uint8List fondo, List<Map<String, dynamic>> lista}) datosEntrada,
) async {
  final lista = datosEntrada.lista;
  final fondo = pw.MemoryImage(datosEntrada.fondo);
  final doc = pw.Document(
    compress: true,
    title: lista.length == 1
        ? 'Pruebas de Selección - ${_m(lista.first['informacion_general'])['nombre_apellidos'] ?? ''}'
        : 'Pruebas de Selección (${lista.length})',
    author: 'Cultivos La Planicie S.A.S.',
  );

  for (final datos in lista) {
    final valores = valoresPlantilla(datos);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Stack(
          children: [
            pw.Positioned.fill(child: pw.Image(fondo, fit: pw.BoxFit.fill)),
            for (final e in valores.entries)
              if (e.value.isNotEmpty && _kCeldas.containsKey(e.key))
                _texto(e.key, e.value, _kCeldas[e.key]!),
          ],
        ),
      ),
    );
  }
  return doc.save();
}

pw.Widget _texto(String clave, String texto, _Celda c) {
  final destacado = clave == 'nivel' || clave == 'aprobo';
  final alto = c.y1 - c.y0;
  final tam = destacado ? 10.0 : (alto < 9 ? 6.5 : 7.5);
  const color = _kNegro;
  return pw.Positioned(
    left: c.x0 + (c.izquierda ? 2 : 1),
    top: c.y0,
    child: pw.SizedBox(
      width: c.x1 - c.x0 - (c.izquierda ? 3 : 2),
      height: alto,
      child: pw.Align(
        alignment: c.izquierda ? pw.Alignment.centerLeft : pw.Alignment.center,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          child: pw.Text(
            texto,
            style: pw.TextStyle(
              fontSize: tam,
              color: color,
              fontWeight: destacado ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ),
    ),
  );
}
