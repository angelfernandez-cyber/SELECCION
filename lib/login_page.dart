import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_api.dart';
import 'home_page.dart';

const _kLogo = 'lib/img/logoapli.png';
const _kTeal = Color(0xFF1F8A99);
const _kVerde = Color(0xFF2E7D32);
const _kAzul = Color(0xFF1565C0);
const _kFondo = Color(0xFFF0F4FA);
const _kClaveCorreo = 'login_correo_recordado';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _hidePassword = true;
  bool _recordar = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCorreo();
  }

  Future<void> _cargarCorreo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final correo = prefs.getString(_kClaveCorreo);
      if (correo != null && mounted) {
        setState(() => _email.text = correo);
      }
    } catch (_) {}
  }

  Future<void> _guardarCorreo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_recordar) {
        await prefs.setString(_kClaveCorreo, _email.text.trim());
      } else {
        await prefs.remove(_kClaveCorreo);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Escribe tu correo y tu contraseña.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppApi.iniciarSesion(_email.text, _password.text);
      await _guardarCorreo();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, _, _) => const HomePage(),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ),
      );
    } catch (error) {
      final msg = error.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        setState(() => _error = msg.contains('incorrectos') || msg.contains('Sesión')
            ? 'Correo o contraseña incorrectos, o la cuenta está inactiva.'
            : msg.contains('Failed host lookup') || msg.contains('SocketException')
                ? 'No hay conexión a internet.'
                : msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Marca (logo + nombre) ─────────────────────────────────────────────
  Widget _logo(double tam) => Container(
        width: tam,
        height: tam,
        padding: EdgeInsets.all(tam * .08),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipOval(child: Image.asset(_kLogo, fit: BoxFit.cover)),
      );

  Widget _marca({required bool clara, double logo = 112}) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _logo(logo),
          const SizedBox(height: 18),
          Text(
            'La Planicie',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
              color: clara ? Colors.white : _kTeal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'CULTIVOS LA PLANICIE S.A.S.',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: clara ? Colors.white70 : Colors.blueGrey.shade500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: clara ? Colors.white.withValues(alpha: .18) : _kTeal.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Gestión Humana · Pruebas de Selección',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: clara ? Colors.white : _kTeal,
              ),
            ),
          ),
        ],
      );

  // ─── Formulario ────────────────────────────────────────────────────────
  Widget _formulario() => Card(
        elevation: 0,
        color: Colors.white,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE3E9F2)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bienvenido',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ingresa con tu cuenta para continuar.',
                  style: TextStyle(color: Colors.blueGrey.shade600),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword ? 'Mostrar' : 'Ocultar',
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(_hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _recordar = !_recordar),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _recordar,
                        onChanged: (v) => setState(() => _recordar = v ?? false),
                      ),
                      const Text('Recordar mi correo'),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _error == null
                      ? const SizedBox(height: 8)
                      : Container(
                          key: ValueKey(_error),
                          margin: const EdgeInsets.only(top: 6, bottom: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF5C2C2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFB42334), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(color: Color(0xFFB42334))),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kAzul, _kTeal]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Ingresar',
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, color: Colors.white),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_outlined, size: 15, color: Colors.blueGrey.shade400),
                    const SizedBox(width: 6),
                    Text(
                      'Acceso solo para personal autorizado',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  static const _degradado = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D47A1), _kTeal, _kVerde],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _kFondo,
        body: LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 900 ? _ancho() : _movil(c),
        ),
      );

  /// Tablet horizontal / escritorio: panel de marca a la izquierda.
  Widget _ancho() => Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(gradient: _degradado),
              child: Stack(
                children: [
                  Positioned(top: -80, left: -80, child: _circulo(260, .08)),
                  Positioned(bottom: -120, right: -60, child: _circulo(340, .07)),
                  Center(child: _marca(clara: true, logo: 150)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: Text(
                      '© ${DateTime.now().year} Cultivos La Planicie S.A.S.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _formulario(),
                ),
              ),
            ),
          ),
        ],
      );

  /// Celular / tablet vertical: encabezado curvo con el logo y el formulario
  /// montado encima.
  Widget _movil(BoxConstraints c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Stack(
            children: [
              ClipPath(
                clipper: _CurvaInferior(),
                child: Container(
                  height: 330,
                  decoration: const BoxDecoration(gradient: _degradado),
                  child: Stack(
                    children: [
                      Positioned(top: -60, right: -50, child: _circulo(200, .09)),
                      Positioned(top: 120, left: -70, child: _circulo(160, .07)),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Column(
                        children: [
                          _marca(clara: true, logo: 104),
                          const SizedBox(height: 26),
                          _formulario(),
                          const SizedBox(height: 18),
                          Text(
                            '© ${DateTime.now().year} Cultivos La Planicie S.A.S.',
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _circulo(double d, double alpha) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      );
}

class _CurvaInferior extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 60)
    ..quadraticBezierTo(size.width / 2, size.height + 20, size.width, size.height - 60)
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
