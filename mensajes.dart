import 'package:flutter/material.dart';

void mostrarMensaje(
  BuildContext context,
  String texto, {
  bool error = false,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
      backgroundColor: error ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    ),
  );
}

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC62828),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return resultado ?? false;
}
