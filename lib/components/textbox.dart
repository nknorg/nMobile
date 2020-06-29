import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';

class Textbox extends StatefulWidget {
  dynamic value;
  final EdgeInsetsGeometry padding;
  final bool multi;
  final int minLines;
  final int maxLines;
  final double fontSize;
  final bool password;
  FormFieldValidator<String> validator;
  TextEditingController controller;
  final bool showErrorMessage;
  String hintText;
  String helperText;
  Widget suffixIcon;
  final bool autofocus;
  final FocusNode focusNode;
  final TextInputType keyboardType;
  final bool enabled;
  final bool readOnly;
  FormFieldSetter<String> onSaved;
  final TextInputAction textInputAction;
  ValueChanged<String> onChanged;
  ValueChanged<String> onFieldSubmitted;
  List<TextInputFormatter> inputFormatters;
  final int maxLength;
  final bool maxLengthEnforced;
  final Color borderColor;
  final Color color;

  Textbox({this.value, this.color = Colours.dark_2d, this.padding = const EdgeInsets.only(bottom: 10), this.showErrorMessage = true,
    this.enabled = true, this.readOnly = false, this.multi = false, this.minLines, this.maxLines = 3,
    this.autofocus = false, this.focusNode, this.controller, this.password = false, this.validator,
    this.hintText, this.helperText, this.keyboardType, this.textInputAction, this.suffixIcon,
    this.onSaved, this.onChanged, this.onFieldSubmitted, this.inputFormatters, this.maxLength,
    this.maxLengthEnforced = true, this.fontSize = 14, this.borderColor});

  @override
  _TextboxState createState() => _TextboxState();
}

class _TextboxState extends State<Textbox> {
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    InputBorder borderStyle = UnderlineInputBorder(borderSide: BorderSide(color: widget.borderColor ?? DefaultTheme.line, width: 0.8.h));
    if (widget.password) {
      return Padding(
        padding: widget.padding,
        child: TextFormField(
          initialValue: widget.value,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          controller: widget.controller,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          inputFormatters: widget.inputFormatters,
          style: TextStyle(fontSize: widget.fontSize, color: widget.color),
          decoration: InputDecoration(
            disabledBorder: borderStyle,
            enabledBorder: borderStyle,
            errorStyle: widget.showErrorMessage
                ? null
                : TextStyle(
                    height: 0,
                    fontSize: 0,
                  ),
            hintText: widget.hintText,
            helperMaxLines: 3,
            hintStyle: TextStyle(fontSize: widget.fontSize),
            helperText: widget.helperText,
            suffixIcon: GestureDetector(
              onTap: () {
                setState(() {
                  _showPassword = !_showPassword;
                });
              },
              child: Opacity(
                  opacity: _showPassword ? 1 : 0.25,
                  child: Icon(
                    FontAwesomeIcons.eye,
                    size: 20,
                  )),
            ),
          ),
          validator: widget.validator,
          obscureText: !_showPassword,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onSaved: widget.onSaved,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          maxLength: widget.maxLength,
          maxLengthEnforced: widget.maxLengthEnforced,
        ),
      );
    } else {
      return Padding(
        padding: widget.padding,
        child: TextFormField(
          initialValue: widget.value,
          minLines: widget.minLines,
          maxLines: widget.multi ? widget.maxLines : 1,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          controller: widget.controller,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          style: TextStyle(fontSize: widget.fontSize, color: widget.color),
          inputFormatters: widget.inputFormatters,
          decoration: InputDecoration(
              errorStyle: widget.showErrorMessage
                  ? null
                  : TextStyle(
                      height: 0,
                      fontSize: 0,
                    ),
              hintText: widget.hintText,
              hintStyle: TextStyle(fontSize: widget.fontSize),
              helperText: widget.helperText,
              suffixIcon: widget.suffixIcon,
              disabledBorder: borderStyle,
              enabledBorder: borderStyle),
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onSaved: widget.onSaved,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          maxLength: widget.maxLength,
          maxLengthEnforced: widget.maxLengthEnforced,
        ),
      );
    }
  }
}
