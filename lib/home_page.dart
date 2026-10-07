import 'package:flutter/material.dart';

import 'app_api.dart';
import 'datos_page.dart';
import 'exportacion_page.dart';
import 'login_page.dart';
import 'respaldo_page.dart';
import 'usuarios_page.dart';

const _kLogo = 'lib/img/logoapli.png';
const _kTeal = Color(0xFF1F8A99);
const _kVerde = Color(0xFF2E7D32);
const _kAzul = Color(0xFF1565C0);
const _kRojo = Color(0xFFC62828);
const _kNaranja = Color(0xFFEF6C00);

const _kDias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _kMeses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PaginaResultados? _resumen;
  bool _cargandoResumen = false;

  Map<String, dynamic> get _permisos => AppApi.permisos;
  bool get _admin => AppApi.esAdmin;
  bool get _accesoDatos =>
      _admin ||
      _permisos['ver_datos'] == true ||
      _permisos['registrar_datos'] == true ||
      _permisos['editar_datos'] == true;
  bool get _accesoPdf => _admin || _permisos['exportar_pdf'] == true;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    if (!_accesoDatos && !_accesoPdf) return;
    setState(() => _cargandoResumen = true);
    try {
      final r = await AppApi.resultadosPaginados(limite: 1);
      if (mounted) setState(() => _resumen = r);
    } catch (_) {}
    if (mounted) setState(() => _cargandoResumen = false);
  }

  List<_Modulo> get _modulos => [
        _Modulo(
          'Resultados de pruebas',
          'Historial, filtros y formulario de Pruebas de Selección.',
          Icons.dataset_outlined,
          _kAzul,
          _accesoDatos,
          () => const DatosPage(),
        ),
        _Modulo(
          'Exportación e impresión PDF',
          'Llena la plantilla oficial para imprimir o compartir.',
          Icons.picture_as_pdf_outlined,
          _kRojo,
          _accesoPdf,
          () => const ExportacionPage(),
        ),
        _Modulo(
          'Respaldo',
          'Descarga una copia de los resultados antes de limpiar.',
          Icons.backup_outlined,
          _kTeal,
          _admin || _permisos['respaldar_datos'] == true,
          () => const RespaldoPage(),
        ),
        _Modulo(
          'Usuarios',
          'Cuentas, roles y acceso a los módulos.',
          Icons.manage_accounts_outlined,
          _kVerde,
          _admin,
          () => const UsuariosPage(),
        ),
      ];

  Future<void> _abrir(_Modulo m) async {
    if (!m.permitido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu cuenta no tiene acceso a este módulo. Pídelo a un administrador.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => m.pagina()));
    if (mounted) setState(() {}); // por si cambió el nombre del usuario
    _cargarResumen();
  }

  Future<void> _salir() async {
    final nombre = (AppApi.usuario?['nombre'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _kRojo.withValues(alpha: .1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: _kRojo, size: 30),
                ),
                const SizedBox(height: 16),
                const Text(
                  '¿Cerrar sesión?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  nombre.isEmpty
                      ? 'Tendrás que ingresar de nuevo con tu correo y contraseña.'
                      : '$nombre, tendrás que ingresar de nuevo con tu correo y contraseña.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey.shade600, height: 1.35),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _kRojo,
                          minimumSize: const Size.fromHeight(46),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Salir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    AppApi.cerrarSesion();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _fecha() {
    final d = DateTime.now();
    return '${_kDias[d.weekday - 1]}, ${d.day} de ${_kMeses[d.month - 1]} de ${d.year}';
  }

  String _iniciales(String n) {
    final p = n.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.length == 1 ? p.first[0] : p.first[0] + p[1][0]).toUpperCase();
  }

  // ─── Encabezado ────────────────────────────────────────────────────────
  Widget _encabezado() {
    final user = AppApi.usuario ?? {};
    final nombre = (user['nombre'] ?? 'Usuario').toString();
    final primerNombre = nombre.trim().split(RegExp(r'\s+')).first;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), _kTeal, _kVerde],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 26),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: ClipOval(child: Image.asset(_kLogo, fit: BoxFit.cover)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'La Planicie',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Pruebas de Selección',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        onPressed: _salir,
                        icon: const Icon(Icons.logout_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white.withValues(alpha: .2),
                        child: Text(
                          _iniciales(nombre),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_saludo()}, $primerNombre',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _fecha(),
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _admin ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _admin ? 'Administrador' : 'Usuario',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Resumen de resultados ─────────────────────────────────────────────
  Widget _indicadores() {
    if (!_accesoDatos && !_accesoPdf) return const SizedBox.shrink();
    final r = _resumen;
    Widget dato(String titulo, int? valor, IconData icono, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3E9F2)),
            ),
            child: Column(
              children: [
                Icon(icono, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  valor == null ? '—' : '$valor',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
                ),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade600),
                ),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Resumen', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            if (_cargandoResumen)
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const Spacer(),
            IconButton(
              tooltip: 'Actualizar',
              visualDensity: VisualDensity.compact,
              onPressed: _cargarResumen,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            dato('Evaluados', r?.total, Icons.people_alt_outlined, _kAzul),
            const SizedBox(width: 8),
            dato('Aprobados', r?.aprobados, Icons.verified_outlined, _kVerde),
            const SizedBox(width: 8),
            dato('Desaprobados', r?.desaprobados, Icons.cancel_outlined, _kRojo),
            const SizedBox(width: 8),
            dato('Campo pendiente', r?.pendientes, Icons.grass_outlined, _kNaranja),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Módulos ───────────────────────────────────────────────────────────
  Widget _modulosGrid() => LayoutBuilder(
        builder: (context, c) {
          final columnas = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
          const sep = 12.0;
          final ancho = (c.maxWidth - sep * (columnas - 1)) / columnas;
          return Wrap(
            spacing: sep,
            runSpacing: sep,
            children: [
              for (final m in _modulos)
                SizedBox(
                  width: ancho,
                  child: _TarjetaModulo(
                    modulo: m,
                    compacta: columnas == 1,
                    onTap: () => _abrir(m),
                  ),
                ),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF0F4FA),
        body: RefreshIndicator(
          onRefresh: _cargarResumen,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _encabezado(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _indicadores(),
                        const Text(
                          'Módulos',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        _modulosGrid(),
                        const SizedBox(height: 28),
                        Center(
                          child: Text(
                            'Cultivos La Planicie S.A.S. · Área de Selección',
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Modulo {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Color color;
  final bool permitido;
  final Widget Function() pagina;
  const _Modulo(
    this.titulo,
    this.descripcion,
    this.icono,
    this.color,
    this.permitido,
    this.pagina,
  );
}

class _TarjetaModulo extends StatelessWidget {
  final _Modulo modulo;
  final bool compacta;
  final VoidCallback onTap;
  const _TarjetaModulo({required this.modulo, required this.compacta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = modulo;
    final color = m.permitido ? m.color : Colors.blueGrey.shade300;
    final icono = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: m.permitido
            ? LinearGradient(colors: [color, Color.lerp(color, Colors.white, .25)!])
            : null,
        color: m.permitido ? null : const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        m.permitido ? m.icono : Icons.lock_outline,
        color: m.permitido ? Colors.white : Colors.blueGrey.shade300,
        size: 26,
      ),
    );
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          m.titulo,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: m.permitido ? const Color(0xFF1B2733) : Colors.blueGrey.shade400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          m.permitido ? m.descripcion : 'Sin acceso · pídelo a un administrador',
          style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13, height: 1.3),
        ),
      ],
    );
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: m.permitido ? color.withValues(alpha: .25) : const Color(0xFFE3E9F2),
            ),
          ),
          child: compacta
              ? Row(
                  children: [
                    icono,
                    const SizedBox(width: 14),
                    Expanded(child: textos),
                    Icon(
                      m.permitido ? Icons.chevron_right_rounded : Icons.lock_outline,
                      color: color,
                    ),
                  ],
                )
              : SizedBox(
                  height: 170,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icono,
                      const SizedBox(height: 14),
                      Expanded(child: textos),
                      Row(
                        children: [
                          Text(
                            m.permitido ? 'Abrir' : 'Sin acceso',
                            style: TextStyle(color: color, fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_forward_rounded, size: 19, color: color),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
