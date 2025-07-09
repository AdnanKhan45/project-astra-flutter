import 'dart:math';
import 'package:flutter/material.dart';

class VoiceVisualizer extends StatefulWidget {
  final double amplitude; // 0.0 - 1.0

  const VoiceVisualizer({super.key, required this.amplitude});

  @override
  State<VoiceVisualizer> createState() => _VoiceVisualizerState();
}

class _VoiceVisualizerState extends State<VoiceVisualizer> with SingleTickerProviderStateMixin {
  static const int _bufferLength = 25;
  late List<double> _amplitudeBuffer;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _amplitudeBuffer = <double>[];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 33), // ~30 fps
    )..addListener(_onFrame)
      ..repeat();
  }

  void _onFrame() {
    _amplitudeBuffer.insert(0, widget.amplitude);
    if (_amplitudeBuffer.length > _bufferLength) {
      _amplitudeBuffer.removeLast();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delays = [20, 12, 0]; // Try [24, 14, 0] or [20, 15, 0] for even slower wave
    final heights = List.generate(3, (i) {
      double value = _amplitudeBuffer.length > delays[i]
          ? _amplitudeBuffer[delays[i]]
          : (_amplitudeBuffer.isNotEmpty ? _amplitudeBuffer.last : 0.0);
      // Optional: add jitter for organic feel
      value += (Random().nextDouble() - 0.5) * 0.05 * value;
      value = value.clamp(0.0, 1.0);
      return 10 + value * 18;
    });

    return Container(
      width: 60,
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              return Container(
                width: 8,
                height: heights[i],
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
