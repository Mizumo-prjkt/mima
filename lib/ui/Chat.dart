import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../store/store.dart';
import '../store/drift.dart';
import '../ollama/ollama_dart.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;

// =============================================================================
// Chat screen (standalone page – wraps ChatView in a Scaffold)
// =============================================================================

class ChatScreen extends StatelessWidget {
  final String? chatId;
  const ChatScreen({super.key, this.chatId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChatView(
        chatId: chatId,
        showBackButton: Navigator.canPop(context),
      ),
    );
  }
}

// =============================================================================
// ChatView — embeddable chat widget used by both ChatScreen and MainMenu
// =============================================================================

class ChatView extends StatefulWidget {
  final String? chatId;
  final bool showBackButton;

  const ChatView({super.key, this.chatId, this.showBackButton = false});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();
  String _selectedModel = 'llama3.2';
  bool _isGenerating = false;
  
  ChatSession? _session;
  List<ChatMessage> _messages = [];
  List<String> _modelsList = [];

  // typing indicator animation
  late final AnimationController _dotsCtrl;

  @override
  void initState() {
    super.initState();
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _loadSessionAndHistory();
    _loadAvailableModels();
  }

  @override
  void didUpdateWidget(ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chatId != oldWidget.chatId) {
      _loadSessionAndHistory();
    }
  }

  Future<void> _loadSessionAndHistory() async {
    final idStr = widget.chatId;
    if (idStr == null) {
      setState(() {
        _session = null;
        _messages = [];
      });
      return;
    }

    final id = int.tryParse(idStr);
    if (id == null) return;

    final sessions = await MimaStore.instance.loadSessions();
    final session = sessions.cast<ChatSession?>().firstWhere((s) => s?.id == id, orElse: () => null);

    if (session != null) {
      final history = await MimaStore.instance.loadMessages(id);
      if (mounted) {
        setState(() {
          _session = session;
          _messages = history;
          _selectedModel = session.modelName;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _loadAvailableModels() async {
    final models = await OllamaService.instance.listModels();
    if (mounted) {
      setState(() {
        _modelsList = models.map((m) => m.model ?? m.name ?? '').where((n) => n.isNotEmpty).toList();
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (_session == null) return;

    final sessionId = _session!.id;

    final userMsg = await MimaStore.instance.addMessage(sessionId, 'user', text);
    if (mounted) {
      setState(() {
        _messages.add(userMsg);
        _inputController.clear();
        _isGenerating = true;
      });
      _scrollToBottom();
    }

    final ollamaMessages = _messages.map((m) {
      if (m.role == 'user') {
        return ollama.ChatMessage.user(m.content);
      } else {
        return ollama.ChatMessage.assistant(m.content);
      }
    }).toList();

    int? assistantMsgIndex;
    String assistantContent = '';

    try {
      final stream = OllamaService.instance.streamChatCompletion(
        model: _selectedModel,
        messages: ollamaMessages,
        temperature: _session?.temperature,
        systemPrompt: _session?.systemPrompt,
      );

      await for (final chunk in stream) {
        if (!mounted) return;
        setState(() {
          assistantContent += chunk;
          if (assistantMsgIndex == null) {
            _messages.add(ChatMessage(
              id: -1,
              sessionId: sessionId,
              role: 'assistant',
              content: assistantContent,
              timestamp: DateTime.now(),
            ));
            assistantMsgIndex = _messages.length - 1;
          } else {
            _messages[assistantMsgIndex!] = ChatMessage(
              id: -1,
              sessionId: sessionId,
              role: 'assistant',
              content: assistantContent,
              timestamp: DateTime.now(),
            );
          }
        });
        _scrollToBottom();
      }

      if (assistantContent.isNotEmpty) {
        final savedMsg = await MimaStore.instance.addMessage(sessionId, 'assistant', assistantContent);
        if (mounted) {
          setState(() {
            _isGenerating = false;
            if (assistantMsgIndex != null) {
              _messages[assistantMsgIndex!] = savedMsg;
            }
          });
          _scrollToBottom();
        }
      } else {
        if (mounted) {
          setState(() {
            _isGenerating = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        _buildHeader(context),
        Divider(height: 1, color: colors.outlineVariant.withOpacity(0.12)),
        Expanded(child: _buildMessageList(context)),
        _buildInputBar(context),
      ],
    );
  }

  // ---- header / toolbar -----------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: EdgeInsets.only(
        top: widget.showBackButton ? MediaQuery.paddingOf(context).top : 0,
        left: 8,
        right: 8,
        bottom: 0,
      ),
      color: colors.surface,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            if (widget.showBackButton)
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            const SizedBox(width: 4),

            // model selector chip
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showModelSelector(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_rounded,
                        size: 16, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      _selectedModel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: colors.primary),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // overflow menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (v) {},
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'clear', child: Text('Clear chat')),
                PopupMenuItem(value: 'export', child: Text('Export chat')),
                PopupMenuItem(value: 'settings', child: Text('Settings')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showModelSelector(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Select Model',
                        style: Theme.of(ctx).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 12),
                  for (final model in (_modelsList.isEmpty ? _availableModels : _modelsList))
                    ListTile(
                      leading: Icon(
                        Icons.smart_toy_outlined,
                        color: model == _selectedModel
                            ? colors.primary
                            : colors.onSurface.withOpacity(0.5),
                      ),
                      title: Text(model),
                      trailing: model == _selectedModel
                          ? Icon(Icons.check_rounded, color: colors.primary)
                          : null,
                      selected: model == _selectedModel,
                      onTap: () async {
                        setState(() => _selectedModel = model);
                        if (_session != null) {
                          await MimaStore.instance.updateSessionModel(_session!.id, model);
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.download_rounded,
                        color: colors.onSurface.withOpacity(0.6)),
                    title: const Text('Browse & download models'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/models/browse');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- message list ---------------------------------------------------------

  Widget _buildMessageList(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_messages.isEmpty && !_isGenerating) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length + (_isGenerating ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _messages.length) {
          // typing indicator
          return _TypingIndicator(controller: _dotsCtrl, colors: colors);
        }
        return _MessageBubble(
          message: _messages[i],
          maxBubbleWidth: _bubbleMaxWidth(context),
        );
      },
    );
  }

  double _bubbleMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w > 1200) return 680;
    if (w > 800) return w * 0.6;
    return w * 0.82;
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withOpacity(0.08),
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 48, color: colors.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              'Start a conversation',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a message below to chat with $_selectedModel',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withOpacity(0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- input bar ------------------------------------------------------------

  Widget _buildInputBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: math.max(MediaQuery.paddingOf(context).bottom, 10),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withOpacity(0.12)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // attachment button
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/filepicker'),
            icon: const Icon(Icons.attach_file_rounded, size: 22),
            style: IconButton.styleFrom(
              foregroundColor: colors.onSurface.withOpacity(0.5),
            ),
          ),

          // text field
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocus,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                        color: colors.outlineVariant.withOpacity(0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide:
                        BorderSide(color: colors.primary.withOpacity(0.5)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  fillColor: colors.surfaceContainerLow,
                  filled: true,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton.filled(
              onPressed: _isGenerating ? null : _sendMessage,
              icon: _isGenerating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colors.onPrimary),
                    )
                  : const Icon(Icons.arrow_upward_rounded, size: 22),
              style: IconButton.styleFrom(
                backgroundColor:
                    _isGenerating ? colors.surfaceContainerHigh : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Message bubble
// =============================================================================

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final double maxBubbleWidth;
  const _MessageBubble({required this.message, required this.maxBubbleWidth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.primary.withOpacity(0.12),
              child: Icon(Icons.auto_awesome_rounded,
                  size: 16, color: colors.primary),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? colors.primary
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: colors.outlineVariant.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // content — simple for now, enhance with markdown later
                  _buildContent(theme, colors, isUser),

                  // timestamp
                  const SizedBox(height: 4),
                  Text(
                     _formatTime(message.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: isUser
                          ? colors.onPrimary.withOpacity(0.55)
                          : colors.onSurface.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colors, bool isUser) {
    // Detect simple code blocks (```...```)
    final content = message.content;
    final codeBlockPattern = RegExp(r'```(\w*)\n?([\s\S]*?)```');

    if (codeBlockPattern.hasMatch(content)) {
      final parts = <Widget>[];
      int lastEnd = 0;
      for (final match in codeBlockPattern.allMatches(content)) {
        // text before code
        if (match.start > lastEnd) {
          parts.add(Text(
            content.substring(lastEnd, match.start),
            style: TextStyle(
              color: isUser ? colors.onPrimary : colors.onSurface,
              height: 1.5,
            ),
          ));
        }
        // code block
        parts.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: colors.outlineVariant.withOpacity(0.15)),
          ),
          child: SelectableText(
            match.group(2)?.trim() ?? '',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: colors.onSurface.withOpacity(0.85),
              height: 1.5,
            ),
          ),
        ));
        lastEnd = match.end;
      }
      if (lastEnd < content.length) {
        parts.add(Text(
          content.substring(lastEnd),
          style: TextStyle(
            color: isUser ? colors.onPrimary : colors.onSurface,
            height: 1.5,
          ),
        ));
      }
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: parts);
    }

    return SelectableText(
      content,
      style: TextStyle(
        color: isUser ? colors.onPrimary : colors.onSurface,
        height: 1.5,
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// =============================================================================
// Attachment chip shown inside a message bubble
// =============================================================================

class _AttachmentChip extends StatelessWidget {
  final String fileName;
  final bool isUser;
  const _AttachmentChip({required this.fileName, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isUser
            ? colors.onPrimary.withOpacity(0.12)
            : colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_rounded,
              size: 16,
              color: isUser
                  ? colors.onPrimary.withOpacity(0.7)
                  : colors.onSurface.withOpacity(0.5)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              fileName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isUser
                    ? colors.onPrimary.withOpacity(0.8)
                    : colors.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Typing indicator (3 animated dots)
// =============================================================================

class _TypingIndicator extends StatelessWidget {
  final AnimationController controller;
  final ColorScheme colors;
  const _TypingIndicator({required this.controller, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.primary.withOpacity(0.12),
            child: Icon(Icons.auto_awesome_rounded,
                size: 16, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                  color: colors.outlineVariant.withOpacity(0.12)),
            ),
            child: AnimatedBuilder(
              animation: controller,
              builder: (ctx, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i * 0.25;
                    final t = (controller.value + delay) % 1.0;
                    final y = math.sin(t * math.pi) * 4;
                    return Transform.translate(
                      offset: Offset(0, -y),
                      child: Container(
                        margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.onSurface.withOpacity(0.35),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Mock data
// =============================================================================

const _availableModels = [
  'llama3.2',
  'llama3.2:1b',
  'mistral',
  'codellama',
  'phi3',
  'gemma2',
];

// End of ChatView file
