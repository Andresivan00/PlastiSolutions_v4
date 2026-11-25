import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/movimiento.dart';
import '../models/producto.dart';
import '../services/firestore_service.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/mensajes.dart';

const _verde = Color(0xFF2E7D32);
const _rojo = Color(0xFFC62828);

String _formatoFecha(DateTime d) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
}

/// Pantalla de gestión: entradas y salidas de stock.
///
/// - La lista es la bitácora de la colección `movimientos`, en tiempo real.
/// - Al registrar un movimiento, el servicio actualiza el stock del producto
///   y guarda el movimiento en una sola transacción.
class MovimientosScreen extends StatefulWidget {
  const MovimientosScreen({super.key});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  final _db = FirestoreService.instance;
  late final Stream<List<Movimiento>> _stream;

  /// null = mostrar todos.
  TipoMovimiento? _filtro;

  @override
  void initState() {
    super.initState();
    _stream = _db.streamMovimientos();
  }

  Future<void> _nuevo() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _FormularioMovimiento(),
    );
    if (ok == true && mounted) {
      mostrarMensaje(context, 'Movimiento registrado');
    }
  }

  Widget _chipFiltro(String texto, TipoMovimiento? valor) {
    return ChoiceChip(
      label: Text(texto),
      selected: _filtro == valor,
      onSelected: (_) => setState(() => _filtro = valor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.swap_vert),
        label: const Text('Nuevo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _chipFiltro('Todos', null),
                const SizedBox(width: 8),
                _chipFiltro('Entradas', TipoMovimiento.entrada),
                const SizedBox(width: 8),
                _chipFiltro('Salidas', TipoMovimiento.salida),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Movimiento>>(
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
                final lista = _filtro == null
                    ? todos
                    : todos.where((m) => m.tipo == _filtro).toList();

                if (lista.isEmpty) {
                  final sinNada = todos.isEmpty;
                  return EstadoVacio(
                    icono: Icons.swap_vert,
                    titulo: 'Sin movimientos',
                    mensaje: sinNada
                        ? 'Registra una entrada o salida para actualizar el stock'
                        : 'No hay movimientos de ese tipo',
                    textoBoton: sinNada ? 'Registrar movimiento' : null,
                    onPressed: sinNada ? _nuevo : null,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: lista.length,
                  itemBuilder: (context, i) =>
                      _TarjetaMovimiento(movimiento: lista[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaMovimiento extends StatelessWidget {
  final Movimiento movimiento;
  const _TarjetaMovimiento({required this.movimiento});

  @override
  Widget build(BuildContext context) {
    final m = movimiento;
    final color = m.esEntrada ? _verde : _rojo;

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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(m.esEntrada ? Icons.add : Icons.remove, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.productoNombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${m.tipo.etiqueta} · ${_formatoFecha(m.fecha)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stock resultante: ${m.stockResultante}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  if ((m.nota ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        m.nota!,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              m.cantidadConSigno,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario dentro del bottom sheet. Se cierra con `true` si se registró.
class _FormularioMovimiento extends StatefulWidget {
  const _FormularioMovimiento();

  @override
  State<_FormularioMovimiento> createState() => _FormularioMovimientoState();
}

class _FormularioMovimientoState extends State<_FormularioMovimiento> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirestoreService.instance;
  final _cantidad = TextEditingController();
  final _nota = TextEditingController();

  List<Producto> _productos = [];
  Producto? _producto;
  TipoMovimiento _tipo = TipoMovimiento.entrada;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    try {
      final lista = await _db.obtenerProductos();
      if (!mounted) return;
      setState(() {
        _productos = lista;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar productos: $e');
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los productos';
        _cargando = false;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final producto = _producto!;
    final nota = _nota.text.trim();

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await _db.registrarMovimiento(
        productoId: producto.id!,
        tipo: _tipo,
        cantidad: int.parse(_cantidad.text.trim()),
        nota: nota.isEmpty ? null : nota,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on StockInsuficienteException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _guardando = false;
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _guardando = false;
      });
    } catch (e) {
      debugPrint('Error al registrar movimiento: $e');
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo registrar el movimiento';
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: _contenido(),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_productos.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Primero registra al menos un producto',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Registrar movimiento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TipoMovimiento>(
              segments: const [
                ButtonSegment(
                  value: TipoMovimiento.entrada,
                  label: Text('Entrada'),
                  icon: Icon(Icons.add),
                ),
                ButtonSegment(
                  value: TipoMovimiento.salida,
                  label: Text('Salida'),
                  icon: Icon(Icons.remove),
                ),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Producto',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            items: _productos
                .map(
                  (p) => DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(
                      '${p.nombre} · stock ${p.stock}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (id) {
              final coincidencias = _productos.where((e) => e.id == id);
              setState(
                () => _producto =
                    coincidencias.isEmpty ? null : coincidencias.first,
              );
            },
            validator: (v) => v == null ? 'Selecciona un producto' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _cantidad,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              prefixIcon: Icon(Icons.numbers),
            ),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Ingresa una cantidad mayor a 0';
              final p = _producto;
              if (_tipo == TipoMovimiento.salida && p != null && n > p.stock) {
                return 'Solo hay ${p.stock} en stock';
              }
              return null;
            },
          ),
          _vistaPrevia(),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nota,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            validator: (v) =>
                (v ?? '').trim().length > 200 ? 'Máximo 200 caracteres' : null,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: _rojo,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 20),
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
            label: Text(_guardando ? 'Guardando...' : 'Registrar movimiento'),
          ),
        ],
      ),
    );
  }

  /// Muestra cómo quedaría el stock antes de guardar.
  Widget _vistaPrevia() {
    final p = _producto;
    final n = int.tryParse(_cantidad.text.trim());
    if (p == null || n == null || n <= 0) return const SizedBox.shrink();

    final nuevo = _tipo == TipoMovimiento.entrada ? p.stock + n : p.stock - n;
    final color = nuevo < 0 ? _rojo : Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Stock: ${p.stock}  →  $nuevo',
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
