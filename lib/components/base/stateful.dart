import 'package:flutter/widgets.dart';

abstract class BaseStateFulWidget extends StatefulWidget {
  const BaseStateFulWidget({Key? key}) : super(key: key);
}

abstract class BaseStateFulWidgetState<T extends StatefulWidget> extends State<T> {
  @override
  void initState() {
    super.initState();
    onRefreshArguments();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    onRefreshArguments();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  @protected
  void onRefreshArguments();
}
