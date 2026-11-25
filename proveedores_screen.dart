import 'package:flutter/material.dart';

import '../models/proveedor.dart';
import '../services/firestore_service.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/mensajes.dart';
import 'proveedor_form_screen.dart';

class ProveedoresScreen extends StatefulWidget {
  const ProveedoresScreen({super.key});

  @override
  State<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  final _db = FirestoreService.instance;

  /// Lista en tiempo real desde Cloud Firestore (se actualiza sola).
  late final Stream<List<Proveedor>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _db.streamProveedores();
  }

  void _abrirForm([Proveedor? p]) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProveedorFormScreen(proveedor: p)),
    );
  }

  Future<void> _eliminar(Proveedor p) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar proveedor',
      mensaje: '¿Eliminar a "${p.nombre}"?',
    );
    if (!ok) return;
    try {
      await _db.eliminarProveedor(p.id!);
      if (!mounted) return;
      mostrarMensaje(context, 'Proveedor eliminado');
    } on ProveedorConProductosException catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.toString(), error: true);
    } catch (e) {
      debugPrint('Error al eliminar proveedor: $e');
      if (!mounted) return;
      mostrarMensaje(context, 'No se pudo eliminar', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: StreamBuilder<List<Proveedor>>(
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
          final lista = snap.data ?? [];
          if (lista.isEmpty) {
            return EstadoVacio(
              icono: Icons.local_shipping_outlined,
              titulo: 'Sin proveedores',
              mensaje: 'Registra un proveedor para poder asociar productos',
              textoBoton: 'Agregar proveedor',
              onPressed: () => _abrirForm(),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final p = lista[i];
              final inicial =
                  p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?';
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
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: accent.withOpacity(0.2),
                        child: Text(
                          inicial,
                          style: TextStyle(
                            color: accent.withOpacity(0.95),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nombre,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ((p.telefono ?? '').isNotEmpty)
                              _Dato(Icons.phone_outlined, p.telefono!),
                            if ((p.correo ?? '').isNotEmpty)
                              _Dato(Icons.mail_outline, p.correo!),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) =>
                            v == 'editar' ? _abrirForm(p) : _eliminar(p),
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
                              leading:
                                  Icon(Icons.delete_outline, color: Colors.red),
                              title: Text('Eliminar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Dato(this.icono, this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icono, size: 15, color: Colors.black45),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
