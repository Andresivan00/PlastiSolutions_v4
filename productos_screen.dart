import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../services/firestore_service.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/mensajes.dart';
import 'producto_detalle_screen.dart';
import 'producto_form_screen.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final _db = FirestoreService.instance;
  final _busqueda = TextEditingController();

  /// Lista en tiempo real desde Cloud Firestore: se actualiza sola cuando
  /// algo cambia en la nube (sincronización BD remota → app). Se crea una
  /// sola vez; la búsqueda filtra en pantalla sin volver a consultar.
  late final Stream<List<Producto>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _db.streamProductos();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _abrirForm([Producto? p]) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductoFormScreen(producto: p)),
    );
  }

  void _abrirDetalle(Producto p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: p)),
    );
  }

  Future<void> _eliminar(Producto p) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar producto',
      mensaje: '¿Eliminar "${p.nombre}" del inventario?',
    );
    if (!ok) return;
    try {
      await _db.eliminarProducto(p.id!);
      if (!mounted) return;
      mostrarMensaje(context, 'Producto eliminado');
    } catch (e) {
      debugPrint('Error al eliminar producto: $e');
      if (!mounted) return;
      mostrarMensaje(context, 'No se pudo eliminar el producto', error: true);
    }
  }

  Color _colorStock(int stock) {
    if (stock <= 5) return const Color(0xFFC62828);
    if (stock <= 20) return const Color(0xFFF57C00);
    return const Color(0xFF2E7D32);
  }

  String _etiquetaStock(int stock) {
    if (stock <= 5) return 'Bajo';
    if (stock <= 20) return 'Medio';
    return 'OK';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _busqueda,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqueda.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _busqueda.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Producto>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return EstadoVacio(
                    icono: Icons.error_outline,
                    titulo: 'No se pudo cargar la información',
                    mensaje: '${snap.error}',
                  );
                }
                final todos = snap.data ?? [];
                final filtro = _busqueda.text.trim().toLowerCase();
                final lista = filtro.isEmpty
                    ? todos
                    : todos
                        .where((p) => p.nombre.toLowerCase().contains(filtro))
                        .toList();

                if (lista.isEmpty) {
                  return EstadoVacio(
                    icono: Icons.inventory_2_outlined,
                    titulo: 'Sin productos',
                    mensaje: filtro.isEmpty
                        ? 'Registra tu primer producto para empezar'
                        : 'No hay resultados para esa búsqueda',
                    textoBoton: filtro.isEmpty ? 'Agregar producto' : null,
                    onPressed: filtro.isEmpty ? () => _abrirForm() : null,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final p = lista[i];
                    final stockColor = _colorStock(p.stock);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      // Material + InkWell: al tocar la tarjeta se abre el
                      // detalle (y se ve el efecto de toque).
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _abrirDetalle(p),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child:
                                      Icon(Icons.inventory_2, color: primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.nombre,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        p.proveedorNombre ?? 'Sin proveedor',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            '\$${p.precio.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: primary,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  stockColor.withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Stock ${p.stock} · ${_etiquetaStock(p.stock)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: stockColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) => v == 'editar'
                                      ? _abrirForm(p)
                                      : _eliminar(p),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'editar',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.edit_outlined),
                                        title: Text('Editar'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'eliminar',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        title: Text('Eliminar'),
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
