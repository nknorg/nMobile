import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CommonWebViewPage extends StatefulWidget {
  String title;
  static final String routeName = "CommonWebViewPage";
  static final String titleName = "TITLE_NAME";
  static final String webUrl = "WEB_URL";

  final Map<String, dynamic> arguments;

  CommonWebViewPage({Key key, this.arguments}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return new CommonWebViewPageState();
  }
}

class CommonWebViewPageState extends State<CommonWebViewPage> {
  bool isLoad = false;

  String title = "";
  String currentUrl = '';

  WebViewController controller;
  @override
  void initState() {
    title = widget.arguments[CommonWebViewPage.titleName];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    String url = widget.arguments[CommonWebViewPage.webUrl];
    return WillPopScope(
        child: Scaffold(
          appBar: AppBar(
            title: Text(title ?? ''),
            elevation: 0,
            leading: IconButton(
                icon: Platform.isAndroid ? Icon(Icons.arrow_back) : Icon(Icons.arrow_back_ios),
                onPressed: () {
                  goBackAction();
                }),
            bottom: new PreferredSize(
              child: !isLoad
                  ? new SizedBox(
                      height: 2.0,
                      child: new LinearProgressIndicator(),
                    )
                  : new Divider(height: 1.0, color: Color(0xFFDFAF60)),
              preferredSize: const Size.fromHeight(1.0),
            ),
          ),
          body: SafeArea(
            child: WebView(
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (controller) {
                controller.loadUrl(url);
                this.controller = controller;
              },
              onPageFinished: (url) async {
                controller.getTitle().then((v) {
                  setState(() {
                    isLoad = true;
                    title = v;
                  });
                });

                _initData(controller, context);
              },
              navigationDelegate: (NavigationRequest request) {
                return NavigationDecision.navigate; // 允许跳转
              },
              javascriptChannels: _setJavascriptChannels(context).toSet(),
            ),
          ),
        ),
        onWillPop: () {
          goBackAction();
          return Future.value(false);
        });
  }

  goBackAction() {
    controller.canGoBack().then((b) {
      if (b) {
        controller.goBack();
      } else {
        Navigator.pop(context);
      }
    });
  }

  _initData(WebViewController controller, BuildContext context) {
    const String initScript = '''
  window.SetTitle.postMessage(document.title);
  var MutationObserver = window.MutationObserver || window.WebKitMutationObserver;
  var MutationObserverConfig = {
    childList: true,
    subtree: true,
    characterData: true
  };
  var observer = new MutationObserver(function (mutations) {
    window.SetTitle.postMessage(document.title);
  });
  observer.observe(document.querySelector('title'), MutationObserverConfig);
''';
    controller.evaluateJavascript(initScript);
  }

  List<JavascriptChannel> _setJavascriptChannels(BuildContext context) {
    List<JavascriptChannel> javascriptChannels = [
      JavascriptChannel(
        name: 'SetTitle',
        onMessageReceived: _setTitleHandle,
      ),
    ];
    return javascriptChannels;
  }

  _setTitleHandle(JavascriptMessage message) {
    if (message.message != null) {
      setState(() {
        title = message.message;
      });
    }
  }
}
