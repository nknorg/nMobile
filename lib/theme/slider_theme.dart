import 'package:flutter/material.dart';

class SliderThemeShape extends SliderComponentShape {

  const SliderThemeShape({
    this.width = 8,
    this.height = 24,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    Animation<double> activationAnimation,
    @required Animation<double> enableAnimation,
    bool isDiscrete,
    TextPainter labelPainter,
    RenderBox parentBox,
    @required SliderThemeData sliderTheme,
    TextDirection textDirection,
    double value,
  }) {
    assert(context != null);
    assert(center != null);
    assert(enableAnimation != null);
    assert(sliderTheme != null);
    assert(sliderTheme.disabledThumbColor != null);
    assert(sliderTheme.thumbColor != null);

    final Canvas canvas = context.canvas;
    final ColorTween colorTween = ColorTween(
      begin: sliderTheme.disabledThumbColor,
      end: sliderTheme.thumbColor,
    );

    Paint paint = Paint();
    paint.color = colorTween.evaluate(enableAnimation);

    Rect rect = Rect.fromCenter(
        center: center, width: width, height: height);
    RRect rRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rRect, paint);

  }
}
