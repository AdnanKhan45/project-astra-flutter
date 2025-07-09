import 'package:flutter/material.dart';

class CameraBlurClipper extends CustomClipper<Path> {
  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;

  CameraBlurClipper({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.borderRadius,
  });

  @override
  Path getClip(Size size) {
    // Create a path that covers the entire screen
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Define the rectangle for the "hole" (the clear camera preview area)
    final RRect holeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        horizontalPadding,
        verticalPadding,
        size.width - (2 * horizontalPadding),
        size.height - (2 * verticalPadding),
      ),
      Radius.circular(borderRadius),
    );

    // Subtract the hole from the main path.
    // This creates a path that is the entire screen MINUS the central rounded rectangle.
    // The BackdropFilter will then be applied only to the remaining (outer) parts of this path.
    path.addRRect(holeRect);
    path.fillType = PathFillType.evenOdd; // Crucial for creating the "hole"

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    // Reclip if any of the parameters change
    return oldClipper is CameraBlurClipper &&
        (oldClipper.horizontalPadding != horizontalPadding ||
            oldClipper.verticalPadding != verticalPadding ||
            oldClipper.borderRadius != borderRadius);
  }
}
