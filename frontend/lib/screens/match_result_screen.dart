import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/friend_models.dart';
import '../models/profile_models.dart';
import '../services/friend_service.dart';
import '../services/movie_service.dart';
import '../theme/app_theme.dart';
import 'movie_detail_screen.dart';
import 'movie_swipe_screen.dart';

class MatchResultScreen extends StatefulWidget {
  final MatchSession session;
  final FriendService service;

  const MatchResultScreen({
    super.key,
    required this.session,
    required this.service,
  });

  @override
  State<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends State<MatchResultScreen> {
  Timer? _pollTimer;
  bool _relaunching = false;

  bool get _hasMatch => widget.session.result.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Pas de match + on n'est pas l'hôte → on attend que l'hôte relance.
    if (!_hasMatch && !widget.session.isHost) {
      _pollTimer = Timer.periodic(
          const Duration(seconds: 2), (_) => _pollForRelaunch());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollForRelaunch() async {
    try {
      final s = await widget.service.getMatch(widget.session.id);
      if (!mounted) return;
      if (s.status == MatchStatus.voting) {
        _pollTimer?.cancel();
        _goToSwipe(s);
      }
    } catch (_) {
      // tick suivant
    }
  }

  Future<void> _relaunch() async {
    setState(() => _relaunching = true);
    try {
      final s = await widget.service.relaunchMatch(widget.session.id);
      if (mounted) _goToSwipe(s);
    } catch (e) {
      if (mounted) {
        setState(() => _relaunching = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _goToSwipe(MatchSession session) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MovieSwipeScreen(session: session, service: widget.service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textDim),
                    onPressed: () =>
                        Navigator.popUntil(context, (r) => r.isFirst),
                  ),
                  Expanded(
                    child: Text(
                      l10n.matchResults.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: _hasMatch
                  ? _MatchFoundView(
                      movies: widget.session.result, l10n: l10n)
                  : _NoMatchView(
                      l10n: l10n,
                      isHost: widget.session.isHost,
                      relaunching: _relaunching,
                      onRelaunch: _relaunch,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Match found
// ─────────────────────────────────────────────────────────────────────────────

class _MatchFoundView extends StatelessWidget {
  final List<ProfileMovieCard> movies;
  final AppLocalizations l10n;

  const _MatchFoundView({required this.movies, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),

        // Header
        const Text('🎉', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(
          l10n.unanimousMovies.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            color: AppTheme.primaryPurple,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l10n.unanimousMoviesSubtitle,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 13, color: AppTheme.textDim),
          ),
        ),

        const SizedBox(height: 28),

        // Grid of matching movies
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: movies.length,
              itemBuilder: (ctx, i) {
                final m = movies[i];
                return GestureDetector(
                  onTap: () async {
                    try {
                      final full = await MovieService.getMovieDetail(m.tmdbId);
                      if (ctx.mounted) {
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(
                              builder: (_) => MovieDetailScreen(movie: full)),
                        );
                      }
                    } catch (_) {/* film introuvable, on ignore */}
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (m.posterUrl != null)
                          CachedNetworkImage(
                            imageUrl: m.posterUrl!,
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
                                color: Colors.white24, size: 48),
                          ),
                        // Title gradient overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.85),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Text(
                              m.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // Heart badge
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite,
                                color: AppTheme.secondaryPurple, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No match
// ─────────────────────────────────────────────────────────────────────────────

class _NoMatchView extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isHost;
  final bool relaunching;
  final VoidCallback onRelaunch;

  const _NoMatchView({
    required this.l10n,
    required this.isHost,
    required this.relaunching,
    required this.onRelaunch,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😔', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            Text(
              l10n.noMatchFound,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.noMatchFoundSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textDim, height: 1.5),
            ),
            const SizedBox(height: 36),
            if (isHost)
              FilledButton.icon(
                onPressed: relaunching ? null : onRelaunch,
                icon: relaunching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.restartMatch),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryPurple),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.waitingForHost,
                      style: const TextStyle(
                          color: AppTheme.textDim, fontSize: 13)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
