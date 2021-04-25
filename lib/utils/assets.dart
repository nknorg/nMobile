import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

Widget assetIcon(String name, {double width, Color color}) {
  return SvgPicture.asset(
    'assets/icons/$name.svg',
    color: color,
    width: width,
  );
}

Widget assetImage(String path, {double width, double height, BoxFit fit, Color color, double scale}) {
  return Image.asset(
    'assets/$path',
    height: height,
    width: width,
    scale: scale,
    fit: fit,
    color: color,
  );
}