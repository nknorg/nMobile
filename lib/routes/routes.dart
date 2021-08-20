import 'package:flutter/material.dart';
import 'package:nmobile/app.dart';
import 'package:nmobile/routes/chat.dart' as chat;
import 'package:nmobile/routes/contact.dart' as contact;
import 'package:nmobile/routes/home.dart' as home;
import 'package:nmobile/routes/settings.dart' as settings;
import 'package:nmobile/routes/topic.dart' as topic;
import 'package:nmobile/routes/wallet.dart' as wallet;

class Routes {
  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  static Map<String, WidgetBuilder> _routes = {};

  static init() {
    registerRoutes({
      AppScreen.routeName: (BuildContext context, {arguments}) => AppScreen(arguments: arguments),
    });
    home.init();
    settings.init();
    wallet.init();
    contact.init();
    topic.init();
    chat.init();
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final String? name = settings.name;
    final Function? pageContentBuilder = _routes[name];
    if (pageContentBuilder != null) {
      if (settings.arguments != null) {
        return MaterialPageRoute(
          settings: RouteSettings(name: name),
          builder: (context) => pageContentBuilder(context, arguments: settings.arguments),
        );
      } else {
        return MaterialPageRoute(
          settings: RouteSettings(name: name),
          builder: (context) => pageContentBuilder(context),
        );
      }
    }
    return null;
  }

  static registerRoutes(Map<String, WidgetBuilder> routes) {
    _routes.addAll(routes);
  }
}

// class CustomRoute extends PageRouteBuilder {
//   final Widget widget;
//
//   CustomRoute(this.widget)
//       : super(
//           transitionDuration: Duration(milliseconds: 500),
//           pageBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2) {
//             return widget;
//           },
//           transitionsBuilder: (BuildContext context, Animation<double> animation1, Animation<double> animation2, Widget child) {
//             return FadeTransition(
//               opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
//                 parent: animation1,
//                 curve: Curves.fastOutSlowIn,
//               )),
//               child: child,
//             );
//           },
//         );
// }
