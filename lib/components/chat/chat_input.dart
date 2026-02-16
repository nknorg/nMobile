import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onAttachmentPressed;
  final VoidCallback? onEmojiPressed;
  final bool showEmojiPicker;
  final bool isUploading;
  final String? replyToMessage;
  final VoidCallback? onCancelReply;
  final bool showSendButton;
  final FocusNode? focusNode;

  const ChatInput({
    Key? key,
    this.controller,
    this.onSubmitted,
    this.onAttachmentPressed,
    this.onEmojiPressed,
    this.showEmojiPicker = false,
    this.isUploading = false,
    this.replyToMessage,
    this.onCancelReply,
    this.showSendButton = true,
    this.focusNode,
  }) : super(key: key);

  @override
  _ChatInputState createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _hasText = false;
  late TextEditingController _effectiveController;
  final TextEditingController _defaultController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _effectiveController = widget.controller ?? _defaultController;
    _effectiveController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      _effectiveController.removeListener(_onTextChanged);
      _effectiveController.dispose();
      _effectiveController = widget.controller ?? _defaultController;
      _effectiveController.addListener(_onTextChanged);
    }
  }
  
  void _onTextChanged() {
    setState(() {
      _hasText = _effectiveController.text.trim().isNotEmpty;
    });
  }
  
  void _handleSubmitted(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isNotEmpty) {
      widget.onSubmitted?.call(trimmedText);
      _effectiveController.clear();
      setState(() {
        _hasText = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview
        if (widget.replyToMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Replying to',
                            style: theme.textTheme.bodySmall,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: widget.onCancelReply,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.replyToMessage!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Input area
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment button
              IconButton(
                icon: const Icon(Icons.attach_file_rounded),
                onPressed: widget.onAttachmentPressed,
                color: theme.iconTheme.color?.withOpacity(0.7),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              // Emoji button
              IconButton(
                icon: Icon(
                  widget.showEmojiPicker
                      ? Icons.keyboard_rounded
                      : Icons.emoji_emotions_outlined,
                ),
                onPressed: widget.onEmojiPressed,
                color: theme.iconTheme.color?.withOpacity(0.7),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              // Text field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    maxHeight: 120,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.transparent : Colors.grey[300]!,
                    ),
                  ),
                  child: TextField(
                    controller: _effectiveController,
                    focusNode: widget.focusNode,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      color: Colors.grey, // dark grey text
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      hintText: 'Message',
                      hintStyle: TextStyle(
                        color: theme.hintColor,
                      ),
                    ),
                    onSubmitted: _handleSubmitted,
                  ),
                ),
              ),
              // Send button or voice message button
              if (widget.showSendButton)
                IconButton(
                  icon: _hasText
                      ? const Icon(Icons.send_rounded)
                      : const Icon(Icons.mic_rounded),
                  color: _hasText
                      ? theme.primaryColor
                      : theme.iconTheme.color?.withOpacity(0.7),
                  onPressed: _hasText
                      ? () => _handleSubmitted(_effectiveController.text)
                      : null,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
