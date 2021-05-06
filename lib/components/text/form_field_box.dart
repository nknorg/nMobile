import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/common/locator.dart';

class FormFieldBox extends StatefulWidget {
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

  FormFieldBox({
    this.value,
    this.color,
    this.padding = const EdgeInsets.only(bottom: 8),
    this.showErrorMessage = true,
    this.enabled = true,
    this.readOnly = false,
    this.multi = false,
    this.minLines,
    this.maxLines = 3,
    this.autofocus = false,
    this.focusNode,
    this.controller,
    this.password = false,
    this.validator,
    this.hintText,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.onSaved,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.maxLength,
    this.maxLengthEnforced = true,
    this.fontSize = 14,
    this.borderColor,
  });

  @override
  _FormFieldBoxState createState() => _FormFieldBoxState();
}

class _FormFieldBoxState extends State<FormFieldBox> {
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    InputBorder borderStyle = UnderlineInputBorder(
      borderSide: BorderSide(
        color: widget.borderColor ?? application.theme.lineColor,
        width: 1,
      ),
    );
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
          style: TextStyle(fontSize: widget.fontSize, color: widget.color ?? application.theme.fontColor1),
          decoration: InputDecoration(
            disabledBorder: borderStyle,
            enabledBorder: borderStyle,
            errorStyle: widget.showErrorMessage ? null : TextStyle(height: 0, fontSize: 0),
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
                child: Icon(FontAwesomeIcons.eye, size: 20),
              ),
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
          style: TextStyle(fontSize: widget.fontSize, color: widget.color ?? application.theme.fontColor1),
          inputFormatters: widget.inputFormatters,
          decoration: InputDecoration(
            errorStyle: widget.showErrorMessage ? null : TextStyle(height: 0, fontSize: 0),
            hintText: widget.hintText,
            hintStyle: TextStyle(fontSize: widget.fontSize),
            helperText: widget.helperText,
            suffixIcon: widget.suffixIcon,
            disabledBorder: borderStyle,
            enabledBorder: borderStyle,
          ),
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
