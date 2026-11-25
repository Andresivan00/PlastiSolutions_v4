/// Tipo de movimiento de inventario.
enum TipoMovimiento {
  entrada,
  salida;

  String get etiqueta => this == TipoMovimiento.entrada ? 'Entrada' : 'Salida';
}

/// Registro de una entrada o salida de stock de un producto.
///
/// Es la tercera colección de la app (`movimientos` en Firestore) y funciona
/// como bitácora: una vez creado, un movimiento no se edita ni se elimina.
class Movimiento {
  final String? id;
  final String productoId;

  /// Nombre del producto al momento del movimiento (se copia para que la
  /// bitácora siga siendo legible aunque el producto se elimine después).
  final String productoNombre;
  final TipoMovimiento tipo;
  final int cantidad;

  /// Stock que quedó en el producto después de aplicar este movimiento.
  final int stockResultante;
  final String? nota;
  final DateTime fecha;

  const Movimiento({
    this.id,
    required this.productoId,
    required this.productoNombre,
    required this.tipo,
    required this.cantidad,
    required this.stockResultante,
    this.nota,
    required this.fecha,
  });

  bool get esEntrada => tipo == TipoMovimiento.entrada;

  /// "+10" para entradas, "-3" para salidas.
  String get cantidadConSigno => '${esEntrada ? '+' : '-'}$cantidad';
}
