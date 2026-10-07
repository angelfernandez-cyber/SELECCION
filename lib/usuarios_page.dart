import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_api.dart';

const _kAzul = Color(0xFF1565C0);
const _kAzulClaro = Color(0xFFE3ECFB);
const _kVerde = Color(0xFF2E7D32);
const _kRojo = Color(0xFFC62828);

/// Módulos a los que se puede dar acceso (los administradores ven todos).
/// 'datos' = Resultados de pruebas (permisos ver/registrar/editar_datos).
const _kModulos = [
  ('datos', 'Resultados de pruebas', 'Historial, filtros y formulario de pruebas.', Icons.dataset_outlined),
  ('exportar_pdf', 'Exportación e impresión PDF', 'Generar, imprimir y descargar la plantilla.', Icons.picture_as_pdf_outlined),
  ('respaldar_datos', 'Respaldo', 'Descargar respaldos y eliminar resultados.', Icons.backup_outlined),
];

/// Acciones dentro del módulo de Resultados.
const _kAccionesDatos = [
  ('registrar_datos', 'Registrar nuevos resultados', Icons.post_add_outlined),
  ('editar_datos', 'Editar resultados guardados', Icons.edit_note_outlined),
];

bool _tieneModulo(Map<String, dynamic> p, String modulo) => modulo == 'datos'
    ? (p['ver_datos'] == true || p['registrar_datos'] == true || p['editar_datos'] == true)
    : p[modulo] == true;

bool _esAdmin(Map<String, dynamic> u) =>
    u['admin'] == true ||
    const ['admin', 'administrador', 'superadmin']
        .contains(u['rol']?.toString().trim().toLowerCase());

String _iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return (partes.first[0] + partes[1][0]).toUpperCase();
}

String _limpiarError(Object e) => e.toString().replaceFirst('Exception: ', '');

// ─────────────────────────────────────────────────────────────────────────────
//  Lista de usuarios
// ─────────────────────────────────────────────────────────────────────────────
class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});
  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  final _buscar = TextEditingController();
  String _filtro = 'todos'; // todos | activos | inactivos | admins
  final Set<String> _cambiando = {};

  String? get _miId => AppApi.usuario?['id']?.toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _users = await AppApi.usuarios();
    } catch (e) {
      _error = _limpiarError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _visibles {
    final q = _buscar.text.trim().toLowerCase();
    return _users.where((u) {
      final activo = u['activo'] == true;
      final pasaFiltro = switch (_filtro) {
        'activos' => activo,
        'inactivos' => !activo,
        'admins' => _esAdmin(u),
        _ => true,
      };
      if (!pasaFiltro) return false;
      if (q.isEmpty) return true;
      return [u['nombre'], u['correo'], u['numero_documento']]
          .any((v) => (v ?? '').toString().toLowerCase().contains(q));
    }).toList();
  }

  void _mensaje(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? _kRojo : null,
      ),
    );
  }

  Future<void> _abrirFormulario([Map<String, dynamic>? user]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _UsuarioFormPage(user: user)),
    );
    if (ok == true) {
      _mensaje(user == null ? 'Usuario creado.' : 'Cambios guardados.');
      _load();
    }
  }

  Future<void> _cambiarActivo(Map<String, dynamic> u, bool activo) async {
    final id = u['id'].toString();
    setState(() => _cambiando.add(id));
    try {
      await AppApi.guardarUsuario(
        id: id,
        nombre: u['nombre']?.toString() ?? '',
        correo: u['correo']?.toString() ?? '',
        contrasena: '',
        activo: activo,
        permisos: Map<String, dynamic>.from(u['permisos'] ?? {}),
        numeroDocumento: u['numero_documento']?.toString(),
      );
      u['activo'] = activo;
      _mensaje(activo ? '${u['nombre']} puede iniciar sesión.' : '${u['nombre']} quedó sin acceso.');
    } catch (e) {
      _mensaje(_limpiarError(e), error: true);
    }
    if (mounted) setState(() => _cambiando.remove(id));
  }

  Future<void> _eliminar(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: _kRojo, size: 36),
        title: const Text('Eliminar usuario'),
        content: Text(
          '¿Deseas eliminar a ${u['nombre']}?\n\nLos resultados que registró se conservan. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kRojo),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppApi.eliminarUsuario(u['id'].toString());
      _mensaje('Usuario eliminado.');
      await _load();
    } catch (e) {
      _mensaje(_limpiarError(e), error: true);
    }
  }

  Widget _resumen() {
    final activos = _users.where((u) => u['activo'] == true).length;
    final admins = _users.where(_esAdmin).length;
    Widget dato(String n, String t, IconData i, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(i, color: Colors.white, size: 20),
                const SizedBox(height: 4),
                Text(n, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                Text(t, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
              ],
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          dato('${_users.length}', 'Usuarios', Icons.groups_outlined, Colors.white),
          const SizedBox(width: 8),
          dato('$activos', 'Activos', Icons.check_circle_outline, Colors.white),
          const SizedBox(width: 8),
          dato('$admins', 'Administradores', Icons.admin_panel_settings_outlined, Colors.white),
        ],
      ),
    );
  }

  Widget _barraBusqueda() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          children: [
            TextField(
              controller: _buscar,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Buscar por nombre, correo o documento',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _buscar.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_buscar.clear),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in const [
                    ('todos', 'Todos'),
                    ('activos', 'Activos'),
                    ('inactivos', 'Sin acceso'),
                    ('admins', 'Administradores'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: _filtro == f.$1,
                        onSelected: (_) => setState(() => _filtro = f.$1),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _tarjeta(Map<String, dynamic> u) {
    final id = u['id'].toString();
    final soyYo = id == _miId;
    final admin = _esAdmin(u);
    final activo = u['activo'] == true;
    final permisos = Map<String, dynamic>.from(u['permisos'] ?? {});
    final nombre = u['nombre']?.toString() ?? '';
    final documento = u['numero_documento']?.toString() ?? '';
    final colorAvatar = !activo ? Colors.grey : (admin ? _kAzul : _kVerde);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: activo ? const Color(0xFFBBD0F0) : const Color(0xFFE0E0E0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirFormulario(u),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colorAvatar.withValues(alpha: .12),
                    child: Text(
                      _iniciales(nombre),
                      style: TextStyle(color: colorAvatar, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              nombre,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                color: activo ? null : Colors.grey.shade600,
                              ),
                            ),
                            if (soyYo) const _Etiqueta('Tú', _kAzul),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          u['correo']?.toString() ?? '',
                          style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (documento.isNotEmpty)
                          Text(
                            'Doc. $documento',
                            style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12.5),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      _cambiando.contains(id)
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Switch(
                              value: activo,
                              onChanged: soyYo ? null : (v) => _cambiarActivo(u, v),
                            ),
                      Text(
                        activo ? 'Activo' : 'Sin acceso',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: activo ? _kVerde : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          admin
                              ? const _Etiqueta('Administrador · acceso total', _kAzul,
                                  icono: Icons.admin_panel_settings_outlined)
                              : const _Etiqueta('Usuario', Colors.blueGrey, icono: Icons.person_outline),
                          if (!admin)
                            for (final m in _kModulos)
                              if (_tieneModulo(permisos, m.$1))
                                _Etiqueta(
                                  m.$1 == 'datos' ? 'Resultados' : (m.$1 == 'exportar_pdf' ? 'PDF' : m.$2),
                                  _kVerde,
                                  icono: m.$4,
                                ),
                          if (!admin && !_kModulos.any((m) => _tieneModulo(permisos, m.$1)))
                            const _Etiqueta('Sin módulos', _kRojo, icono: Icons.block),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Opciones',
                      onSelected: (a) {
                        if (a == 'editar') _abrirFormulario(u);
                        if (a == 'eliminar') _eliminar(u);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'editar',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Editar'),
                          ),
                        ),
                        if (!soyYo)
                          const PopupMenuItem(
                            value: 'eliminar',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.delete_outline, color: _kRojo),
                              title: Text('Eliminar', style: TextStyle(color: _kRojo)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget cuerpo;
    if (_loading) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      cuerpo = Center(
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
    } else {
      final lista = _visibles;
      cuerpo = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _resumen(),
            _barraBusqueda(),
            const SizedBox(height: 8),
            if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No hay usuarios con ese filtro.')),
              )
            else
              for (final u in lista)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 9),
                  child: _tarjeta(u),
                ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(onPressed: _load, tooltip: 'Actualizar', icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo usuario'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: cuerpo,
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData? icono;
  const _Etiqueta(this.texto, this.color, {this.icono});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(texto, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Formulario de usuario (crear / editar)
// ─────────────────────────────────────────────────────────────────────────────
class _UsuarioFormPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  const _UsuarioFormPage({this.user});
  @override
  State<_UsuarioFormPage> createState() => _UsuarioFormPageState();
}

class _UsuarioFormPageState extends State<_UsuarioFormPage> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.user?['nombre']?.toString());
  late final _correo = TextEditingController(text: widget.user?['correo']?.toString());
  late final _documento =
      TextEditingController(text: widget.user?['numero_documento']?.toString());
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  bool _verClave = false;
  late bool _activo = widget.user?['activo'] != false;
  late bool _admin = widget.user != null && _esAdmin(widget.user!);
  late final Map<String, bool> _permisos = {
    'ver_datos': true,
    'registrar_datos': true,
    'editar_datos': false,
    'exportar_pdf': true,
    'respaldar_datos': false,
    ...Map<String, dynamic>.from(widget.user?['permisos'] ?? {})
        .map((k, v) => MapEntry(k, v == true)),
  };
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.user != null;
  bool get _soyYo => _editando && widget.user!['id']?.toString() == AppApi.usuario?['id']?.toString();

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _documento.dispose();
    _clave.dispose();
    _clave2.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await AppApi.guardarUsuario(
        id: widget.user?['id']?.toString(),
        nombre: _nombre.text.trim(),
        correo: _correo.text.trim(),
        contrasena: _clave.text,
        activo: _activo,
        permisos: _permisos,
        rol: _admin ? 'admin' : 'usuario',
        numeroDocumento: _documento.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = _limpiarError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _seccion(String titulo, IconData icono, List<Widget> hijos) => Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFBBD0F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icono, color: _kAzul, size: 20),
                  const SizedBox(width: 8),
                  Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 14),
              ...hijos,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_editando ? 'Editar usuario' : 'Nuevo usuario')),
        body: Form(
          key: _form,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kRojo.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kRojo.withValues(alpha: .4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: _kRojo),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!, style: const TextStyle(color: _kRojo))),
                        ],
                      ),
                    ),
                  _seccion('Datos personales', Icons.badge_outlined, [
                    TextFormField(
                      controller: _nombre,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe el nombre completo' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _documento,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Número de documento (opcional)',
                        prefixIcon: Icon(Icons.credit_card_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Correo (para iniciar sesión)',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim())
                          ? null
                          : 'Escribe un correo válido',
                    ),
                  ]),
                  _seccion('Acceso', Icons.lock_outline, [
                    TextFormField(
                      controller: _clave,
                      obscureText: !_verClave,
                      decoration: InputDecoration(
                        labelText: _editando ? 'Nueva contraseña (opcional)' : 'Contraseña',
                        helperText: _editando ? 'Déjala vacía para no cambiarla.' : 'Mínimo 4 caracteres.',
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _verClave = !_verClave),
                        ),
                      ),
                      validator: (v) {
                        final t = v ?? '';
                        if (!_editando && t.isEmpty) return 'La contraseña es obligatoria';
                        if (t.isNotEmpty && t.length < 4) return 'Mínimo 4 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clave2,
                      obscureText: !_verClave,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      validator: (v) => (_clave.text.isNotEmpty && v != _clave.text)
                          ? 'Las contraseñas no coinciden'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Rol', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Usuario'), icon: Icon(Icons.person_outline)),
                        ButtonSegment(
                          value: true,
                          label: Text('Administrador'),
                          icon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                      ],
                      selected: {_admin},
                      onSelectionChanged: _soyYo ? null : (s) => setState(() => _admin = s.first),
                    ),
                    if (_soyYo)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'No puedes cambiar tu propio rol ni desactivar tu cuenta.',
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
                        ),
                      ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cuenta activa'),
                      subtitle: Text(_activo ? 'Puede iniciar sesión' : 'No puede iniciar sesión'),
                      value: _activo,
                      onChanged: _soyYo ? null : (v) => setState(() => _activo = v),
                    ),
                  ]),
                  _seccion('Acceso a módulos', Icons.apps_outlined, [
                    if (_admin)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kAzulClaro,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: _kAzul),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Los administradores entran a todos los módulos: Resultados, '
                                'Exportación PDF, Respaldo y Usuarios.',
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      for (final m in _kModulos) ...[
                        _ModuloTile(
                          icono: m.$4,
                          titulo: m.$2,
                          descripcion: m.$3,
                          activo: _tieneModulo(_permisos, m.$1),
                          onChanged: (v) => setState(() {
                            if (m.$1 == 'datos') {
                              _permisos['ver_datos'] = v;
                              if (!v) {
                                _permisos['registrar_datos'] = false;
                                _permisos['editar_datos'] = false;
                              }
                            } else {
                              _permisos[m.$1] = v;
                            }
                          }),
                        ),
                        if (m.$1 == 'datos' && _tieneModulo(_permisos, 'datos'))
                          Container(
                            margin: const EdgeInsets.only(left: 18, bottom: 8),
                            padding: const EdgeInsets.only(left: 12),
                            decoration: const BoxDecoration(
                              border: Border(left: BorderSide(color: Color(0xFFBBD0F0), width: 2)),
                            ),
                            child: Column(
                              children: [
                                for (final a in _kAccionesDatos)
                                  CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    secondary: Icon(a.$3, size: 20, color: Colors.blueGrey),
                                    title: Text(a.$2),
                                    value: _permisos[a.$1] ?? false,
                                    onChanged: (v) => setState(() {
                                      _permisos[a.$1] = v ?? false;
                                      _permisos['ver_datos'] = true;
                                    }),
                                  ),
                              ],
                            ),
                          ),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 16, color: Colors.blueGrey.shade400),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'El módulo Usuarios solo lo ven los administradores.',
                                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_editando ? 'Guardar cambios' : 'Crear usuario',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Fila de un módulo con su interruptor de acceso.
class _ModuloTile extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final bool activo;
  final ValueChanged<bool> onChanged;
  const _ModuloTile({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.activo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: activo ? _kAzulClaro : const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: activo ? _kAzul.withValues(alpha: .4) : const Color(0xFFE3E8EE)),
        ),
        child: SwitchListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          secondary: CircleAvatar(
            backgroundColor: activo ? _kAzul : Colors.blueGrey.shade100,
            child: Icon(icono, color: activo ? Colors.white : Colors.blueGrey, size: 20),
          ),
          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(descripcion),
          value: activo,
          onChanged: onChanged,
        ),
      );
}
