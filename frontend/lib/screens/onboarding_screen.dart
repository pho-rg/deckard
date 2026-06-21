import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/profile_models.dart';
import '../services/auth_service.dart';
import '../services/movie_service.dart';
import '../theme/app_theme.dart';
import 'main_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late Future<List<ProfileMovieCard>> _moviesFuture;
  final Set<int> _selected = {}; // tmdbIds sélectionnés
  bool _submitting = false;

  static const _maxPick = 10;
  static const _minPick = 1;

  @override
  void initState() {
    super.initState();
    _moviesFuture = _loadMovies();
  }

  Future<List<ProfileMovieCard>> _loadMovies() {
    // Fixed IMDb id list (bundled JSON) resolved to cards by the backend.
    return MovieService.getOnboardingMovies();
  }

  void _toggle(int tmdbId) {
    setState(() {
      if (_selected.contains(tmdbId)) {
        _selected.remove(tmdbId);
      } else if (_selected.length < _maxPick) {
        _selected.add(tmdbId);
      }
    });
  }

  Future<void> _continue() async {
    if (_selected.length < _minPick) return;
    setState(() => _submitting = true);
    try {
      await AuthService.saveOnboardingMovies(_selected.toList());
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canContinue = _selected.length >= _minPick;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.onboardingTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.onboardingSubtitle,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textDim),
                  ),
                ],
              ),
            ),

            // ── Counter ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  _CounterBadge(
                      count: _selected.length, max: _maxPick, l10n: l10n),
                ],
              ),
            ),

            // ── Grid ────────────────────────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<ProfileMovieCard>>(
                future: _moviesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final movies = snapshot.data ?? [];
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2 / 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: movies.length,
                    itemBuilder: (_, i) {
                      final m = movies[i];
                      final selected = _selected.contains(m.tmdbId);
                      final maxReached = _selected.length >= _maxPick;
                      return _MovieTile(
                        movie: m,
                        selected: selected,
                        dimmed: maxReached && !selected,
                        onTap: () => _toggle(m.tmdbId),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Bouton Continuer ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (canContinue && !_submitting) ? _continue : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    disabledBackgroundColor:
                        AppTheme.primaryPurple.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          l10n.onboardingContinue,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Counter badge
// ─────────────────────────────────────────────────────────────────────────────

class _CounterBadge extends StatelessWidget {
  final int count;
  final int max;
  final AppLocalizations l10n;

  const _CounterBadge(
      {required this.count, required this.max, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: count > 0
            ? AppTheme.primaryPurple.withOpacity(0.2)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: count > 0
              ? AppTheme.primaryPurple.withOpacity(0.5)
              : Colors.white12,
        ),
      ),
      child: Text(
        l10n.onboardingCounter(count, max),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: count > 0 ? AppTheme.secondaryPurple : AppTheme.textDim,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Movie tile
// ─────────────────────────────────────────────────────────────────────────────

class _MovieTile extends StatelessWidget {
  final ProfileMovieCard movie;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _MovieTile({
    required this.movie,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster
            if (movie.posterUrl != null)
              CachedNetworkImage(
                imageUrl: movie.posterUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey[850]),
                errorWidget: (_, __, ___) =>
                    Container(color: Colors.grey[850]),
              )
            else
              Container(
                color: Colors.grey[850],
                child: const Icon(Icons.movie,
                    color: Colors.white24, size: 32),
              ),

            // Dim overlay when max reached and not selected
            if (dimmed)
              Container(color: Colors.black.withOpacity(0.6)),

            // Selected overlay
            if (selected) ...[
              Container(color: AppTheme.primaryPurple.withOpacity(0.5)),
              const Center(
                child: Icon(Icons.check_circle,
                    color: Colors.white, size: 32),
              ),
            ],

            // Border when selected
            if (selected)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.secondaryPurple, width: 2.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
