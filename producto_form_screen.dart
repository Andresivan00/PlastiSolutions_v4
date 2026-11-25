import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/producto.dart';
import '../models/proveedor.dart';
import '../services/firestore_service.dart';
import '../widgets/mensajes.dart';

/// Sirve para registrar un producto nuevo y para editar uno existente
/// (si recibe `producto`, el título y el botón cambian a "Editar").
class ProductoFormScreen extends StatefulWidget {
  final Producto? producto;

  const ProductoFormScreen({super.key, this.producto});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirestoreService.instance;

  late final TextEditingController _nombre;
  late final TextEditingController _precio;
  late final TextEditingController _stock;

  List<Proveedor> _proveedores = [];
  String? _proveedorId;
  bool _cargando = true;
  bool _guardando = false;
  String? _errorCarga;

  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _precio = TextEditingController(
      text: p != null ? p.precio.toStringAsFixed(2) : '',
    );
    _stock = TextEditingController(
      text: p != null ? '${p.stock}' : '',
    );
    _proveedorId = p?.proveedorId;
    _cargarProveedores();
  }

  Future<void> _cargarProveedores() async {
    try {
      final lista = await _db.obtenerProveedores();
      if (!mounted) return;
      setState(() {
        _proveedores = lista;
        _cargando = false;
        if (_proveedorId != null &&
            !lista.any((e) => e.id == _proveedorId)) {
          _proveedorId = null;
        }
      });
    } catch (e) {
      debugPrint('Error al cargar proveedores: $e');
      if (!mounted) return;
      setState(() {
        _errorCarga = 'No se pudieron cargar los proveedores';
        _cargando = false;
      });
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_proveedorId == null) {
      mostrarMensaje(context, 'Selecciona un proveedor', error: true);
      return;
    }

    setState(() => _guardando = true);
    final producto = Producto(
      id: widget.producto?.id,
      nombre: _nombre.text.trim(),
      precio: double.parse(_precio.text.replaceAll(',', '.')),
      stock: int.parse(_stock.text),
      proveedorId: _proveedorId!,
    );

    try {
      if (_esEdicion) {
        await _db.actualizarProducto(producto);
      } else {
        await _db.insertarProducto(producto);
      }
      if (!mounted) return;
      mostrarMensaje(
        context,
        _esEdicion ? 'Producto actualizado' : 'Producto registrado',
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error al guardar producto: $e');
      if (!mounted) return;
      mostrarMensaje(context, 'No se pudo guardar el producto', error: true);
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : (_errorCarga != null || _proveedores.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _errorCarga != null
                              ? Icons.error_outline
                              : Icons.local_shipping_outlined,
                          size: 56,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorCarga ??
                              'Primero registra al menos un proveedor',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Volver'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Datos del producto',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nombre,
                          textCapitalization: TextCapitalization.sentences,
                          // 120 = límite que también exigen las reglas de Firestore.
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(120),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            prefixIcon: Icon(Icons.label_outline),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa el nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _precio,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Precio unitario',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa el precio';
                            }
                            final n =
                                double.tryParse(v.replaceAll(',', '.'));
                            if (n == null || n <= 0) {
                              return 'Precio inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _stock,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa el stock';
                            }
                            final n = int.tryParse(v);
                            if (n == null || n < 0) {
                              return 'Stock inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _proveedorId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Proveedor',
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                          items: _proveedores
                              .map(
                                (pr) => DropdownMenuItem<String>(
                                  value: pr.id,
                                  child: Text(
                                    pr.nombre,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _proveedorId = v),
                          validator: (v) =>
                              v == null ? 'Selecciona un proveedor' : null,
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed: _guardando ? null : _guardar,
                          icon: _guardando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _guardando
                                ? 'Guardando...'
                                : (_esEdicion
                                    ? 'Actualizar producto'
                                    : 'Guardar producto'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
