import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_config.dart';

class AppApi {
  static String? correo;
  static String? contrasena;
  static Map<String, dynamic>? usuario;

  static bool get esAdmin => usuario?['admin'] == true;
  static Map<String, dynamic> get permisos =>
      Map<String, dynamic>.from(usuario?['permisos'] ?? const {});

  static Future<dynamic> rpc(String function, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${SupabaseConfig.url}/rest/v1/rpc/$function'),
      headers: {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_error(response.body, response.statusCode));
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> iniciarSesion(
    String email,
    String password,
  ) async {
    final result = await rpc('app_iniciar_sesion', {
      'p_correo': email.trim(),
      'p_contrasena': password,
    });
    if (result is! Map) throw Exception('Correo o contraseña incorrectos.');
    correo = email.trim();
    contrasena = password;
    usuario = Map<String, dynamic>.from(result);
    return usuario!;
  }

  static Map<String, dynamic> get credenciales => {
    'p_actor_correo': correo,
    'p_actor_contrasena': contrasena,
  };

  static Future<List<Map<String, dynamic>>> usuarios() async {
    final result = await rpc('app_listar_usuarios', credenciales);
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// Crea o actualiza un usuario. [rol]: 'usuario' | 'admin' (null = no cambia).
  static Future<void> guardarUsuario({
    String? id,
    required String nombre,
    required String correo,
    required String contrasena,
    required bool activo,
    required Map<String, dynamic> permisos,
    String? rol,
    String? numeroDocumento,
  }) async {
    await rpc('app_guardar_usuario', {
      ...credenciales,
      'p_id': id,
      'p_nombre': nombre,
      'p_correo': correo,
      'p_contrasena': contrasena,
      'p_activo': activo,
      'p_permisos': permisos,
      'p_rol': rol,
      'p_numero_documento': numeroDocumento,
    });
    // Si el administrador se editó a sí mismo, actualiza la sesión.
    if (id != null && id == usuario?['id']?.toString()) {
      AppApi.correo = correo.trim().toLowerCase();
      if (contrasena.trim().isNotEmpty) AppApi.contrasena = contrasena;
      usuario = {...?usuario, 'nombre': nombre.trim(), 'correo': AppApi.correo};
    }
  }

  static Future<void> eliminarUsuario(String id) async {
    await rpc('app_eliminar_usuario', {...credenciales, 'p_id': id});
  }

  static Future<List<Map<String, dynamic>>> registros() async {
    final result = await rpc('app_listar_resultados', credenciales);
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// Historial paginado con filtros (fecha, cédula y estado de Prueba de Campo).
  /// [estadoCampo]: 'completo', 'pendiente' o null para todos.
  static Future<PaginaResultados> resultadosPaginados({
    DateTime? desde,
    DateTime? hasta,
    String? cedula,
    String? estadoCampo,
    String? resultado,
    int limite = 20,
    int offset = 0,
  }) async {
    String? fecha(DateTime? d) => d == null
        ? null
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final result = await rpc('app_listar_resultados_pag', {
      ...credenciales,
      'p_desde': fecha(desde),
      'p_hasta': fecha(hasta),
      'p_cedula': (cedula ?? '').trim().isEmpty ? null : cedula!.trim(),
      'p_estado_campo': estadoCampo,
      'p_limite': limite,
      'p_offset': offset,
      'p_resultado': resultado,
    });
    final map = Map<String, dynamic>.from(result as Map);
    return PaginaResultados(
      total: (map['total'] as num?)?.toInt() ?? 0,
      completos: (map['completos'] as num?)?.toInt() ?? 0,
      pendientes: (map['pendientes'] as num?)?.toInt() ?? 0,
      aprobados: (map['aprobados'] as num?)?.toInt() ?? 0,
      desaprobados: (map['desaprobados'] as num?)?.toInt() ?? 0,
      sinCalcular: (map['sin_calcular'] as num?)?.toInt() ?? 0,
      filas: (map['filas'] as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
    );
  }

  /// Guarda (inserta o actualiza) un resultado de prueba.
  /// Devuelve el id del resultado guardado.
  static Future<String?> guardarResultado({
    String? id,
    required String fecha,
    required String nombre,
    required String apellido,
    required String cedula,
    String? area,
    String? genero,
    String? formador,
    String? proceso,
    String? liderPrueba,
    double? pinBoardDestrezaT1,
    double? pinBoardDestrezaT2,
    String? pinBoardCalidadT1,
    String? pinBoardCalidadT2,
    double? destrezaFinaDestrezaT1,
    double? destrezaFinaDestrezaT2,
    String? destrezaFinaCalidadT1,
    String? destrezaFinaCalidadT2,
    double? speedStackDestrezaT1,
    double? speedStackDestrezaT2,
    String? speedStackCalidadT1,
    String? speedStackCalidadT2,
    double? fitBrainVelocidadT1,
    double? fitBrainVelocidadT2,
    double? fitBrainPorcentajeT1,
    double? fitBrainPorcentajeT2,
    double? habilidadMgrDestrezaT1,
    String? habilidadMgrCalidadT1,
    double? pruebaCampoDestrezaT1,
    String? pruebaCampoCalidadT1,
    double? concentracionDestrezaT1,
    String? concentracionCalidadT1,
    double? suma,
    double? resta,
    double? multiplicacion,
    double? division,
    Map<String, dynamic>? competencias,
  }) async {
    final result = await rpc('app_guardar_resultado', {
      ...credenciales,
      'p_id': id,
      'p_fecha': fecha,
      'p_nombre': nombre,
      'p_apellido': apellido,
      'p_cedula': cedula,
      'p_area': area,
      'p_genero': genero,
      'p_formador': formador,
      'p_proceso': proceso,
      'p_lider_prueba': liderPrueba,
      'p_pin_board_destreza_t1': pinBoardDestrezaT1,
      'p_pin_board_destreza_t2': pinBoardDestrezaT2,
      'p_pin_board_calidad_t1': pinBoardCalidadT1,
      'p_pin_board_calidad_t2': pinBoardCalidadT2,
      'p_destreza_fina_destreza_t1': destrezaFinaDestrezaT1,
      'p_destreza_fina_destreza_t2': destrezaFinaDestrezaT2,
      'p_destreza_fina_calidad_t1': destrezaFinaCalidadT1,
      'p_destreza_fina_calidad_t2': destrezaFinaCalidadT2,
      'p_speed_stack_destreza_t1': speedStackDestrezaT1,
      'p_speed_stack_destreza_t2': speedStackDestrezaT2,
      'p_speed_stack_calidad_t1': speedStackCalidadT1,
      'p_speed_stack_calidad_t2': speedStackCalidadT2,
      'p_fit_brain_velocidad_t1': fitBrainVelocidadT1,
      'p_fit_brain_velocidad_t2': fitBrainVelocidadT2,
      'p_fit_brain_porcentaje_acierto_t1': fitBrainPorcentajeT1,
      'p_fit_brain_porcentaje_acierto_t2': fitBrainPorcentajeT2,
      'p_habilidad_motora_gruesa_destreza_t1': habilidadMgrDestrezaT1,
      'p_habilidad_motora_gruesa_calidad_t1': habilidadMgrCalidadT1,
      'p_prueba_campo_destreza_t1': pruebaCampoDestrezaT1,
      'p_prueba_campo_calidad_t1': pruebaCampoCalidadT1,
      'p_concentracion_conteo_destreza_t1': concentracionDestrezaT1,
      'p_concentracion_conteo_calidad_t1': concentracionCalidadT1,
      'p_suma': suma,
      'p_resta': resta,
      'p_multiplicacion': multiplicacion,
      'p_division': division,
      if (competencias != null) 'p_competencias': competencias,
    });
    return result?.toString() ?? id;
  }

  /// Datos de un resultado organizados como la plantilla PDF de Pruebas de
  /// Selección (información general, pruebas, competencias, niveles y si aprobó).
  static Future<Map<String, dynamic>> resultadoPdf(String id) async {
    final result = await rpc('app_resultado_pdf', {...credenciales, 'p_id': id});
    return Map<String, dynamic>.from(result as Map);
  }

  /// Guarda los niveles calculados (vista Proceso), el promedio y el resultado.
  static Future<void> guardarNiveles({
    required String id,
    required Map<String, dynamic> niveles,
    double? promedio,
    String? resultado,
    String? pruebaCampoTipo,
  }) async {
    await rpc('app_guardar_niveles', {
      ...credenciales,
      'p_id': id,
      'p_niveles': niveles,
      'p_promedio': promedio == null ? null : double.parse(promedio.toStringAsFixed(2)),
      'p_resultado': resultado,
      'p_prueba_campo_tipo': pruebaCampoTipo,
    });
  }

  static Future<List<Map<String, dynamic>>> respaldoRegistros() async {
    final result = await rpc('app_respaldo_resultados', credenciales);
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// Almacenamiento de la base de datos en Supabase (usado, límite del plan…).
  static Future<Map<String, dynamic>> almacenamiento() async {
    final result = await rpc('app_almacenamiento', credenciales);
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<void> eliminarRegistros() async {
    await rpc('app_eliminar_resultados', credenciales);
  }

  static void cerrarSesion() {
    correo = null;
    contrasena = null;
    usuario = null;
  }

  static String _error(String body, int status) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        final message = decoded['message'].toString();
        if (message.contains('function') || message.contains('schema cache')) {
          return 'Falta ejecutar supabase/resultados_v2.sql en Supabase.';
        }
        return message;
      }
    } catch (_) {}
    return 'Error de Supabase ($status).';
  }
}

class PaginaResultados {
  final int total;
  final int completos;
  final int pendientes;
  final int aprobados;
  final int desaprobados;
  final int sinCalcular;
  final List<Map<String, dynamic>> filas;
  const PaginaResultados({
    required this.total,
    required this.completos,
    required this.pendientes,
    this.aprobados = 0,
    this.desaprobados = 0,
    this.sinCalcular = 0,
    required this.filas,
  });
}
