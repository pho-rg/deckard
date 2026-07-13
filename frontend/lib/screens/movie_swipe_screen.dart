import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/friend_models.dart';
import '../models/profile_models.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import 'match_result_screen.dart';

class MovieSwipeScreen extends StatefulWidget {
  final MatchSession session;
  final FriendService service;

  const MovieSwipeScreen({
    super.key,
    required this.session,
    required this.service,
  });

  @override
  State<MovieSwipeScreen> createState() => _MovieSwipeScreenState();
}

class _MovieSwipeScreenState extends State<MovieSwipeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final Map<int, bool> _choices = {}; // tmdbId → selected
  bool _submitting = false;
  Timer? _pollTimer;

  List<ProfileMovieCard> get _movies => widget.session.movies;

  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.05),
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 1, end: 0).animate(_animCtrl);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _choose(bool selected) async {
    if (_currentIndex >= _movies.length) return;
    final movie = _movies[_currentIndex];
    _choices[movie.tmdbId] = selected;

    // Animate out
    await _animCtrl.forward();
    _animCtrl.reset();

    if (_currentIndex + 1 >= _movies.length) {
      // All movies voted → submit
      await _submit();
    } else {
      setState(() => _currentIndex++);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    // On envoie les "non" (les films refusés) ; le back les retire de la liste.
    final rejected = _movies
        .where((m) => _choices[m.tmdbId] == false)
        .map((m) => m.tmdbId)
        .toList();
    try {
      var session = await widget.service.submitChoices(
        widget.session.id,
        rejected,
      );
      // Attendre que tous les participants aient soumis (statut "terminé").
      session = await _awaitFinished(session);
      if (mounted) _goToResult(session);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<MatchSession> _awaitFinished(MatchSession current) async {
    if (current.status == MatchStatus.finished) return current;
    final completer = Completer<MatchSession>();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final latest = await widget.service.getMatch(widget.session.id);
        if (latest.status == MatchStatus.finished) {
          t.cancel();
          if (!completer.isCompleted) completer.complete(latest);
        }
      } catch (_) {
        // tick suivant
      }
    });
    return completer.future;
  }

  void _goToResult(MatchSession session) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MatchResultScreen(session: session, service: widget.service),
      ),
    );
  }

  /// Quitte le vote en cours : prévient le back pour que les autres
  /// participants ne restent pas bloqués à attendre le choix de quelqu'un qui
  /// est parti (cf. FriendService.leaveMatch). Best-effort.
  Future<void> _leaveAndPop() async {
    try {
      await widget.service.leaveMatch(widget.session.id);
    } catch (_) {
      // best-effort
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = _movies.length;

    if (_submitting) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryPurple),
              const SizedBox(height: 20),
              Text(
                l10n.waitingForOthers,
                style: const TextStyle(color: AppTheme.textDim),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithPop: (didPop, result) {
        if (didPop) return;
        _leaveAndPop();
      },
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textDim),
                    onPressed: _leaveAndPop,
                  ),
                  Expanded(
                    child: Text(
                      l10n.makeYourSelection.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                  Text(
                    '${_currentIndex + 1}/$total',
                    style: const TextStyle(
                        color: AppTheme.textDim, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / total,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryPurple),
                  minHeight: 3,
                ),
              ),
            ),

            // ── Movie card stack ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 8),
                child: _buildCardStack(l10n),
              ),
            ),

            // ── Buttons ──────────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Icons.close,
                    color: Colors.redAccent,
                    label: l10n.declineMovie,
                    onTap: () => _choose(false),
                  ),
                  _ActionButton(
                    icon: Icons.favorite,
                    color: AppTheme.secondaryPurple,
                    label: l10n.selectMovie,
                    onTap: () => _choose(true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCardStack(AppLocalizations l10n) {
    final movies = _movies;
    final current = movies[_currentIndex];

    // Show up to 3 cards stacked (next ones peeking behind)
    return Stack(
      alignment: Alignment.center,
      children: [
        // Card 3 (furthest back)
        if (_currentIndex + 2 < movies.length)
          _buildCard(movies[_currentIndex + 2], depth: 2),
        // Card 2
        if (_currentIndex + 1 < movies.length)
          _buildCard(movies[_currentIndex + 1], depth: 1),
        // Current card (animated)
        FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _buildCard(current, depth: 0, withInfo: true, l10n: l10n),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
    ProfileMovieCard movie, {
    required int depth,
    bool withInfo = false,
    AppLocalizations? l10n,
  }) {
    final scale = 1.0 - depth * 0.04;
    final vertOffset = depth * 12.0;

    return Transform.translate(
      offset: Offset(0, vertOffset),
      child: Transform.scale(
        scale: scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Poster
                if (movie.posterUrl != null)
                  CachedNetworkImage(
                    imageUrl: movie.posterUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: Colors.grey[850]),
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.grey[850]),
                  )
                else
                  Container(
                    color: Colors.grey[850],
                    child: const Icon(Icons.movie,
                        color: Colors.white24, size: 60),
                  ),

                // Gradient + info overlay (only on front card)
                if (withInfo && l10n != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (movie.year.isNotEmpty)
                                Text(
                                  movie.year,
                                  style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13),
                                ),
                              if (movie.voteAverage != null) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.star,
                                    color: AppTheme.secondaryPurple,
                                    size: 13),
                                const SizedBox(width: 3),
                                Text(
                                  movie.voteAverage!.toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action button (Decline / Select)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              color: color.withOpacity(0.1),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
