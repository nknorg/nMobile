import 'package:flutter/material.dart';
import 'package:nmobile/components/base/stateful.dart';

class DropDownScaleLayout extends BaseStateFulWidget {
  final Widget content;
  final double triggerOffsetY;
  final Function()? onDragStart;
  final Function(double)? onDragUpdate;
  final Function(bool)? onDragEnd;

  DropDownScaleLayout({
    required this.content,
    this.triggerOffsetY = 100,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  _DropDownScaleLayoutState createState() => _DropDownScaleLayoutState();
}

class _DropDownScaleLayoutState extends BaseStateFulWidgetState<DropDownScaleLayout> {
  bool isDrag = false;

  Offset? _startPoint;
  Offset? _preFocalPoint;
  Offset _curDeltaOffset = Offset(0.0, 0.0);
  Offset _totDeltaOffset = Offset(0.0, 0.0);
  double _totDeltaScale = 1.0;

  @override
  void onRefreshArguments() {}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Container(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _handleOnScaleStart,
          onScaleUpdate: _handleOnScaleUpdate,
          onScaleEnd: _handleOnScaleEnd,
          child: _transform(),
        ),
      ),
    );
  }

  void _handleOnScaleStart(ScaleStartDetails details) {
    isDrag = false;

    _startPoint = details.focalPoint;
    _preFocalPoint = _startPoint;
    _curDeltaOffset = Offset(0.0, 0.0);
    _totDeltaOffset = Offset(0.0, 0.0);
    _totDeltaScale = 1.0;
  }

  void _handleOnScaleUpdate(ScaleUpdateDetails details) {
    // pre focus point
    Offset? preFocalPoint = _preFocalPoint ?? _startPoint;
    if (preFocalPoint == null) {
      _preFocalPoint = details.focalPoint;
      return;
    }
    if (_totDeltaOffset.dy < 0) return;
    // current offset
    _curDeltaOffset = details.focalPoint - preFocalPoint;
    if ((_totDeltaScale == 1) && ((_curDeltaOffset.dx.abs() >= 2) || ((_curDeltaOffset.dy >= -5) && (_curDeltaOffset.dy <= 5)))) return;
    if ((_curDeltaOffset.dy >= -2) && (_curDeltaOffset.dy <= 2)) return;
    // drag start
    if (!isDrag) this.widget.onDragStart?.call();
    isDrag = true;
    // total scale
    if (_curDeltaOffset.dy < -2) {
      _totDeltaScale += 0.005;
    } else {
      _totDeltaScale -= 0.005;
    }
    if (_totDeltaScale < 0.3) _totDeltaScale = 0.3;
    if (_totDeltaScale > 1) _totDeltaScale = 1;
    // total offset
    _totDeltaOffset += _curDeltaOffset;
    // refresh view
    setState(() {});
    double percent = _totDeltaOffset.dy / this.widget.triggerOffsetY;
    if (percent >= 0) this.widget.onDragUpdate?.call(percent);
    // save pre focus focus
    _preFocalPoint = details.focalPoint;
  }

  void _handleOnScaleEnd(ScaleEndDetails details) {
    if (_totDeltaOffset.dy >= this.widget.triggerOffsetY) {
      this.widget.onDragEnd?.call(true);
      return;
    }
    _startPoint = null;
    _preFocalPoint = null;
    _curDeltaOffset = Offset(0.0, 0.0);
    _totDeltaOffset = Offset(0.0, 0.0);
    _totDeltaScale = 1.0;
    setState(() {});
    if (isDrag) this.widget.onDragEnd?.call(false);
    isDrag = false;
  }

  _transform() {
    return Transform.translate(
      offset: _totDeltaOffset,
      child: Transform.scale(
        child: this.widget.content,
        scale: _totDeltaScale,
        origin: _totDeltaOffset,
      ),
    );
  }
}
