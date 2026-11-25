import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/proveedor.dart';
import '../services/firestore_service.dart';
import '../widgets/mensajes.dart';

/// Sirve para registrar un proveedor nuevo y para editar uno existente
/// (si recibe `proveedor`, el título y el botón cambian a "Editar").
class ProveedorFormScreen extends StatefulWidget {
  final Proveedor? proveedor;

  const ProveedorFormScreen({super.key, this.proveedor});

  @override
  State<ProveedorFormScreen> createState() => _ProveedorFormScreenState();
}

class _ProveedorFormScreenState extends State<ProveedorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirestoreService.instance;

  late final TextEditingController _nombre;
  late final TextEditingController _telefono;
  late final TextEditingController _correo;
  bool _guardando = false;

  bool get _esEdicion => widget.proveedor != null;

  @override
  void initState() {
    super.initState();
    final p = widget.proveedor;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _telefono = TextEditingController(text: p?.telefono ?? '');
    _correo = TextEditingController(text: p?.correo ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _correo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final proveedor = Proveedor(
      id: widget.proveedor?.id,
      nombre: _nombre.text.trim(),
      telefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
      correo: _correo.text.trim().isEmpty ? null : _correo.text.trim(),
    );

    try {
      if (_esEdicion) {
        await _db.actualizarProveedor(proveedor);
      } else {
        await _db.insertarProveedor(proveedor);
      }
      if (!mounted) return;
      mostrarMensaje(
        context,
        _esEdicion ? 'Proveedor actualizado' : 'Proveedor registrado',
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error al guardar proveedor: $e');
      if (!mounted) return;
      mostrarMensaje(context, 'No se pudo guardar el proveedor', error: true);
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar proveedor' : 'Nuevo proveedor'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Datos de contacto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Los límites (120 / 40 / 120) son los mismos que exigen las
              // reglas de seguridad de Firestore.
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                decoration: const InputDecoration(
                  labelText: 'Nombre o razón social',
                  prefixIcon: Icon(Icons.business_outlined),
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
                controller: _telefono,
                keyboardType: TextInputType.phone,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                decoration: const InputDecoration(
                  labelText: 'Correo (opcional)',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Correo no válido';
                  }
                  return null;
                },
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
                          ? 'Actualizar proveedor'
                          : 'Guardar proveedor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
