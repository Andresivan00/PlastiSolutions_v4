import 'package:firebase_auth/firebase_auth.dart';

/// Error de autenticación con un mensaje listo para mostrar al usuario.
class AuthException implements Exception {
  final String mensaje;
  const AuthException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Encapsula Firebase Authentication (correo y contraseña).
///
/// Seguridad: Firebase guarda las contraseñas con hash en sus servidores
/// (la app nunca las almacena) y entrega un token que se renueva solo.
/// Ese token es el que las reglas de Firestore usan para saber quién es el
/// usuario (request.auth.uid).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Usuario con sesión activa, o null si no ha iniciado sesión.
  User? get usuarioActual => _auth.currentUser;

  /// Emite el usuario cada vez que se inicia o se cierra sesión.
  /// main.dart lo usa para decidir si muestra el login o el dashboard.
  Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

  Future<void> iniciarSesion(String correo, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    }
  }

  Future<void> registrar(String correo, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traducir(e.code));
    }
  }

  Future<void> cerrarSesion() => _auth.signOut();

  String _traducir(String code) {
    switch (code) {
      // Las versiones recientes de Firebase devuelven 'invalid-credential'
      // tanto para contraseña incorrecta como para correo inexistente.
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Correo o contraseña incorrectos';
      case 'invalid-email':
        return 'El correo no es válido';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta de nuevo más tarde';
      case 'network-request-failed':
        return 'Sin conexión a internet';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres)';
      case 'operation-not-allowed':
        return 'El acceso con correo no está habilitado en Firebase';
      default:
        return 'No se pudo completar la operación ($code)';
    }
  }
}
