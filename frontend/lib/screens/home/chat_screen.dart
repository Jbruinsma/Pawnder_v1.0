import 'package:flutter/material.dart';
import 'package:pawnder_app/models/message_thread.dart';
import 'package:pawnder_app/screens/home/message_thread_screen.dart';
import 'package:pawnder_app/services/message_service.dart';
import 'package:pawnder_app/services/message_socket_service.dart';
import 'package:pawnder_app/widgets/build_header.dart';
import 'package:pawnder_app/widgets/user_avatar.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageService = MessageService();
  final _messageSocketService = MessageSocketService();

  List<MessageThread> _threads = const [];
  String? _selectedThreadId;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _messageSubscription;

  MessageThread? get _selectedThread {
    if (_threads.isEmpty) {
      return null;
    }

    return _threads.firstWhere(
      (thread) => thread.id == _selectedThreadId,
      orElse: () => _threads.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadThreads();
    _subscribeToLiveMessages();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToLiveMessages() async {
    await _messageSocketService.connect();
    _messageSubscription = _messageSocketService.incomingEvents.listen((_) {
      if (mounted) {
        _loadThreads();
      }
    });
  }

  Future<void> _loadThreads() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final threads = await _messageService.getThreads();
      if (!mounted) {
        return;
      }

      setState(() {
        _threads = threads;
        _selectedThreadId = threads.isEmpty ? null : threads.first.id;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _messageService.messageForError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openThread(MessageThread thread) async {
    setState(() {
      _selectedThreadId = thread.id;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MessageThreadScreen(thread: thread)),
    );
    await _loadThreads();
  }

  Future<void> _confirmDeleteThread(MessageThread thread) async {
    final participantId = thread.participantId;
    if (participantId == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          'Remove your conversation with ${thread.participantName} from this inbox?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await _messageService.deleteThread(participantId);
      await _loadThreads();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _messageService.messageForError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedThread = _selectedThread;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeHeader(
            title: 'Messages',
            fallbackIcon: Icons.mark_unread_chat_alt_outlined,
          ),
          const SizedBox(height: 18),
          if (_isLoading) const LinearProgressIndicator(minHeight: 3),
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_threads.isNotEmpty)
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _threads.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final thread = _threads[index];
                  final isSelected = thread.id == selectedThread?.id;
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _openThread(thread),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                        ),
                      ),
                      child: Text(
                        thread.participantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_threads.isNotEmpty) const SizedBox(height: 16),
          Expanded(
            child: _threads.isEmpty && !_isLoading
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _threads.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final thread = _threads[index];
                      final isSelected = thread.id == selectedThread?.id;
                      return _ThreadListTile(
                        thread: thread,
                        isSelected: isSelected,
                        onTap: () => _openThread(thread),
                        onLongPress: () => _confirmDeleteThread(thread),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ThreadListTile extends StatelessWidget {
  final MessageThread thread;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ThreadListTile({
    required this.thread,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: isSelected
                  ? theme.cardColor
                  : theme.scaffoldBackgroundColor,
              child: UserAvatar(
                imagePath: thread.participantAvatarPath,
                size: 44,
                backgroundColor: isSelected
                    ? theme.cardColor
                    : theme.scaffoldBackgroundColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.participantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        thread.lastUpdatedLabel,
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.onPrimary.withValues(
                                  alpha: 0.72,
                                )
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    thread.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    thread.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.78)
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (thread.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.16)
                      : theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${thread.unreadCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.onPrimary.withValues(alpha: 0.72)
                    : theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}