import 'package:flutter/widgets.dart';

abstract class BaseStateFulWidget extends StatefulWidget {
  const BaseStateFulWidget({Key? key}) : super(key: key);
}

abstract class BaseStateFulWidgetState<T extends StatefulWidget> extends State<T> {
  // will rebuild views after onRefreshArguments call
  @protected
  void onRefreshArguments();

  // @override
  // State createState() {
  //   return super.createState();
  // }

  @override
  void initState() {
    super.initState();
    onRefreshArguments();
  }

  // @override
  // Widget build(BuildContext context) {
  //   return super.build(context);
  // }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    onRefreshArguments();
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }
}
