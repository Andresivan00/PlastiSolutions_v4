import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/mensajes.dart';
import '../widgets/tarjeta_resumen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = FirestoreService.instance;
  late Future<Map<String, int>> _resumen;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _resumen = Future.wait([
      _db.contarProductos(),
      _db.contarProveedores(),
    ]).then((v) => {'productos': v[0], 'proveedores': v[1]});
  }

  void _ir(String ruta) async {
    await Navigator.pushNamed(context, ruta);
    if (mounted) setState(_cargar);
  }

  /// Pide confirmación y cierra la sesión. Al cerrarse, la puerta de
  /// autenticación de main.dart muestra el login automáticamente.
  Future<void> _cerrarSesion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('¿Quieres salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await AuthService.instance.cerrarSesion();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      if (!mounted) return;
      mostrarMensaje(context, 'No se pudo cerrar la sesión', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final correo = AuthService.instance.usuarioActual?.email ?? '';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(_cargar),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.of(context).padding.top + 20,
                  24,
                  28,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PlastiSolutions',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Control de inventario y proveedores',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar sesión',
                          onPressed: _cerrarSesion,
                          icon: const Icon(Icons.logout, color: Colors.white),
                        ),
                      ],
                    ),
                    if (correo.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              correo,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: FutureBuilder<Map<String, int>>(
                  future: _resumen,
                  builder: (context, snap) {
                    final productos = snap.data?['productos'] ?? 0;
                    final proveedores = snap.data?['proveedores'] ?? 0;
                    return Row(
                      children: [
                        Expanded(
                          child: TarjetaResumen(
                            icono: Icons.inventory_2_outlined,
                            etiqueta: 'Productos',
                            valor: productos,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TarjetaResumen(
                            icono: Icons.local_shipping_outlined,
                            etiqueta: 'Proveedores',
                            valor: proveedores,
                            color: const Color(0xFFF5A623),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Secciones',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AccesoCard(
                      icono: Icons.inventory_2,
                      titulo: 'Productos',
                      detalle: 'Consulta, registra y edita tu inventario',
                      color: primary,
                      onTap: () => _ir('/productos'),
                    ),
                    const SizedBox(height: 12),
                    _AccesoCard(
                      icono: Icons.local_shipping,
                      titulo: 'Proveedores',
                      detalle: 'Gestiona los datos de contacto',
                      color: const Color(0xFFF5A623),
                      onTap: () => _ir('/proveedores'),
                    ),
                    const SizedBox(height: 12),
                    _AccesoCard(
                      icono: Icons.swap_vert,
                      titulo: 'Movimientos',
                      detalle: 'Registra entradas y salidas de stock',
                      color: const Color(0xFF5C6BC0),
                      onTap: () => _ir('/movimientos'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccesoCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final Color color;
  final VoidCallback onTap;

  const _AccesoCard({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icono, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
