import 'package:flutter/material.dart';
import 'package:nmobile/components/chat/chat_input.dart';
import 'package:nmobile/components/chat/message_bubble.dart';
import 'package:nmobile/components/layout/chat_topic_search.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/common/settings.dart';

class TelegramChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isGroup;

  const TelegramChatScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
    this.isGroup = false,
  }) : super(key: key);

  @override
  _TelegramChatScreenState createState() => _TelegramChatScreenState();
}

class _TelegramChatScreenState extends State<TelegramChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  String? _replyToMessage;

  @override
  void initState() {
    super.initState();
    // Load messages for this chat
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    // TODO: Load messages from your data source
    // This is just sample data
    setState(() {
      _messages.addAll([
        {
          'id': '1',
          'text': 'Hello! How are you?',
          'isMe': false,
          'time': '10:00 AM',
          'isRead': true,
        },
        {
          'id': '2',
          'text': 'I\'m doing great, thanks for asking!',
          'isMe': true,
          'time': '10:02 AM',
          'isRead': true,
        },
        {
          'id': '3',
          'text': 'Would you like to meet up later?',
          'isMe': false,
          'time': '10:03 AM',
          'isRead': true,
        },
      ]);
    });
    
    // Scroll to bottom after messages are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage(String text) {
    if (text.trim().isEmpty) return;

    final newMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': text,
      'isMe': true,
      'time': _formatTime(DateTime.now()),
      'isRead': false,
      'replyTo': _replyToMessage,
    };

    setState(() {
      _messages.add(newMessage);
      _replyToMessage = null;
    });

    // Scroll to bottom
    _scrollToBottom();

    // TODO: Send message to your backend
    // await _sendMessageToBackend(text, _replyToMessage);
  }

  void _handleReplyToMessage(String messageId) {
    final message = _messages.firstWhere((m) => m['id'] == messageId);
    setState(() {
      _replyToMessage = message['text'] as String;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatName),
            if (widget.isGroup)
              const Text(
                'online',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              BottomDialog.of(context).showWithTitle(
                title: 'Find Public Groups',
                height: Settings.screenHeight() * 0.8,
                child: ChatTopicSearchLayout(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Show more options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(
                  key: ValueKey(message['id']),
                  message: message['text'] as String,
                  isMe: message['isMe'] as bool,
                  time: message['time'] as String,
                  isRead: message['isRead'] as bool,
                  onLongPress: () => _handleReplyToMessage(message['id'] as String),
                );
              },
            ),
          ),
          // Input area
          ChatInput(
            controller: _messageController,
            onSubmitted: _handleSendMessage,
            replyToMessage: _replyToMessage,
            onCancelReply: _cancelReply,
            onAttachmentPressed: () {
              // TODO: Handle attachment
            },
            onEmojiPressed: () {
              // TODO: Toggle emoji picker
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
