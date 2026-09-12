import 'package:flutter/material.dart';

class ImageLightbox extends StatelessWidget {
  const ImageLightbox({super.key, required this.imageUrl});

  final String imageUrl;

  static void show(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => ImageLightbox(imageUrl: imageUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('Failed to load image'),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
