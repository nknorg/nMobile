import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class TouchEntropyCollector extends StatefulWidget {
  final ValueChanged<String> onEntropyCollected;
  final int requiredEntropyBits;
  final double minEntropy;
  final int minDurationMs; // minimum collection duration in milliseconds

  const TouchEntropyCollector({
    Key? key,
    required this.onEntropyCollected,
    this.requiredEntropyBits = 256,
    this.minEntropy = 0.9, // Minimum entropy per bit (0.0 to 1.0)
    this.minDurationMs = 4000,
  }) : super(key: key);

  @override
  _TouchEntropyCollectorState createState() => _TouchEntropyCollectorState();
}

class _TouchEntropyCollectorState extends State<TouchEntropyCollector> {
  final List<Offset> _points = [];
  final List<int> _entropyData = [];
  double _entropyProgress = 0.0;
  bool _isComplete = false;
  final Random _random = Random.secure();
  int? _startMs;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).primaryColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GestureDetector(
            onPanStart: _handlePanStart,
            onPanUpdate: _handlePanUpdate,
            child: CustomPaint(
              painter: _EntropyPainter(
                points: _points,
                progress: _entropyProgress,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: _entropyProgress,
          minHeight: 8,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            _isComplete ? Colors.green : Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isComplete
              ? 'Entropy collection complete!'
              : 'Move your finger randomly in the box above',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _handlePanStart(DragStartDetails details) {
    if (_isComplete) return;
    _startMs ??= DateTime.now().millisecondsSinceEpoch;
    _addPoint(details.localPosition);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isComplete) return;
    _startMs ??= DateTime.now().millisecondsSinceEpoch;
    _addPoint(details.localPosition);
  }

  void _addPoint(Offset point) {
    setState(() {
      _points.add(point);
      
      // Add entropy from the point coordinates and timing
      final now = DateTime.now().microsecondsSinceEpoch;
      _entropyData.addAll([
        point.dx.toInt() & 0xFF,
        point.dy.toInt() & 0xFF,
        now & 0xFF,
        (now >> 8) & 0xFF,
        _random.nextInt(256),
      ]);

      // Calculate entropy progress
      final uniqueValues = _entropyData.toSet().length;
      final estimatedEntropy = uniqueValues / 256.0;
      final byEntropy = (_entropyData.length * estimatedEntropy * 8) / widget.requiredEntropyBits;

      // Calculate time-based progress
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final byTime = widget.minDurationMs <= 0 ? 1.0 : (nowMs - (_startMs ?? nowMs)) / widget.minDurationMs;

      // Overall progress is constrained by both
      _entropyProgress = [byEntropy, byTime, 1.0].reduce(min);

      // Complete only when both reach or exceed 1.0
      if ((_entropyProgress >= 1.0) && (byEntropy >= 1.0) && (byTime >= 1.0)) {
        _entropyProgress = 1.0;
        if (!_isComplete) {
          _isComplete = true;
          _finalizeEntropy();
        }
      }
    });
  }

  void _finalizeEntropy() {
    // Hash the collected entropy to ensure uniform distribution
    final hash = sha256.convert(_entropyData);
    widget.onEntropyCollected(hash.toString());
  }
}

class _EntropyPainter extends CustomPainter {
  final List<Offset> points;
  final double progress;

  _EntropyPainter({required this.points, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw the path
    for (var i = 1; i < points.length; i++) {
      final p1 = points[i - 1];
      final p2 = points[i];
      
      // Fade out older segments
      final opacity = 0.1 + (i / points.length) * 0.9;
      paint.color = Colors.blue.withOpacity(opacity * 0.6);
      
      canvas.drawLine(p1, p2, paint);
    }

    // Draw a progress indicator
    final progressPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final progressFill = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final progressRect = Rect.fromLTWH(0, size.height - 4, size.width * progress, 4);
    canvas.drawRect(progressRect, progressFill);
  }

  @override
  bool shouldRepaint(_EntropyPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.progress != progress;
}
