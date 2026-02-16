import 'package:flutter/material.dart';
import 'package:nmobile/theme/app_theme.dart';

class ChatListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? time;
  final String? avatarUrl;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ChatListItem({
    Key? key,
    required this.title,
    this.subtitle,
    this.time,
    this.avatarUrl,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Material(
      color: isSelected 
          ? isDark 
              ? Colors.grey[800] 
              : Colors.grey[200]
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: isDark 
              ? AppTheme.darkChatListItemDecoration 
              : AppTheme.chatListItemDecoration,
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.primaryColor.withOpacity(0.2),
                    backgroundImage: avatarUrl != null 
                        ? NetworkImage(avatarUrl!) as ImageProvider
                        : null,
                    child: avatarUrl == null 
                        ? Text(
                            title.isNotEmpty ? title[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  if (isPinned)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.push_pin,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Chat info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (time != null)
                          Text(
                            time!,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isMuted)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.notifications_off,
                              size: 14,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            subtitle ?? '',
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Unread badge
              if (unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppTheme.unreadBadgeColor,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
