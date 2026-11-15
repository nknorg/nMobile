import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmobile/helpers/file_crypto.dart';

/// Circle avatar for a file that may be AES-GCM ciphertext.
/// Legacy plaintext is shown directly. Ciphertext is restored only while visible.
class PlainCircleAvatar extends StatefulWidget {
  final String path;
  final double radius;
  final Widget fallback;

  const PlainCircleAvatar({
    Key? key,
    required this.path,
    required this.radius,
    required this.fallback,
  }) : super(key: key);

  @override
  State<PlainCircleAvatar> createState() => _PlainCircleAvatarState();
}

class _PlainCircleAvatarState extends State<PlainCircleAvatar> {
  String? _held;
  String? _plain;
  int _epoch = 0;
  int _gen = 0;
  bool _error = false;
  bool _rebindScheduled = false;

  @override
  void initState() {
    super.initState();
    _bind(notify: false);
  }

  @override
  void didUpdateWidget(PlainCircleAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _error = false;
      _bind(notify: true);
    }
  }

  @override
  void dispose() {
    _gen++;
    final held = _held;
    _held = null;
    if (held != null) FileCrypto.release(held);
    super.dispose();
  }

  void _bind({required bool notify}) {
    final path = widget.path;
    final gen = ++_gen;
    _epoch = FileCrypto.epoch;
    if (!FileCrypto.isEncryptedSync(path)) {
      final prev = _held;
      _held = null;
      _plain = path;
      if (prev != null) FileCrypto.release(prev);
      if (notify) setState(() {});
      return;
    }
    FileCrypto.openForRead(path).then((plain) {
      if (!mounted || gen != _gen) {
        FileCrypto.release(path);
        return;
      }
      if (FileCrypto.epoch != _epoch) {
        FileCrypto.release(path);
        _bind(notify: true);
        return;
      }
      final prev = _held;
      if (plain == null || plain.isEmpty) {
        _held = null;
        _plain = null;
        _error = true;
      } else {
        _held = plain == path ? null : path;
        _plain = plain;
        _error = false;
      }
      if (prev != null && prev != _held) FileCrypto.release(prev);
      setState(() {});
    });
  }

  void _scheduleRebindIfWiped() {
    if (FileCrypto.epoch == _epoch || _rebindScheduled) return;
    _rebindScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebindScheduled = false;
      if (!mounted) return;
      if (FileCrypto.epoch == _epoch) return;
      _error = false;
      _bind(notify: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleRebindIfWiped();
    final plain = _plain;
    if (_error || plain == null || plain.isEmpty || !File(plain).existsSync()) {
      return widget.fallback;
    }
    return CircleAvatar(
      radius: widget.radius,
      backgroundImage: FileImage(File(plain)),
      onBackgroundImageError: (Object exception, StackTrace? stackTrace) {
        if (_error || !mounted) return;
        if (FileCrypto.epoch != _epoch) {
          _scheduleRebindIfWiped();
          return;
        }
        setState(() {
          _error = true;
        });
      },
    );
  }
}
