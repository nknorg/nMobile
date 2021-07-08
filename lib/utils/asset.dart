import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Asset {
  static Image image(
    String path, {
    double? width,
    double? height,
    Color? color,
    double scale = 1,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry align = Alignment.center,
  }) {
    return Image.asset(
      'assets/$path',
      width: width,
      height: height,
      color: color,
      scale: scale,
      fit: fit,
      alignment: align,
    );
  }

  static SvgPicture svg(
    String path, {
    double? width,
    double? height,
    Color? color,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry align = Alignment.center,
    Clip clip = Clip.none,
  }) {
    return SvgPicture.asset(
      'assets/$path.svg',
      width: width,
      height: height,
      color: color,
      fit: fit,
      alignment: align,
      clipBehavior: clip,
    );
  }

  static SvgPicture iconSvg(
    String name, {
    double? width,
    double? height,
    Color? color,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry align = Alignment.center,
    Clip clip = Clip.none,
  }) {
    return svg(
      'icons/$name',
      width: width,
      height: height,
      color: color,
      fit: fit,
      align: align,
      clip: clip,
    );
  }
}
