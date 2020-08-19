import 'package:flutter/material.dart';

extension ParseNumbers on String {
  int parseInt() {
    return int.parse(this);
  }

  double parseDouble() {
    return double.parse(this);
  }
}

extension PaddingInt on num {
  EdgeInsets pad({double l: -1, double t: -1, double r: -1, double b: -1, replace: false}) => EdgeInsets.only(
      left: l < 0 ? this < 0 ? 0 : this.toDouble() : l,
      top: t < 0 ? this < 0 ? 0 : this.toDouble() : t,
      right: r < 0 ? this < 0 ? 0 : this.toDouble() : r,
      bottom: b < 0 ? this < 0 ? 0 : this.toDouble() : b);

  EdgeInsets symm({double v = 0}) => EdgeInsets.symmetric(horizontal: this.toDouble(), vertical: v);
}

extension PaddingEdgeInsets on EdgeInsets {
  EdgeInsets pad({double l: 0, double t: 0, double r: 0, double b: 0, replace: false}) =>
      EdgeInsets.only(left: l < 0 ? 0 : l, top: t < 0 ? 0 : t, right: r < 0 ? 0 : r, bottom: b < 0 ? 0 : b);
}

extension PaddingWidget on Widget {
  Padding pad({double l: 0, double t: 0, double r: 0, double b: 0, replace: false}) =>
      padd(EdgeInsets.only(left: l < 0 ? 0 : l, top: t < 0 ? 0 : t, right: r < 0 ? 0 : r, bottom: b < 0 ? 0 : b), replace: replace);

  Padding symm({double h = 0, double v = 0}) => padd(EdgeInsets.symmetric(horizontal: h, vertical: v), replace: true);

  Padding padd(EdgeInsets padding, {bool replace = false}) =>
      replace ? Padding(padding: padding, child: this is Padding ? (this as Padding).child : this) : Padding(padding: padding, child: this);
}

extension AlignWidget on Widget {
  Align align(Alignment align) => Align(child: this, alignment: align);
}

extension OffstageWidget on Widget {
  Widget offstage(bool off, {bool add = false}) => add ? Offstage(offstage: off, child: this) : off ? Offstage(offstage: true, child: this) : this;
}

extension SingleWidgetToList on Widget {
  List<Widget> get toList => [this];
}

extension SizedBoxWidget on Widget {
  SizedBox sized({double w, double h}) => SizedBox(width: w, height: h, child: this);
}

extension CenterWidget on Widget {
  Center get center => Center(child: this);
}

extension InkWellWidget on Widget {
  InkWell inkWell(void onTap()) {
    return InkWell(child: this, onTap: onTap);
  }
}

extension NumToDoubleOrInt on num {
  int get i => this.round();

  double get d => this.roundToDouble();
}

class Space {
  static Container get empty => Container();
}

extension CheckAnything on dynamic {
  bool get isNull => this == null;

  bool get nonNull => this != null;
}

bool nonEmpty(String s) {
  return s != null && s.isNotEmpty;
}

bool isEmpty(String s) {
  return s == null || s.isEmpty;
}

main() {
  // e.g.
  print('42'.parseInt());
}
