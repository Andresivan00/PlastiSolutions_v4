/// Producto del inventario (colección `productos` en Cloud Firestore).
class Producto {
  /// Id del documento en Firestore (texto). Es null mientras no se ha guardado.
  final String? id;
  final String nombre;
  final double precio;
  final int stock;

  /// Id del documento del proveedor (colección `proveedores`).
  final String proveedorId;

  /// Nombre del proveedor. Se copia dentro del producto al guardarlo porque
  /// Firestore no tiene INNER JOIN; así la lista lo muestra sin otra consulta.
  final String? proveedorNombre;

  const Producto({
    this.id,
    required this.nombre,
    required this.precio,
    required this.stock,
    required this.proveedorId,
    this.proveedorNombre,
  });
}
