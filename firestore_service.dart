import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/movimiento.dart';
import '../models/producto.dart';
import '../models/proveedor.dart';

/// Se lanza al intentar eliminar un proveedor que todavía tiene productos.
class ProveedorConProductosException implements Exception {
  final int cantidad;
  const ProveedorConProductosException(this.cantidad);

  @override
  String toString() =>
      'No se puede eliminar: el proveedor tiene $cantidad producto(s) asociado(s). '
      'Elimina o reasigna esos productos primero.';
}

/// Se lanza al registrar una salida mayor al stock disponible.
class StockInsuficienteException implements Exception {
  final int disponible;
  const StockInsuficienteException(this.disponible);

  @override
  String toString() =>
      'Stock insuficiente: solo hay $disponible unidad(es) disponible(s)';
}

/// Acceso a Cloud Firestore (base de datos remota).
///
/// ESTRUCTURA DE LOS DATOS (colecciones de nivel superior):
///
///   proveedores/{id}
///     uid, nombre, telefono, correo, creadoEn, actualizadoEn
///
///   productos/{id}
///     uid, nombre, precio, stock, proveedorId, proveedorNombre,
///     creadoEn, actualizadoEn
///
///   movimientos/{id}   (bitácora de entradas y salidas; no se edita)
///     uid, productoId, productoNombre, tipo ('entrada' | 'salida'),
///     cantidad, stockResultante, nota, fecha
///
/// - `uid` es el dueño del documento (el usuario de Firebase Auth que lo
///   creó). Las reglas de seguridad solo dejan leer y modificar documentos
///   cuyo `uid` coincide con el usuario autenticado, y todas las consultas
///   de este servicio filtran por ese campo.
/// - `proveedorNombre` se guarda dentro del producto (Firestore no tiene
///   INNER JOIN). Se mantiene al día al crear o editar un producto y cuando
///   se cambia el nombre de un proveedor.
///
/// Los métodos `Future` mantienen los mismos nombres que tenía
/// DatabaseService, para que las pantallas existentes cambien poco.
/// Los métodos `stream*` usan snapshots: la app se actualiza sola cuando
/// el dato cambia en la nube (por ejemplo, si lo editas en la consola de
/// Firebase). Eso demuestra la sincronización BD remota → app.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _productos =>
      _fs.collection('productos');
  CollectionReference<Map<String, dynamic>> get _proveedores =>
      _fs.collection('proveedores');
  CollectionReference<Map<String, dynamic>> get _movimientos =>
      _fs.collection('movimientos');

  /// uid del usuario con sesión activa.
  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('No hay una sesión activa');
    return u.uid;
  }

  // ───────────────────────── PROVEEDORES ─────────────────────────

  Future<List<Proveedor>> obtenerProveedores() async {
    final snap = await _proveedores.where('uid', isEqualTo: _uid).get();
    final lista = snap.docs.map(_proveedorDesde).toList();
    lista.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return lista;
  }

  /// Lista en tiempo real: se vuelve a emitir cada vez que cambia algo en
  /// la nube.
  Stream<List<Proveedor>> streamProveedores() {
    return _proveedores.where('uid', isEqualTo: _uid).snapshots().map((s) {
      final lista = s.docs.map(_proveedorDesde).toList();
      lista.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
      return lista;
    });
  }

  Future<void> insertarProveedor(Proveedor p) async {
    await _proveedores.add({
      'uid': _uid,
      'nombre': p.nombre,
      'telefono': p.telefono,
      'correo': p.correo,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Actualiza el proveedor y, en el mismo lote, el nombre que llevan
  /// copiado sus productos.
  Future<void> actualizarProveedor(Proveedor p) async {
    final id = p.id;
    if (id == null) throw ArgumentError('El proveedor no tiene id');

    final productos = await _productos
        .where('uid', isEqualTo: _uid)
        .where('proveedorId', isEqualTo: id)
        .get();

    final batch = _fs.batch();
    batch.update(_proveedores.doc(id), {
      'nombre': p.nombre,
      'telefono': p.telefono,
      'correo': p.correo,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
    for (final d in productos.docs) {
      batch.update(d.reference, {'proveedorNombre': p.nombre});
    }
    await batch.commit();
  }

  /// Lanza [ProveedorConProductosException] si aún tiene productos.
  Future<void> eliminarProveedor(String id) async {
    final asociados = await _productos
        .where('uid', isEqualTo: _uid)
        .where('proveedorId', isEqualTo: id)
        .count()
        .get();
    final n = asociados.count ?? 0;
    if (n > 0) throw ProveedorConProductosException(n);
    await _proveedores.doc(id).delete();
  }

  Future<int> contarProveedores() async {
    final snap =
        await _proveedores.where('uid', isEqualTo: _uid).count().get();
    return snap.count ?? 0;
  }

  // ───────────────────────── PRODUCTOS ─────────────────────────

  /// Lectura única. [filtro] busca por nombre (sin distinguir mayúsculas).
  Future<List<Producto>> obtenerProductos({String filtro = ''}) async {
    final snap = await _productos.where('uid', isEqualTo: _uid).get();
    return _filtrar(snap.docs.map(_productoDesde).toList(), filtro);
  }

  /// Lista en tiempo real: se vuelve a emitir cada vez que cambia algo en
  /// la nube.
  Stream<List<Producto>> streamProductos({String filtro = ''}) {
    return _productos
        .where('uid', isEqualTo: _uid)
        .snapshots()
        .map((s) => _filtrar(s.docs.map(_productoDesde).toList(), filtro));
  }

  /// Un solo producto en tiempo real. Emite null si fue eliminado.
  Stream<Producto?> streamProducto(String id) {
    return _productos.doc(id).snapshots().map(
          (d) => (d.exists && d.data() != null) ? _productoDesde(d) : null,
        );
  }

  Future<void> insertarProducto(Producto p) async {
    final proveedor = await _leerProveedor(p.proveedorId);
    await _productos.add({
      'uid': _uid,
      ..._datosProducto(p, proveedor.nombre),
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarProducto(Producto p) async {
    final id = p.id;
    if (id == null) throw ArgumentError('El producto no tiene id');
    final proveedor = await _leerProveedor(p.proveedorId);
    await _productos.doc(id).update({
      ..._datosProducto(p, proveedor.nombre),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> eliminarProducto(String id) => _productos.doc(id).delete();

  Future<int> contarProductos() async {
    final snap = await _productos.where('uid', isEqualTo: _uid).count().get();
    return snap.count ?? 0;
  }

  // ───────────────────────── MOVIMIENTOS ─────────────────────────

  /// Bitácora en tiempo real, del más reciente al más antiguo.
  Stream<List<Movimiento>> streamMovimientos() {
    return _movimientos.where('uid', isEqualTo: _uid).snapshots().map((s) {
      final lista = s.docs.map(_movimientoDesde).toList();
      lista.sort((a, b) => b.fecha.compareTo(a.fecha));
      return lista;
    });
  }

  /// Registra una entrada o salida y actualiza el stock del producto en la
  /// MISMA transacción: se guardan las dos cosas o ninguna.
  ///
  /// El stock se lee dentro de la transacción (no de la pantalla), así que el
  /// resultado es correcto aunque el valor haya cambiado desde otro lugar.
  /// Lanza [StockInsuficienteException] si una salida dejaría el stock negativo.
  Future<void> registrarMovimiento({
    required String productoId,
    required TipoMovimiento tipo,
    required int cantidad,
    String? nota,
  }) async {
    if (cantidad <= 0) throw ArgumentError('La cantidad debe ser mayor a 0');

    final uid = _uid;
    final productoRef = _productos.doc(productoId);
    final movimientoRef = _movimientos.doc();

    await _fs.runTransaction((tx) async {
      final snap = await tx.get(productoRef);
      final data = snap.data();
      if (!snap.exists || data == null) {
        throw StateError('El producto ya no existe');
      }

      final stockActual = (data['stock'] as num?)?.toInt() ?? 0;
      final nuevoStock = tipo == TipoMovimiento.entrada
          ? stockActual + cantidad
          : stockActual - cantidad;
      if (nuevoStock < 0) throw StockInsuficienteException(stockActual);

      tx.update(productoRef, {
        'stock': nuevoStock,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      tx.set(movimientoRef, {
        'uid': uid,
        'productoId': productoId,
        'productoNombre': data['nombre'],
        'tipo': tipo.name,
        'cantidad': cantidad,
        'stockResultante': nuevoStock,
        'nota': nota,
        'fecha': FieldValue.serverTimestamp(),
      });
    });
  }

  // ───────────────────────── Auxiliares ─────────────────────────

  Future<Proveedor> _leerProveedor(String id) async {
    final doc = await _proveedores.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      throw StateError('El proveedor seleccionado ya no existe');
    }
    return _proveedorDesde(doc);
  }

  Map<String, dynamic> _datosProducto(Producto p, String proveedorNombre) => {
        'nombre': p.nombre,
        'precio': p.precio,
        'stock': p.stock,
        'proveedorId': p.proveedorId,
        'proveedorNombre': proveedorNombre,
      };

  /// Filtra por nombre y ordena alfabéticamente en el cliente.
  /// (Se ordena aquí para no obligar a crear índices compuestos en Firestore.)
  List<Producto> _filtrar(List<Producto> lista, String filtro) {
    final f = filtro.trim().toLowerCase();
    final resultado = f.isEmpty
        ? lista
        : lista.where((p) => p.nombre.toLowerCase().contains(f)).toList();
    resultado.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return resultado;
  }

  Producto _productoDesde(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Producto(
      id: d.id,
      nombre: (m['nombre'] as String?) ?? '',
      precio: (m['precio'] as num?)?.toDouble() ?? 0,
      stock: (m['stock'] as num?)?.toInt() ?? 0,
      proveedorId: (m['proveedorId'] as String?) ?? '',
      proveedorNombre: m['proveedorNombre'] as String?,
    );
  }

  Movimiento _movimientoDesde(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Movimiento(
      id: d.id,
      productoId: (m['productoId'] as String?) ?? '',
      productoNombre: (m['productoNombre'] as String?) ?? '',
      tipo: m['tipo'] == 'salida'
          ? TipoMovimiento.salida
          : TipoMovimiento.entrada,
      cantidad: (m['cantidad'] as num?)?.toInt() ?? 0,
      stockResultante: (m['stockResultante'] as num?)?.toInt() ?? 0,
      nota: m['nota'] as String?,
      // Mientras el servidor no confirma la escritura, `fecha` llega null.
      fecha: (m['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Proveedor _proveedorDesde(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Proveedor(
      id: d.id,
      nombre: (m['nombre'] as String?) ?? '',
      telefono: m['telefono'] as String?,
      correo: m['correo'] as String?,
    );
  }
}
