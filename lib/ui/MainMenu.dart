import 'package:flutter/material.dart';
import '../main.dart';
import 'Chat.dart';
import '../store/store.dart';
import '../store/drift.dart';

// =============================================================================
// MainMenuScreen — adaptive layout: sidebar+content on wide, list on narrow
// =============================================================================

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  late final AnimationController _entryCtrl;

  List<ChatWithLastMessage> _chats = [];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final list = await MimaStore.instance.loadSessionsWithLastMessage();
    if (mounted) {
      setState(() {
        _chats = list;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  List<ChatWithLastMessage> get _filteredChats {
    if (_searchQuery.isEmpty) return _chats;
    final q = _searchQuery.toLowerCase();
    return _chats
        .where((c) =>
            c.session.title.toLowerCase().contains(q) ||
            (c.lastMessage?.content.toLowerCase().contains(q) ?? false))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isWide = MimaBreakpoints.isWide(context);

    return Scaffold(
      body: FadeTransition(
        opacity:
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
        child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
      ),
      // FAB only on narrow (mobile)
      floatingActionButton: isWide
          ? null
          : FloatingActionButton(
              onPressed: _createNewChat,
              tooltip: 'New chat',
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  // ---- wide (desktop / landscape tablet) ------------------------------------

  Widget _buildWideLayout() {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        // sidebar
        SizedBox(
          width: 340,
          child: _buildSidebar(context),
        ),
        VerticalDivider(
          width: 1,
          color: colors.outlineVariant.withOpacity(0.12),
        ),
        // main content
        Expanded(
          child: _selectedIndex != null
              ? ChatView(
                  chatId: _filteredChats[_selectedIndex!].session.id.toString(),
                  onChatUpdated: _loadChats,
                  onSessionDeleted: () {
                    setState(() {
                      _selectedIndex = null;
                    });
                  },
                )
              : _buildDesktopEmptyState(),
        ),
      ],
    );
  }

  // ---- narrow (mobile / portrait tablet) ------------------------------------

  Widget _buildNarrowLayout() {
    return SafeArea(
      child: Column(
        children: [
          _buildMobileHeader(),
          _buildSearchBar(),
          Expanded(child: _buildChatList(isSidebar: false)),
        ],
      ),
    );
  }

  // ---- sidebar (used in wide layout) ----------------------------------------

  Widget _buildSidebar(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      color: colors.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            // sidebar header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  // app icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.tertiary],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        size: 18, color: colors.onPrimary),
                  ),
                  const SizedBox(width: 12),
                  Text('Mima',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontSize: 20)),
                  const Spacer(),
                  // new chat
                  IconButton(
                    onPressed: _createNewChat,
                    icon: const Icon(Icons.edit_square, size: 20),
                    tooltip: 'New chat',
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surfaceContainer,
                    ),
                  ),
                ],
              ),
            ),

            // search
            _buildSearchBar(),

            // chat list
            Expanded(child: _buildChatList(isSidebar: true)),

            // bottom toolbar
            Divider(height: 1, color: colors.outlineVariant.withOpacity(0.1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _SidebarButton(
                    icon: Icons.download_rounded,
                    label: 'Models',
                    onTap: () =>
                        Navigator.pushNamed(context, '/models/manage'),
                  ),
                  const Spacer(),
                  _SidebarButton(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: () =>
                        Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- mobile header --------------------------------------------------------

  Widget _buildMobileHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.tertiary],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: 16, color: colors.onPrimary),
          ),
          const SizedBox(width: 12),
          Text('Mima',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/models/manage'),
            icon: const Icon(Icons.smart_toy_outlined, size: 22),
            tooltip: 'Models',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  // ---- search bar -----------------------------------------------------------

  Widget _buildSearchBar() {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded,
              size: 20, color: colors.onSurface.withOpacity(0.4)),
          hintText: 'Search chats…',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  // ---- chat list ------------------------------------------------------------

  Widget _buildChatList({required bool isSidebar}) {
    final filtered = _filteredChats;

    if (filtered.isEmpty) {
      return _buildListEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final chat = filtered[i];
        final selected = isSidebar && _selectedIndex == i;

        return _ChatListTile(
          chat: chat,
          selected: selected,
          onTap: () {
            if (isSidebar) {
              setState(() => _selectedIndex = i);
            } else {
              Navigator.pushNamed(context, '/chat', arguments: chat.session.id.toString())
                  .then((_) => _loadChats());
            }
          },
          onDelete: () => _deleteChat(i),
        );
      },
    );
  }

  Widget _buildListEmptyState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 48, color: colors.onSurface.withOpacity(0.15)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No results' : 'No chats yet',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onSurface.withOpacity(0.4),
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tap + to start a new conversation',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withOpacity(0.25),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopEmptyState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withOpacity(0.06),
            ),
            child: Icon(Icons.chat_rounded,
                size: 56, color: colors.primary.withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            'Select a conversation',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a chat from the sidebar or start a new one',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  // ---- actions --------------------------------------------------------------

  Future<void> _createNewChat() async {
    final defaultModelName = await MimaStore.instance.getSetting('default_model') ?? 'llama3.2';
    final newSession = await MimaStore.instance.createSession(
      'New conversation',
      defaultModelName,
    );
    await _loadChats();
    if (mounted) {
      if (MimaBreakpoints.isWide(context)) {
        final idx = _chats.indexWhere((c) => c.session.id == newSession.id);
        setState(() {
          _selectedIndex = idx >= 0 ? idx : 0;
        });
      } else {
        Navigator.pushNamed(context, '/chat', arguments: newSession.id.toString())
            .then((_) => _loadChats());
      }
    }
  }

  Future<void> _deleteChat(int index) async {
    final chat = _filteredChats[index];
    await MimaStore.instance.deleteSession(chat.session.id);
    await _loadChats();
    if (mounted) {
      setState(() {
        if (_selectedIndex == index) _selectedIndex = null;
        if (_selectedIndex != null && _selectedIndex! > index) {
          _selectedIndex = _selectedIndex! - 1;
        }
      });
    }
  }
}

// =============================================================================
// Chat list tile
// =============================================================================

class _ChatListTile extends StatelessWidget {
  final ChatWithLastMessage chat;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatListTile({
    required this.chat,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Dismissible(
        key: ValueKey(chat.session.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: colors.error.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.delete_rounded, color: colors.error),
        ),
        onDismissed: (_) => onDelete(),
        child: Material(
          color: selected
              ? colors.primary.withOpacity(0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // chat icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.primary.withOpacity(0.15)
                          : colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.chat_bubble_rounded,
                      size: 18,
                      color: selected
                          ? colors.primary
                          : colors.onSurface.withOpacity(0.35),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                        chat.session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (chat.lastMessage != null && chat.lastMessage!.content.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          chat.lastMessage!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // meta
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (chat.session.isPinned)
                          Icon(Icons.push_pin_rounded,
                              size: 11, color: colors.primary),
                        if (chat.session.isPinned)
                          const SizedBox(width: 4),
                        Text(
                          _timeAgo(chat.lastMessage?.timestamp ?? chat.session.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: colors.onSurface.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.session.modelName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: colors.primary.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// =============================================================================
// Sidebar bottom button
// =============================================================================

class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SidebarButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: TextButton.styleFrom(
        foregroundColor: colors.onSurface.withOpacity(0.6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }
}

// End of MainMenuScreen
