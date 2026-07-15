import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:nmobile/common/locator.dart';
import 'package:nmobile/common/settings.dart';
import 'package:nmobile/components/layout/expansion_layout.dart';

class EmojiPickerBottomMenu extends StatelessWidget {
  final String? target;
  final bool show;
  final Function(List<Map<String, dynamic>> result)? onPicked;
  final TextEditingController controller;
  final _scrollController = ScrollController();

  EmojiPickerBottomMenu({
    this.target,
    this.show = false,
    this.onPicked,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    double btnSize = Settings.screenWidth() / 6;
    double iconSize = btnSize / 2;

    return ExpansionLayout(
      isExpanded: show,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: application.theme.backgroundColor2),
          ),
        ),
        child: EmojiPicker(
          textEditingController: controller,
          scrollController: _scrollController,
          config: Config(
            height: 256,
            checkPlatformCompatibility: true,
            viewOrderConfig: const ViewOrderConfig(),
            emojiViewConfig: EmojiViewConfig(
              // Issue: https://github.com/flutter/flutter/issues/28894
              emojiSizeMax: 28 *
                  (foundation.defaultTargetPlatform ==
                      TargetPlatform.iOS
                      ? 1.2
                      : 1.0),
            ),
            skinToneConfig: const SkinToneConfig(),
            categoryViewConfig: const CategoryViewConfig(),
            bottomActionBarConfig: const BottomActionBarConfig(),
            searchViewConfig: const SearchViewConfig(),
          ),
        ),
      ),
    );
  }
}
