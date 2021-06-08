import 'dart:core';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class TrianglePainter extends CustomPainter {
  bool isDown;
  Color color;

  TrianglePainter({this.isDown = true, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    Paint _paint = new Paint();
    _paint.strokeWidth = 2.0;
    _paint.color = color;
    _paint.style = PaintingStyle.fill;

    Path path = new Path();
    if (isDown) {
      path.moveTo(0.0, -1.0);
      path.lineTo(size.width, -1.0);
      path.lineTo(size.width / 2.0, size.height);
    } else {
      path.moveTo(size.width / 2.0, 0.0);
      path.lineTo(0.0, size.height + 1);
      path.lineTo(size.width, size.height + 1);
    }

    canvas.drawPath(path, _paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

abstract class MenuItemProvider {
  String? get menuTitle;
  Widget? get menuImage;
  TextStyle? get menuTextStyle;
}

class MenuItem extends MenuItemProvider {
  Widget? image;
  String? title;
  dynamic userInfo;
  TextStyle? textStyle;

  MenuItem({this.title, this.image, this.userInfo, this.textStyle});

  @override
  Widget? get menuImage => image;

  @override
  String? get menuTitle => title;

  @override
  TextStyle get menuTextStyle => textStyle ?? TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0);
}

enum MenuType { big, oneLine }

typedef MenuClickCallback = Function(MenuItemProvider item);
typedef PopupMenuStateChanged = Function(bool isShow);

class PopupMenu {
  static var itemWidth = 68.0;
  static var itemHeight = 36.0;
  static var arrowHeight = 10.0;

  OverlayEntry? _entry;
  late List<MenuItemProvider> items;

  /// row count
  int _row = 1;

  /// col count
  int _col = 1;

  /// The left top point of this menu.
  late Offset _offset;

  /// Menu will show at above or under this rect
  late Rect _showRect;

  /// if false menu is show above of the widget, otherwise menu is show under the widget
  bool _isDown = true;

  /// The max column count, default is 4.
  int _maxColumn = 4;

  /// callback
  VoidCallback? dismissCallback;
  MenuClickCallback? onClickMenu;
  PopupMenuStateChanged? stateChanged;

  late Size _screenSize; // 屏幕的尺寸

  /// Cannot be null
  late BuildContext context;

  /// style
  late Color _backgroundColor;
  late Color _highlightColor;
  late Color _lineColor;

  /// It's showing or not.
  bool _isShow = false;
  bool get isShow => _isShow;

  PopupMenu({
    required BuildContext context,
    required List<MenuItemProvider> items,
    MenuClickCallback? onClickMenu,
    VoidCallback? onDismiss,
    int? maxColumn,
    Color? backgroundColor,
    Color? highlightColor,
    Color? lineColor,
    PopupMenuStateChanged? stateChanged,
  }) {
    this.context = context;
    this.onClickMenu = onClickMenu;
    this.dismissCallback = onDismiss;
    this.stateChanged = stateChanged;
    this.items = items;
    this._maxColumn = maxColumn ?? 4;
    this._backgroundColor = backgroundColor ?? Color(0xff232323);
    this._lineColor = lineColor ?? Color(0xff353535);
    this._highlightColor = highlightColor ?? Color(0x55000000);
  }

  void show({Rect? rect, GlobalKey? widgetKey, List<MenuItemProvider>? items}) {
    if (rect == null && widgetKey == null) return;

    this.items = items ?? this.items;
    this._showRect = rect ?? PopupMenu.getWidgetGlobalRect(widgetKey!) ?? Rect.zero;
    this._screenSize = window.physicalSize / window.devicePixelRatio;
    this.dismissCallback = dismissCallback;

    _calculatePosition(this.context);

    _entry = OverlayEntry(builder: (context) {
      return buildPopupMenuLayout(_offset);
    });

    Overlay.of(this.context)?.insert(_entry!);
    _isShow = true;
    this.stateChanged?.call(true);
  }

  static Rect? getWidgetGlobalRect(GlobalKey key) {
    RenderObject? object = key.currentContext?.findRenderObject();
    if (!(object is RenderBox)) return null;
    var offset = object.localToGlobal(Offset.zero);
    return Rect.fromLTWH(offset.dx, offset.dy, object.size.width, object.size.height);
  }

  void _calculatePosition(BuildContext context) {
    _col = _calculateColCount();
    _row = _calculateRowCount();
    _offset = _calculateOffset(this.context);
  }

  Offset _calculateOffset(BuildContext context) {
    double dx = _showRect.left + _showRect.width / 2.0 - menuWidth() / 2.0;
    if (dx < 10.0) {
      dx = 10.0;
    }

    if (dx + menuWidth() > _screenSize.width && dx > 10.0) {
      double tempDx = _screenSize.width - menuWidth() - 10;
      if (tempDx > 10) dx = tempDx;
    }

    double dy = _showRect.top - menuHeight();
    if (dy <= MediaQuery.of(context).padding.top + 10) {
      // The have not enough space above, show menu under the widget.
      dy = arrowHeight + _showRect.height + _showRect.top;
      _isDown = false;
    } else {
      dy -= arrowHeight;
      _isDown = true;
    }

    return Offset(dx, dy);
  }

  double menuWidth() {
    return itemWidth * _col;
  }

  // This height exclude the arrow
  double menuHeight() {
    return itemHeight * _row;
  }

  LayoutBuilder buildPopupMenuLayout(Offset offset) {
    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          dismiss();
        },
//        onTapDown: (TapDownDetails details) {
//          dismiss();
//        },
        // onPanStart: (DragStartDetails details) {
        //   dismiss();
        // },
        onVerticalDragStart: (DragStartDetails details) {
          dismiss();
        },
        onHorizontalDragStart: (DragStartDetails details) {
          dismiss();
        },
        child: Container(
          child: Stack(
            children: <Widget>[
              // triangle arrow
              Positioned(
                left: _showRect.left + _showRect.width / 2.0 - 7.5,
                top: _isDown ? offset.dy + menuHeight() : offset.dy - arrowHeight,
                child: CustomPaint(
                  size: Size(15.0, arrowHeight),
                  painter: TrianglePainter(isDown: _isDown, color: _backgroundColor),
                ),
              ),
              // menu content
              Positioned(
                left: offset.dx,
                top: offset.dy,
                child: Container(
                  width: menuWidth(),
                  height: menuHeight(),
                  child: Column(
                    children: <Widget>[
                      ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: Container(
                            width: menuWidth(),
                            height: menuHeight(),
                            decoration: BoxDecoration(color: _backgroundColor, borderRadius: BorderRadius.circular(10.0)),
                            child: Column(
                              children: _createRows(),
                            ),
                          )),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      );
    });
  }

  // 创建行
  List<Widget> _createRows() {
    List<Widget> rows = [];
    for (int i = 0; i < _row; i++) {
      Color color = (i < _row - 1 && _row != 1) ? _lineColor : Colors.transparent;
      Widget rowWidget = Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color))),
        height: itemHeight,
        child: Row(
          children: _createRowItems(i),
        ),
      );

      rows.add(rowWidget);
    }

    return rows;
  }

  // 创建一行的item,  row 从0开始算
  List<Widget> _createRowItems(int row) {
    List<MenuItemProvider> subItems = items.sublist(row * _col, min(row * _col + _col, items.length));
    List<Widget> itemWidgets = [];
    int i = 0;
    for (var item in subItems) {
      itemWidgets.add(_createMenuItem(
        item,
        i < (_col - 1),
      ));
      i++;
    }

    return itemWidgets;
  }

  // calculate row count
  int _calculateRowCount() {
    if (items.isEmpty) return 0;

    int itemCount = items.length;

    if (_calculateColCount() == 1) {
      return itemCount;
    }

    int row = (itemCount - 1) ~/ _calculateColCount() + 1;

    return row;
  }

  // calculate col count
  int _calculateColCount() {
    if (items.isEmpty) return 0;

    int itemCount = items.length;
    if (_maxColumn != 4 && _maxColumn > 0) {
      return _maxColumn;
    }

    if (itemCount == 4) {
      // 4个显示成两行
      return 2;
    }

    if (itemCount <= _maxColumn) {
      return itemCount;
    }

    if (itemCount == 5) {
      return 3;
    }

    if (itemCount == 6) {
      return 3;
    }

    return _maxColumn;
  }

  double get screenWidth {
    double width = window.physicalSize.width;
    double ratio = window.devicePixelRatio;
    return width / ratio;
  }

  Widget _createMenuItem(MenuItemProvider item, bool showLine) {
    return _MenuItemWidget(
      item: item,
      showLine: showLine,
      clickCallback: itemClicked,
      lineColor: _lineColor,
      backgroundColor: _backgroundColor,
      highlightColor: _highlightColor,
    );
  }

  void itemClicked(MenuItemProvider item) {
    onClickMenu?.call(item);
    dismiss();
  }

  void dismiss() {
    if (!_isShow) {
      // Remove method should only be called once
      return;
    }

    _entry?.remove();
    _isShow = false;
    dismissCallback?.call();
    this.stateChanged?.call(false);
  }
}

class _MenuItemWidget extends StatefulWidget {
  final MenuItemProvider item;
  final Color lineColor;
  final Color backgroundColor;
  final Color highlightColor;
  final bool showLine;
  final Function(MenuItemProvider item)? clickCallback;

  _MenuItemWidget({
    required this.item,
    required this.lineColor,
    required this.backgroundColor,
    required this.highlightColor,
    this.showLine = false,
    this.clickCallback,
  });

  @override
  State<StatefulWidget> createState() {
    return _MenuItemWidgetState();
  }
}

class _MenuItemWidgetState extends State<_MenuItemWidget> {
  var highlightColor = Color(0x55000000);
  var color = Color(0xff232323);

  @override
  void initState() {
    color = widget.backgroundColor;
    highlightColor = widget.highlightColor;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        color = highlightColor;
        setState(() {});
      },
      onTapUp: (details) {
        color = widget.backgroundColor;
        setState(() {});
      },
      onLongPressEnd: (details) {
        color = widget.backgroundColor;
        setState(() {});
      },
      onTap: () {
        widget.clickCallback?.call(widget.item);
      },
      child: Container(
        width: PopupMenu.itemWidth,
        height: PopupMenu.itemHeight,
        decoration: BoxDecoration(color: color, border: Border(right: BorderSide(color: widget.showLine ? widget.lineColor : Colors.transparent))),
        child: _createContent(),
      ),
    );
  }

  Widget _createContent() {
    if (widget.item.menuImage != null) {
      // image and text
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 30.0,
            height: 30.0,
            child: widget.item.menuImage,
          ),
          Container(
            height: 22.0,
            child: Material(
              color: Colors.transparent,
              child: Text(
                widget.item.menuTitle ?? " ",
                style: widget.item.menuTextStyle,
              ),
            ),
          )
        ],
      );
    } else {
      // only text
      return Container(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Text(
              widget.item.menuTitle ?? " ",
              style: widget.item.menuTextStyle,
            ),
          ),
        ),
      );
    }
  }
}
