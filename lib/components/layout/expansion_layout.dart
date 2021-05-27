import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

const Duration _kExpand = Duration(milliseconds: 200);

class ExpansionLayout extends StatefulWidget {
  final Widget child;
  final bool isExpanded;
  final Color? backgroundColor;
  final Widget? trailing;
  final ValueChanged<bool>? onExpansionChanged;

  const ExpansionLayout({
    Key? key,
    required this.child,
    this.isExpanded = false,
    this.backgroundColor,
    this.onExpansionChanged,
    this.trailing,
  }) : super(key: key);

  @override
  _ExpansionLayoutState createState() => _ExpansionLayoutState();
}

class _ExpansionLayoutState extends State<ExpansionLayout> with SingleTickerProviderStateMixin {
  static final Animatable<double> _easeInTween = CurveTween(curve: Curves.easeIn);
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: _kExpand, vsync: this);
    _heightFactor = _controller.drive(_easeInTween);
    _isExpanded = widget.isExpanded;
    if (_isExpanded) _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = widget.isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse().then<void>((void value) {
          if (!mounted) return;
        });
      }
      PageStorage.of(context)?.writeState(context, _isExpanded);
    });
    if (widget.onExpansionChanged != null) widget.onExpansionChanged!(_isExpanded);
  }

  Widget _buildChildren(BuildContext context, Widget? child) {
    return Container(
      child: ClipRect(
        child: Align(
          heightFactor: _heightFactor.value,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _handleTap();
    final bool closed = !_isExpanded && _controller.isDismissed;
    return AnimatedBuilder(
      animation: _controller.view,
      builder: _buildChildren,
      child: closed ? null : widget.child,
    );
  }
}
