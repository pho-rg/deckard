import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/friend_models.dart';
import '../models/profile_models.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import 'match_lobby_screen.dart';

class MatchResultScreen extends StatelessWidget {
  final MatchSession session;
  final List<ProfileMovieCard> unanimousMovies;
  final FriendService service;

  const MatchResultScreen({
    super.key,
    required this.session,
    required this.unanimousMovies,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasMatch = unanimousMovies.isNotEmpty;

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
                  // Spacer to balance the close button
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: hasMatch
                  ? _MatchFoundView(movies: unanimousMovies, l10n: l10n)
                  : _NoMatchView(
                      l10n: l10n,
                      session: session,
                      service: service,
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
              itemBuilder: (_, i) {
                final m = movies[i];
                return ClipRRect(
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
                                Colors.black.withOpacity(0.85),
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
  final MatchSession session;
  final FriendService service;

  const _NoMatchView({
    required this.l10n,
    required this.session,
    required this.service,
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
            if (session.isHost) ...[
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: () => _restartMatch(context),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.restartMatch),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _restartMatch(BuildContext context) async {
    final newSession = await service.createMatch();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MatchLobbyScreen(session: newSession, service: service),
        ),
      );
    }
  }
}
