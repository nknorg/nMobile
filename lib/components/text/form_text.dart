import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/components/base/stateful.dart';

class FormText extends BaseStateFulWidget {
  dynamic value;
  final double fontSize;
  final Color? fontColor;
  final EdgeInsetsGeometry padding;
  final bool password;
  TextEditingController? controller;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;
  final int minLines;
  final int maxLines;
  FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool maxLengthEnforced;
  List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  ValueChanged<String>? onChanged;
  VoidCallback? onEditingComplete;
  ValueChanged<String>? onFieldSubmitted;
  FormFieldSetter<String>? onSaved;
  // decoration
  String? hintText;
  String? helperText;
  final bool showErrorMessage;
  Widget? suffixIcon;
  final Color? borderColor;

  FormText({
    this.value,
    this.fontSize = 14,
    this.fontColor,
    this.padding = const EdgeInsets.only(bottom: 8),
    this.password = false,
    this.controller,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
    this.minLines = 1,
    this.maxLines = 1,
    this.validator,
    this.keyboardType,
    this.maxLength,
    this.maxLengthEnforced = true,
    this.inputFormatters,
    this.textInputAction,
    this.onChanged,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.onSaved,
    // decoration
    this.hintText,
    this.helperText,
    this.showErrorMessage = true,
    this.suffixIcon,
    this.borderColor,
  });

  @override
  _FormTextState createState() => _FormTextState();
}

class _FormTextState extends BaseStateFulWidgetState<FormText> {
  bool _showPassword = false;

  @override
  void onRefreshArguments() {}

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
          style: TextStyle(fontSize: widget.fontSize, color: widget.fontColor ?? application.theme.fontColor1),
          controller: widget.controller,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          obscureText: !_showPassword,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          maxLength: widget.maxLength,
          maxLengthEnforced: widget.maxLengthEnforced,
          inputFormatters: widget.inputFormatters,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onEditingComplete: widget.onEditingComplete,
          onFieldSubmitted: widget.onFieldSubmitted,
          onSaved: widget.onSaved,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(fontSize: widget.fontSize),
            helperText: widget.helperText,
            helperMaxLines: 3,
            errorStyle: widget.showErrorMessage ? null : TextStyle(height: 0, fontSize: 0),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _showPassword = !_showPassword),
              child: Opacity(opacity: _showPassword ? 1 : 0.25, child: Icon(FontAwesomeIcons.eye, size: 20)),
            ),
            disabledBorder: borderStyle,
            enabledBorder: borderStyle,
          ),
        ),
      );
    } else {
      return Padding(
        padding: widget.padding,
        child: TextFormField(
          initialValue: widget.value,
          style: TextStyle(fontSize: widget.fontSize, color: widget.fontColor ?? application.theme.fontColor1),
          controller: widget.controller,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          maxLength: widget.maxLength,
          maxLengthEnforced: widget.maxLengthEnforced,
          inputFormatters: widget.inputFormatters,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onEditingComplete: widget.onEditingComplete,
          onFieldSubmitted: widget.onFieldSubmitted,
          onSaved: widget.onSaved,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(fontSize: widget.fontSize),
            helperText: widget.helperText,
            errorStyle: widget.showErrorMessage ? null : TextStyle(height: 0, fontSize: 0),
            suffixIcon: widget.suffixIcon,
            disabledBorder: borderStyle,
            enabledBorder: borderStyle,
          ),
        ),
      );
    }
  }
}
