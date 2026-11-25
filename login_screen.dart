import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Inicio de sesión (y registro) con Firebase Authentication.
///
/// Esta pantalla no navega por sí sola: al iniciar sesión, main.dart escucha
/// `AuthService.cambiosDeSesion` y reemplaza el login por el dashboard.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService.instance;
  final _correo = TextEditingController();
  final _password = TextEditingController();

  bool _modoRegistro = false;
  bool _verPassword = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      if (_modoRegistro) {
        await _auth.registrar(_correo.text, _password.text);
      } else {
        await _auth.iniciarSesion(_correo.text, _password.text);
      }
      if (mounted) setState(() => _cargando = false);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error de autenticación: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrió un error inesperado. Intenta de nuevo';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Encabezado con la misma identidad visual del dashboard.
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.of(context).padding.top + 36,
                24,
                36,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primary, primary.withOpacity(0.85)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'PlastiSolutions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Control de inventario y proveedores',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _modoRegistro ? 'Crear cuenta' : 'Iniciar sesión',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _modoRegistro
                                ? 'Registra tu correo para tener tu propio inventario'
                                : 'Ingresa con tu correo y contraseña',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _correo,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (v) {
                              final t = v?.trim() ?? '';
                              if (t.isEmpty) return 'Ingresa tu correo';
                              final valido =
                                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(t);
                              if (!valido) return 'Correo no válido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: !_verPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_cargando) _enviar();
                            },
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _verPassword
                                    ? 'Ocultar contraseña'
                                    : 'Mostrar contraseña',
                                icon: Icon(
                                  _verPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _verPassword = !_verPassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresa tu contraseña';
                              }
                              if (_modoRegistro && v.length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC62828).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      const Color(0xFFC62828).withOpacity(0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFC62828),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFC62828),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _cargando ? null : _enviar,
                            icon: _cargando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _modoRegistro
                                        ? Icons.person_add_alt_1
                                        : Icons.login,
                                  ),
                            label: Text(
                              _cargando
                                  ? 'Un momento...'
                                  : (_modoRegistro
                                      ? 'Crear cuenta'
                                      : 'Iniciar sesión'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: _cargando
                                  ? null
                                  : () => setState(() {
                                        _modoRegistro = !_modoRegistro;
                                        _error = null;
                                      }),
                              child: Text(
                                _modoRegistro
                                    ? '¿Ya tienes cuenta? Inicia sesión'
                                    : '¿No tienes cuenta? Regístrate',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
