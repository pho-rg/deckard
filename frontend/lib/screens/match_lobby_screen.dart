import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/friend_models.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import 'movie_swipe_screen.dart';

class MatchLobbyScreen extends StatefulWidget {
  final MatchSession session;
  final FriendService service;

  const MatchLobbyScreen(
      {super.key, required this.session, required this.service});

  @override
  State<MatchLobbyScreen> createState() => _MatchLobbyScreenState();
}

class _MatchLobbyScreenState extends State<MatchLobbyScreen> {
  late MatchSession _session;
  bool _starting = false;
  Timer? _simulationTimer;

  // Mock friends that will "join" one by one after a delay
  final _friendsToJoin = [
    Friend(id: 'f1', username: 'jane_riefel'),
    Friend(id: 'f2', username: 'yann_brumir'),
  ];
  int _joinedCount = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    // Only simulate friends joining if we are the host
    if (_session.isHost) {
      _simulateFriendsJoining();
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _simulateFriendsJoining() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (_joinedCount >= _friendsToJoin.length) {
        t.cancel();
        return;
      }
      final newFriend = _friendsToJoin[_joinedCount];
      _joinedCount++;
      if (mounted) {
        setState(() {
          _session = _session.copyWith(
            participants: [..._session.participants, newFriend],
          );
        });
      }
    });
  }

  Future<void> _go(AppLocalizations l10n) async {
    setState(() => _starting = true);
    final movies = await widget.service.startMatch(_session.id);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MovieSwipeScreen(
            session: _session,
            movies: movies,
            service: widget.service,
          ),
        ),
      );
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _session.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.codeCopied),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.match.toUpperCase()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // ── Header ────────────────────────────────────────────────────
              Text(
                'DECKARD AI',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: AppTheme.primaryPurple.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.groupMatch,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('✨', style: TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.gatherGroupTastes,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textDim),
              ),

              const SizedBox(height: 32),

              // ── Code display ──────────────────────────────────────────────
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Faux QR grid
                      const _FauxQrGrid(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                l10n.orUseCode.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textDim,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _copyCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppTheme.primaryPurple, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _session.code,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryPurple,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.copy_outlined,
                          size: 16, color: AppTheme.textDim),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Friends who joined ────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.friendsWhoJoined.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: AppTheme.textDim,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _session.participants.length,
                  itemBuilder: (_, i) {
                    final p = _session.participants[i];
                    final isMe = p.id == 'mock-user-id';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: isMe
                              ? Border.all(
                                  color: AppTheme.primaryPurple
                                      .withOpacity(0.4))
                              : null,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  AppTheme.primaryPurple.withOpacity(0.7),
                              child: Text(
                                p.initials,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              p.username,
                              style: const TextStyle(
                                  color: AppTheme.textMain,
                                  fontWeight: FontWeight.w500),
                            ),
                            if (i == 0 && _session.isHost) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'HOST',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: AppTheme.secondaryPurple,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── GO button ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _starting ? null : () => _go(l10n),
                    icon: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      l10n.goButton,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Faux QR grid (decorative, 21×21 QR-like structure)
// ─────────────────────────────────────────────────────────────────────────────

class _FauxQrGrid extends StatelessWidget {
  const _FauxQrGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(170, 170),
      painter: _QrPainter(),
    );
  }
}

class _QrPainter extends CustomPainter {
  // Pre-built 21×21 QR-like grid (computed once)
  static final _grid = _buildGrid();

  static List<List<int>> _buildGrid() {
    const n = 21;
    // -1 = unset, 0 = white, 1 = black
    final g = List.generate(n, (_) => List.filled(n, -1));

    // ── Finder pattern template ──────────────────────────────────────────────
    const fp = [
      [1, 1, 1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0, 0, 1],
      [1, 0, 1, 1, 1, 0, 1],
      [1, 0, 1, 1, 1, 0, 1],
      [1, 0, 1, 1, 1, 0, 1],
      [1, 0, 0, 0, 0, 0, 1],
      [1, 1, 1, 1, 1, 1, 1],
    ];

    void placeFinder(int r0, int c0) {
      for (var r = 0; r < 7; r++) {
        for (var c = 0; c < 7; c++) {
          g[r0 + r][c0 + c] = fp[r][c];
        }
      }
    }

    placeFinder(0, 0);   // top-left
    placeFinder(0, 14);  // top-right
    placeFinder(14, 0);  // bottom-left

    // ── Separators (1-module white border around each finder) ────────────────
    void s0(int r, int c) {
      if (r >= 0 && r < n && c >= 0 && c < n && g[r][c] == -1) g[r][c] = 0;
    }

    for (var i = 0; i <= 7; i++) s0(7, i);       // top-left: row 7
    for (var i = 0; i <= 7; i++) s0(i, 7);       // top-left: col 7
    for (var i = 13; i <= 20; i++) s0(7, i);     // top-right: row 7
    for (var i = 0; i <= 7; i++) s0(i, 13);      // top-right: col 13
    for (var i = 0; i <= 7; i++) s0(13, i);      // bottom-left: row 13
    for (var i = 13; i <= 20; i++) s0(i, 7);     // bottom-left: col 7

    // ── Timing patterns (row 6 and col 6 between separators) ─────────────────
    for (var i = 8; i <= 12; i++) {
      g[6][i] = i.isEven ? 1 : 0;
      g[i][6] = i.isEven ? 1 : 0;
    }

    // ── Dark module (always black) ────────────────────────────────────────────
    g[13][8] = 1;

    // ── Format info strips (simplified decorative values) ─────────────────────
    for (var c = 0; c <= 8; c++) {
      if (g[8][c] == -1) g[8][c] = (c & 1) ^ ((c >> 1) & 1);
    }
    for (var r = 0; r <= 7; r++) {
      if (g[r][8] == -1) g[r][8] = (r & 1) ^ 1;
    }
    for (var c = 13; c <= 20; c++) {
      if (g[8][c] == -1) g[8][c] = (c + 1) & 1;
    }
    for (var r = 13; r <= 20; r++) {
      if (g[r][8] == -1) g[r][8] = r & 1;
    }

    // ── Data area: deterministic pseudo-random fill ───────────────────────────
    var seed = 0xA3F1B8C2;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (g[r][c] == -1) {
          seed ^= seed << 13;
          seed ^= seed >> 17;
          seed ^= seed << 5;
          seed &= 0xFFFFFFFF;
          g[r][c] = seed & 1;
        }
      }
    }

    return g;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final black = Paint()..color = Colors.black;
    final cell = size.width / 21;

    for (var r = 0; r < 21; r++) {
      for (var c = 0; c < 21; c++) {
        if (_grid[r][c] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  c * cell + 0.5, r * cell + 0.5, cell - 1, cell - 1),
              Radius.circular(cell * 0.18),
            ),
            black,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
