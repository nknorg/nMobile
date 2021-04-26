import 'package:flutter/cupertino.dart';

abstract class BaseScreen extends StatefulWidget {
  final Map arguments;

  BaseScreen({this.arguments});

  @override
  BaseScreenState createState();
}

abstract class BaseScreenState<T extends StatefulWidget> extends State<T> {
  @override
  void initState() {
    // TODO:GG log
    super.initState();
  }

  @override
  void didChangeDependencies() {
    // TODO:GG log
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    // TODO:GG log
    super.didUpdateWidget(oldWidget);
  }

  @override
  void deactivate() {
    // TODO:GG log
    super.deactivate();
  }

  @override
  void dispose() {
    // TODO:GG log
    super.dispose();
  }
}
