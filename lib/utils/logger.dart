import 'dart:convert';

import 'package:logger/logger.dart';

Logger logger = Logger(
  filter: null,
  printer: ColorPrinter(),
  output: null,
  level: Level.verbose,
);

mixin Tag {
  String get TAG => _tagInner(32, 5);

  String _tagInner(int length, int lenHashCode) {
    final String name = this.runtimeType.toString() + '@' + hashCode.toString().substring(0, lenHashCode);
    return name;
    // if (name.length > length) {
    //   return name.substring(name.length - length);
    // } else
    //   return name.padLeft(length, '.');
  }
}

class ColorPrinter extends LogPrinter {
  static final levelPrefixes = {
    Level.verbose: '[V]',
    Level.debug: '[D]',
    Level.info: '[I]',
    Level.warning: '[W]',
    Level.error: '[E]',
    Level.wtf: '[WTF]',
  };

  static final levelColors = {
    Level.verbose: AnsiColor.fg(AnsiColor.grey(0.5)),
    Level.debug: AnsiColor.none(),
    Level.info: AnsiColor.fg(12),
    Level.warning: AnsiColor.fg(208),
    Level.error: AnsiColor.fg(196),
    Level.wtf: AnsiColor.fg(199),
  };

  final bool printTime;
  final bool colors;

  ColorPrinter({this.printTime = true, this.colors = true});

  @override
  List<String> log(LogEvent event) {
    var color = levelColors[event.level]!;
    var messageStr = color(_stringifyMessage(event.message));
    var errorStr = event.error != null ? color('  ERROR: ${event.error}') : '';
    var timeStr = printTime ? color('TIME: ${DateTime.now().toIso8601String()}') : '';
    return ['${_labelFor(event.level)}  $timeStr  $messageStr  <<<ERROR>>>:$errorStr'];
  }

  String _labelFor(Level level) {
    var prefix = levelPrefixes[level]!;
    var color = levelColors[level]!;

    return colors ? color(prefix) : prefix;
  }

  String _stringifyMessage(dynamic message) {
    if (message is Map || message is Iterable) {
      var encoder = JsonEncoder.withIndent(null);
      return encoder.convert(message);
    } else {
      return message.toString();
    }
  }
}
