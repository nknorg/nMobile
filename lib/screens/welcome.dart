import 'package:flutter/material.dart';

class Welcome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Image(
        image: AssetImage('assets/splash/splash@2x.png'),
        alignment: Alignment.bottomCenter,
        fit: BoxFit.contain,
      ),
    );
  }
}
