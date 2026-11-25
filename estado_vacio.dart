import 'package:flutter/material.dart';

class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final String? textoBoton;
  final VoidCallback? onPressed;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.textoBoton,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 56, color: primary.withOpacity(0.7)),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (textoBoton != null && onPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.add),
                label: Text(textoBoton!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
