import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
                      // Real QR code encoding the join code
                      _SessionQr(code: _session.code),
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
// Real QR code — encodes the session join code via qr_flutter
// ─────────────────────────────────────────────────────────────────────────────

class _SessionQr extends StatelessWidget {
  final String code;

  const _SessionQr({required this.code});

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: code,
      version: QrVersions.auto,
      size: 170,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
  }
}
