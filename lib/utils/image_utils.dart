import 'package:cached_network_image/cached_network_image.dart';
import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';

class ImageUtils {}

Widget loadAssetImage(String name, {double width, double height, BoxFit fit, Color color, double scale}) {
  return Image.asset(
    getImgPath(name),
    height: height,
    width: width,
    scale: scale,
    fit: fit,
    color: color,
  );
}

Widget loadAssetChatPng(String name, {double width, double height, BoxFit fit, Color color, double scale}) {
  return Image.asset(
    getImgPath(name, path: 'chat'),
    height: height,
    width: width,
    scale: scale,
    fit: fit,
    color: color,
  );
}

Widget loadAssetChatSvg(String name, {double width, double height, BoxFit fit, Color color, double scale}) {
  return SvgPicture.asset(
    'assets/chat/$name.svg',
    color: color,
    width: width,
  );
}

Widget loadAssetContactImage(String name, {double width, double height, BoxFit fit, Color color, double scale}) {
  return Image.asset(
    getImgPath(name, path: 'contact'),
    height: height,
    width: width,
    scale: scale,
    fit: fit,
    color: color,
  );
}

Widget loadAssetIconsImage(String name, {double width, Color color}) {
  return SvgPicture.asset(
    'assets/icons/$name.svg',
    color: color,
    width: width,
  );
}

Widget loadAssetSplashImage(String name, {double width, double height, BoxFit fit, Color color, double scale}) {
  return Image.asset(
    getImgPath(name, path: 'splash'),
    height: height,
    width: width,
    scale: scale,
    fit: fit,
    color: color,
  );
}

Widget loadAssetWalletImage(String name, {double width, double height, BoxFit fit, Color color, double scale}) {
  return Image.asset(
    getImgPath(name, path: 'wallet'),
    height: height,
    width: width,
    scale: scale,
    fit: fit,
    color: color,
  );
}

Widget loadNetworkImage(String imageUrl, {double width, double height, BoxFit fit: BoxFit.cover, String holderImg: "ic_launcher"}) {
  if (TextUtil.isEmpty(imageUrl) || !imageUrl.startsWith('http')) {
    return loadAssetImage(holderImg, height: height, width: width, fit: fit);
  }
  return CachedNetworkImage(
    imageUrl: imageUrl,
    width: width,
    height: height,
    fit: fit,
  );
}

ImageProvider getImageProvider(String imageUrl, {String holderImg: ""}) {
  if (TextUtil.isEmpty(imageUrl)) {
    return AssetImage(getImgPath(holderImg));
  }
  return CachedNetworkImageProvider(imageUrl);
}

String getImgPath(String name, {String format: 'png', String path}) {
  if (path == null) {
    return 'assets/$name.$format';
  } else {
    return 'assets/$path/$name.$format';
  }
}
