import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/friend_models.dart';
import '../models/profile_models.dart';
import '../services/friend_service.dart';
import '../services/movie_service.dart';
import '../theme/app_theme.dart';
import 'match_lobby_screen.dart';
import 'movie_detail_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _service = FriendService();
  late Future<_FriendsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_FriendsData> _load() async {
    final results = await Future.wait([
      _service.getMyFriends(),
      _service.getIncomingRequests(),
      _service.getPopularWithFriends(),
    ]);
    return _FriendsData(
      friends: results[0] as List<Friend>,
      requests: results[1] as List<FriendRequest>,
      popular: results[2] as List<ProfileMovieCard>,
    );
  }

  void _refresh() => setState(() => _dataFuture = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: l10n.addFriend,
            onPressed: () => _showAddFriendSheet(context, l10n),
          ),
        ],
      ),
      body: FutureBuilder<_FriendsData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('${snapshot.error}',
                  style: const TextStyle(color: AppTheme.textDim)),
            );
          }
          final data = snapshot.data!;
          return _buildBody(context, l10n, data);
        },
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, AppLocalizations l10n, _FriendsData data) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Match banner ────────────────────────────────────────────────
          _MatchBanner(l10n: l10n, service: _service),

          // ── Incoming requests ───────────────────────────────────────────
          if (data.requests.isNotEmpty)
            _RequestsSection(
              requests: data.requests,
              l10n: l10n,
              onAccept: (id) async {
                await _service.acceptRequest(id);
                _refresh();
              },
              onReject: (id) async {
                await _service.rejectRequest(id);
                _refresh();
              },
            ),

          // ── Popular with friends ────────────────────────────────────────
          _SectionHeader(l10n.popularWithFriends),
          _PopularGrid(movies: data.popular),

          // ── Friends list ────────────────────────────────────────────────
          _SectionHeader(l10n.myFriends),
          data.friends.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Text(l10n.noFriendsYet,
                      style: const TextStyle(
                          color: AppTheme.textDim, fontSize: 13)),
                )
              : _FriendsList(friends: data.friends),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Add friend bottom sheet ─────────────────────────────────────────────────

  void _showAddFriendSheet(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddFriendSheet(l10n: l10n, service: _service),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data bundle
// ─────────────────────────────────────────────────────────────────────────────

class _FriendsData {
  final List<Friend> friends;
  final List<FriendRequest> requests;
  final List<ProfileMovieCard> popular;

  _FriendsData(
      {required this.friends, required this.requests, required this.popular});
}

// ─────────────────────────────────────────────────────────────────────────────
// Match banner
// ─────────────────────────────────────────────────────────────────────────────

class _MatchBanner extends StatelessWidget {
  final AppLocalizations l10n;
  final FriendService service;

  const _MatchBanner({required this.l10n, required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D2640), Color(0xFF1B1A23)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✨',
            style: TextStyle(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.watchWithFriends,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.gatherGroupTastes,
            style: const TextStyle(fontSize: 13, color: AppTheme.textDim),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _startMatch(context),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(l10n.startAMatch),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _joinMatch(context),
                icon: const Icon(Icons.qr_code_scanner, size: 18,
                    color: AppTheme.secondaryPurple),
                label: Text(l10n.joinAMatch,
                    style:
                        const TextStyle(color: AppTheme.secondaryPurple)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryPurple),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startMatch(BuildContext context) async {
    final session = await service.createMatch();
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MatchLobbyScreen(session: session, service: service),
        ),
      );
    }
  }

  void _joinMatch(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _JoinMatchDialog(
        l10n: AppLocalizations.of(context)!,
        onJoin: (code) async {
          final session = await service.joinMatch(code);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MatchLobbyScreen(session: session, service: service),
              ),
            );
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Join match dialog
// ─────────────────────────────────────────────────────────────────────────────

class _JoinMatchDialog extends StatefulWidget {
  final AppLocalizations l10n;
  final Future<void> Function(String code) onJoin;

  const _JoinMatchDialog({required this.l10n, required this.onJoin});

  @override
  State<_JoinMatchDialog> createState() => _JoinMatchDialogState();
}

class _JoinMatchDialogState extends State<_JoinMatchDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(l10n.joinAMatch,
          style: const TextStyle(color: AppTheme.textMain)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
                color: AppTheme.textMain,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 4),
            decoration: InputDecoration(
              hintText: 'XXXXX',
              hintStyle:
                  const TextStyle(color: Colors.white24, letterSpacing: 4),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white12)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white12)),
            ),
            maxLength: 5,
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () async {
              final code = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                    builder: (_) => const QrScannerScreen(),
                    fullscreenDialog: true),
              );
              if (code != null && mounted) {
                setState(() => _ctrl.text = code.toUpperCase());
              }
            },
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: Text(l10n.scanQrCode),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.secondaryPurple,
              side: const BorderSide(color: AppTheme.primaryPurple),
              minimumSize: const Size(double.infinity, 42),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.decline,
              style: const TextStyle(color: AppTheme.textDim)),
        ),
        FilledButton(
          onPressed: _loading
              ? null
              : () async {
                  if (_ctrl.text.trim().length < 5) return;
                  setState(() => _loading = true);
                  await widget.onJoin(_ctrl.text.trim());
                  if (mounted) Navigator.pop(context);
                },
          style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(l10n.join),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Incoming requests
// ─────────────────────────────────────────────────────────────────────────────

class _RequestsSection extends StatelessWidget {
  final List<FriendRequest> requests;
  final AppLocalizations l10n;
  final void Function(String id) onAccept;
  final void Function(String id) onReject;

  const _RequestsSection({
    required this.requests,
    required this.l10n,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined,
                  size: 16, color: AppTheme.secondaryPurple),
              const SizedBox(width: 6),
              Text(
                l10n.friendRequests,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppTheme.secondaryPurple,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${requests.length}',
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        ...requests.map((req) => _RequestTile(
              request: req,
              l10n: l10n,
              onAccept: () => onAccept(req.requester.id),
              onReject: () => onReject(req.requester.id),
            )),
        const Divider(color: Colors.white10, height: 1),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  final FriendRequest request;
  final AppLocalizations l10n;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestTile({
    required this.request,
    required this.l10n,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  userId: request.requester.id,
                  initialUsername: request.requester.username,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Avatar(initials: request.requester.initials, radius: 20),
                const SizedBox(width: 12),
                Text(
                  request.requester.username,
                  style: const TextStyle(
                      color: AppTheme.textMain, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onReject,
            child: Text(l10n.decline,
                style: const TextStyle(
                    color: AppTheme.textDim, fontSize: 13)),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l10n.accept,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Popular with friends grid
// ─────────────────────────────────────────────────────────────────────────────

class _PopularGrid extends StatelessWidget {
  final List<ProfileMovieCard> movies;

  const _PopularGrid({required this.movies});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW - 48) / 2; // 2 columns, 16+8+8+16 padding
    final cardH = cardW / (2 / 3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: movies.length.clamp(0, 4),
        itemBuilder: (ctx, i) {
          final m = movies[i];
          return GestureDetector(
            onTap: () async {
              final full = await MovieService.getById(m.tmdbId);
              if (full != null && ctx.mounted) {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => MovieDetailScreen(movie: full)),
                );
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: m.posterUrl != null
                  ? CachedNetworkImage(
                      imageUrl: m.posterUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: Colors.grey[850]),
                      errorWidget: (_, __, ___) =>
                          Container(color: Colors.grey[850]),
                    )
                  : Container(color: Colors.grey[850]),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Friends list
// ─────────────────────────────────────────────────────────────────────────────

class _FriendsList extends StatelessWidget {
  final List<Friend> friends;

  const _FriendsList({required this.friends});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: friends.length,
      itemBuilder: (_, i) => _FriendTile(friend: friends[i]),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Friend friend;

  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _Avatar(initials: friend.initials, radius: 22),
      title: Text(
        friend.username,
        style: const TextStyle(
            color: AppTheme.textMain, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right,
          color: AppTheme.textDim, size: 18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(
            userId: friend.id,
            initialUsername: friend.username,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add friend sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddFriendSheet extends StatefulWidget {
  final AppLocalizations l10n;
  final FriendService service;

  const _AddFriendSheet({required this.l10n, required this.service});

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().length < 3) return;
    setState(() => _loading = true);
    await widget.service.sendFriendRequest(_ctrl.text.trim());
    setState(() {
      _loading = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.addFriend,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain)),
          const SizedBox(height: 20),
          if (_sent)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primaryPurple.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppTheme.secondaryPurple),
                  const SizedBox(width: 12),
                  Text(l10n.friendRequestSent,
                      style: const TextStyle(
                          color: AppTheme.secondaryPurple,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textMain),
              decoration: InputDecoration(
                hintText: l10n.searchUsername,
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.person_search_outlined,
                    color: AppTheme.textDim, size: 20),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Colors.white12)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryPurple)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(l10n.sendRequest,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final double radius;

  const _Avatar({required this.initials, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryPurple.withOpacity(0.7),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
