/// Proveedor (colección `proveedores` en Cloud Firestore).
class Proveedor {
  /// Id del documento en Firestore (texto). Es null mientras no se ha guardado.
  final String? id;
  final String nombre;
  final String? telefono;
  final String? correo;

  const Proveedor({this.id, required this.nombre, this.telefono, this.correo});
}
