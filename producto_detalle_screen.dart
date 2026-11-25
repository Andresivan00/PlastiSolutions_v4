import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../services/firestore_service.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/mensajes.dart';
import 'producto_form_screen.dart';

/// Detalle de un producto.
///
/// Escucha el documento en Firestore en tiempo real: si el producto se edita
/// o se elimina desde otro lugar (otro dispositivo o la consola de Firebase),
/// esta pantalla se actualiza sola.
///
/// Al eliminar el producto se cierra con `true` para que la lista se recargue.
class ProductoDetalleScreen extends StatefulWidget {
  final Producto producto;

  const ProductoDetalleScreen({super.key, required this.producto});

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  final _db = FirestoreService.instance;
  late final Stream<Producto?> _stream;
  bool _eliminando = false;

  @override
  void initState() {
    super.initState();
    _stream = _db.streamProducto(widget.producto.id!);
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

  Future<void> _editar(Producto p) async {
    // No hace falta recargar al volver: el stream refleja el cambio.
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductoFormScreen(producto: p)),
    );
  }

  Future<void> _eliminar(Producto p) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar producto',
      mensaje: '¿Eliminar "${p.nombre}" del inventario?',
    );
    if (!ok) return;

    setState(() => _eliminando = true);
    try {
      await _db.eliminarProducto(p.id!);
      if (!mounted) return;
      mostrarMensaje(context, 'Producto eliminado');
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      mostrarMensaje(context, 'No se pudo eliminar el producto', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del producto')),
      body: StreamBuilder<Producto?>(
        stream: _stream,
        initialData: widget.producto,
        builder: (context, snap) {
          // Mientras se elimina, el snapshot local ya llega vacío: se evita
          // mostrar "no encontrado" justo antes de cerrar la pantalla.
          if (_eliminando) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EstadoVacio(
              icono: Icons.error_outline,
              titulo: 'No se pudo cargar la información',
              mensaje: '${snap.error}',
            );
          }
          final p = snap.data;
          if (p == null) {
            return const EstadoVacio(
              icono: Icons.search_off,
              titulo: 'Producto no encontrado',
              mensaje:
                  'Fue eliminado desde otro lugar. Vuelve atrás para actualizar la lista.',
            );
          }
          return _contenido(p);
        },
      ),
    );
  }

  Widget _contenido(Producto p) {
    final primary = Theme.of(context).colorScheme.primary;
    final stockColor = _colorStock(p.stock);
    final valorInventario = p.precio * p.stock;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Tarjeta(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.inventory_2, color: primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stockColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Stock ${_etiquetaStock(p.stock)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: stockColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Tarjeta(
            child: Column(
              children: [
                _Fila(
                  icono: Icons.attach_money,
                  etiqueta: 'Precio unitario',
                  valor: '\$${p.precio.toStringAsFixed(2)}',
                ),
                const Divider(height: 24),
                _Fila(
                  icono: Icons.numbers,
                  etiqueta: 'Stock disponible',
                  valor: '${p.stock} unidades',
                  colorValor: stockColor,
                ),
                const Divider(height: 24),
                _Fila(
                  icono: Icons.local_shipping_outlined,
                  etiqueta: 'Proveedor',
                  valor: p.proveedorNombre ?? 'Sin proveedor',
                ),
                const Divider(height: 24),
                _Fila(
                  icono: Icons.calculate_outlined,
                  etiqueta: 'Valor en inventario',
                  valor: '\$${valorInventario.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _editar(p),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar producto'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _eliminar(p),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar producto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
              side: const BorderSide(color: Color(0xFFC62828)),
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
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final Widget child;
  const _Tarjeta({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }
}

class _Fila extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color? colorValor;

  const _Fila({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.colorValor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 20, color: Colors.black45),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            etiqueta,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colorValor,
            ),
          ),
        ),
      ],
    );
  }
}
