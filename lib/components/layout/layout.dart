import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';

class Layout extends StatelessWidget {
  final Key? key;
  final Color headerColor;
  final PreferredSizeWidget? header;
  final Color? bodyColor;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final BorderRadius? borderRadius;
  final bool clipAlias;

  Layout({
    this.key,
    required this.headerColor,
    this.header,
    this.bodyColor,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(32)),
    this.clipAlias = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: this.key,
      backgroundColor: this.headerColor,
      appBar: this.header,
      floatingActionButton: this.floatingActionButton,
      floatingActionButtonLocation: this.floatingActionButtonLocation,
      body: Container(
        constraints: BoxConstraints.expand(),
        decoration: BoxDecoration(
          borderRadius: this.borderRadius ?? BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: PhysicalModel(
          elevation: 0,
          clipBehavior: this.clipAlias ? Clip.antiAlias : Clip.none,
          color: this.bodyColor ?? application.theme.backgroundColor,
          borderRadius: this.borderRadius ?? BorderRadius.vertical(top: Radius.circular(32)),
          child: Column(
            children: <Widget>[
              Expanded(
                child: this.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
