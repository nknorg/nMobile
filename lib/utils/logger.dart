import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:nmobile/common/settings.dart';

Logger logger = Logger(
  filter: CustomFilter(),
  printer: ColorPrinter(),
  output: null,
  level: Level.verbose,
);

class CustomFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (!Settings.debug) return false;
    bool isVerbose = event.level == Level.verbose;
    bool isDebug = event.level == Level.debug;
    bool isInfo = event.level == Level.info;
    bool isWarning = event.level == Level.warning;
    bool isError = event.level == Level.error;
    bool isWtf = event.level == Level.wtf;
    bool levelOk = isVerbose || isDebug || isInfo || isWarning || isError || isWtf;
    return levelOk;
  }
}

mixin Tag {
  String get TAG => _tagInner(32, 5);

  String _tagInner(int length, int lenHashCode) {
    String hashCodeStr = hashCode.toString();
    int endIndex = (hashCodeStr.length > lenHashCode) ? lenHashCode : hashCodeStr.length;
    final String name = this.runtimeType.toString() + '@' + hashCodeStr.substring(0, endIndex);
    return name;
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
    DateTime data = DateTime.now();
    var timeStr = printTime ? color('TIME: ${data.minute}:${data.second}:${data.millisecond}') : '';
    var messageStr = color(_stringifyMessage(event.message));
    var errorStr = event.error != null ? '  ERROR: ${event.error}' : '';
    return ['${_labelFor(event.level)}  $timeStr  $messageStr  $errorStr'];
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
