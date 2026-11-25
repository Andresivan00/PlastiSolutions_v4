import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/movimientos_screen.dart';
import 'screens/productos_screen.dart';
import 'screens/proveedores_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Conecta la app con el proyecto de Firebase (Authentication + Firestore).
  // En Android los datos del proyecto se leen de android/app/google-services.json
  // (el plugin com.google.gms.google-services los incorpora al compilar).
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Sin esto la app quedaría en blanco; así se ve qué falló.
    runApp(_ErrorDeInicio(detalle: '$e'));
    return;
  }

  runApp(const PlastiSolutionsApp());
}

class PlastiSolutionsApp extends StatelessWidget {
  const PlastiSolutionsApp({super.key});

  static const Color primary = Color(0xFF0D7377);
  static const Color accent = Color(0xFFF5A623);
  static const Color bg = Color(0xFFF4F7F8);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'PlastiSolutions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 1.6),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      initialRoute: '/',
      routes: {
        // La ruta raíz es la "puerta": decide entre login y dashboard.
        '/': (_) => const _PuertaAuth(),
        '/productos': (_) => const ProductosScreen(),
        '/proveedores': (_) => const ProveedoresScreen(),
        '/movimientos': (_) => const MovimientosScreen(),
      },
    );
  }
}

/// Puerta de autenticación.
///
/// Escucha la sesión de Firebase Authentication:
///  - sin sesión → LoginScreen
///  - con sesión → DashboardScreen
/// Como la sesión se guarda en el dispositivo, al volver a abrir la app el
/// usuario sigue dentro hasta que cierre sesión.
class _PuertaAuth extends StatefulWidget {
  const _PuertaAuth();

  @override
  State<_PuertaAuth> createState() => _PuertaAuthState();
}

class _PuertaAuthState extends State<_PuertaAuth> {
  // Se crea una sola vez para que el StreamBuilder no se vuelva a suscribir
  // en cada rebuild.
  late final Stream<User?> _sesion = AuthService.instance.cambiosDeSesion;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _sesion,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) {
          // Si se cierra la sesión con otras pantallas abiertas encima,
          // se regresa a la raíz para que se vea el login.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).popUntil((r) => r.isFirst);
            }
          });
          return const LoginScreen();
        }
        return const DashboardScreen();
      },
    );
  }
}

/// Pantalla mínima que se muestra si Firebase no logra iniciar.
class _ErrorDeInicio extends StatelessWidget {
  final String detalle;
  const _ErrorDeInicio({required this.detalle});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 56, color: Color(0xFFC62828)),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo conectar con Firebase',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Revisa que android/app/google-services.json sea el de tu proyecto '
                  'y que estés ejecutando la app en Android.\n\n$detalle',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
