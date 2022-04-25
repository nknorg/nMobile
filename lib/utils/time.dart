import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nmobile/common/global.dart';
import 'package:nmobile/common/settings.dart';

class Time {
  static String formatDate(DateTime? time) {
    if (time == null) return "";
    return DateFormat("EEE, MM dd yyyy", Settings.locale == 'zh' ? 'zh' : 'en').format(time);
  }

  static String formatTime(DateTime? time) {
    if (time == null) return "";
    var now = DateTime.now();
    var localizations = Localizations.localeOf(Global.appContext).toString();
    if (now.difference(time).inDays == 0 && time.day == now.day) {
      return DateFormat.Hm(localizations).format(time);
    } else if (now.difference(time).inDays <= 7 && time.weekday <= now.weekday) {
      return DateFormat.E(localizations).format(time);
    } else if (now.difference(time).inDays <= 31 && time.month == time.month) {
      return DateFormat.Md(localizations).format(time);
    } else {
      return DateFormat.yMd(localizations).format(time);
    }
  }

  static String formatChatTime(DateTime? timestamp) {
    var now = DateTime.now();
    var localizations = Localizations.localeOf(Global.appContext).toString();
    DateTime time = timestamp ?? now;
    String timeFormat;
    if (now.difference(time).inDays == 0 && time.day == now.day) {
      timeFormat = DateFormat.Hm(localizations).format(time);
    } else if (now.difference(time).inDays <= 7 && time.weekday <= now.weekday) {
      timeFormat = DateFormat.E(localizations).format(time) + ' ' + DateFormat.Hm(localizations).format(time);
    } else if (now.difference(time).inDays <= 31 && time.month == time.month) {
      timeFormat = DateFormat.Md(localizations).format(time) + ' ' + DateFormat.Hm(localizations).format(time);
    } else {
      timeFormat = DateFormat.yMd(localizations).format(time) + ' ' + DateFormat.Hm(localizations).format(time);
    }

    return timeFormat;
  }

  static String formatTimeFromNow(DateTime? time) {
    if (time == null) return "";
    var now = DateTime.now();
    var diff = time.difference(now);

    if (diff.inSeconds < 0) {
      return '0';
    } else if (diff.inSeconds < Duration.secondsPerMinute) {
      return diff.inSeconds.toString();
    } else if (diff.inMinutes < Duration.minutesPerHour) {
      return formatDurationToTime(diff).toString().substring(3);
    } else if (diff.inHours < Duration.hoursPerDay) {
      return formatDurationToTime(diff);
    } else if (diff.inDays < 7) {
      return diff.inDays.toString() + ' ' + Global.locale((s) => s.days);
    } else {
      return (diff.inDays / 7).toStringAsFixed(0) + ' ' + Global.locale((s) => s.weeks);
    }
  }

  static String formatDurationToTime(Duration d) {
    return d.toString().split('.').first.padLeft(8, "0");
  }

  static String formatDuration(Duration d) {
    if (d.inSeconds < 0) {
      return '0 ${Global.locale((s) => s.seconds)}';
    } else if (d.inSeconds < Duration.secondsPerMinute) {
      return d.inSeconds.toString() + ' ${Global.locale((s) => s.seconds)}';
    } else if (d.inMinutes < Duration.minutesPerHour) {
      return d.inMinutes.toString() + ' ${Global.locale((s) => s.minutes)}';
    } else if (d.inHours < Duration.hoursPerDay) {
      return d.inHours.toString() + ' ${Global.locale((s) => s.hours)}';
    } else if (d.inDays < 7) {
      return d.inDays.toString() + ' ' + Global.locale((s) => s.days);
    } else {
      return (d.inDays / 7).toStringAsFixed(0) + ' ' + Global.locale((s) => s.weeks);
    }
  }
}
