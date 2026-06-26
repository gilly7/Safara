import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/source_info.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safara Chat'),
        actions: [
          IconButton(
            tooltip: 'New session',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => context.read<ChatProvider>().newSession(),
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chat, _) {
          return Column(
            children: [
              if (chat.isStreaming)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: DashChat(
                  currentUser: chat.currentUser,
                  onSend: (message) => chat.sendMessage(message.text),
                  messageListOptions: const MessageListOptions(
                    showDateSeparator: false,
                  ),
                  messageOptions: MessageOptions(
                    showCurrentUserAvatar: true,
                    showOtherUsersAvatar: true,
                    avatarBuilder: (user, onPress, onLong) {
                      final isSafara = user.id == 'safara';
                      return CircleAvatar(
                        backgroundColor: isSafara
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.secondaryContainer,
                        child: Icon(
                          isSafara ? Icons.explore : Icons.person,
                          size: 20,
                          color: isSafara
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                        ),
                      );
                    },
                    messageTextBuilder: (message, previous, next) {
                      final isSafara = message.user.id == 'safara';
                      final isStreaming =
                          message.customProperties?['streaming'] == true;
                      if (!isSafara) {
                        return Text(message.text);
                      }
                      return MarkdownBody(
                        data: message.text.isEmpty && isStreaming
                            ? '_Thinking..._'
                            : message.text,
                      );
                    },
                    bottom: (message, previous, next) {
                      if (message.user.id != chat.safaraUser.id) {
                        return const SizedBox.shrink();
                      }
                      final messageId =
                          message.customProperties?['id'] as String?;
                      if (messageId == null) return const SizedBox.shrink();
                      final sources = chat.sourcesForMessage(messageId);
                      if (sources.isEmpty) return const SizedBox.shrink();
                      return _SourcesFooter(sources: sources);
                    },
                  ),
                  messages: chat.messages,
                  inputOptions: InputOptions(
                    sendButtonBuilder: (onSend) => IconButton(
                      onPressed: chat.isStreaming ? null : onSend,
                      icon: Icon(
                        Icons.send_rounded,
                        color: chat.isStreaming
                            ? Theme.of(context).disabledColor
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    inputDecoration: InputDecoration(
                      hintText: 'Ask about Kenya travel...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SourcesFooter extends StatelessWidget {
  const _SourcesFooter({required this.sources});

  final List<SourceInfo> sources;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.source_outlined, size: 14, color: scheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Sources',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...sources.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.fileName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      s.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
