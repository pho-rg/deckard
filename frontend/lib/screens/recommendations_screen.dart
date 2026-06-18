import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../theme/app_theme.dart';
import 'movie_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Period filter
// ─────────────────────────────────────────────────────────────────────────────

class _Period {
  final String label;
  final int? from;
  final int? to;

  const _Period(this.label, {this.from, this.to});

  bool matches(String? releaseDate) {
    if (releaseDate == null || releaseDate.isEmpty) return false;
    final year = int.tryParse(releaseDate.split('-').first);
    if (year == null) return false;
    if (from != null && year < from!) return false;
    if (to != null && year >= to!) return false;
    return true;
  }
}

const _kPeriods = [
  _Period('< 1980', to: 1980),
  _Period('1980 – 1989', from: 1980, to: 1990),
  _Period('1990 – 1999', from: 1990, to: 2000),
  _Period('2000 – 2009', from: 2000, to: 2010),
  _Period('2010 – 2019', from: 2010, to: 2020),
  _Period('2020+', from: 2020),
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<Movie> _allMovies = [];
  List<Movie> _filtered = [];
  bool _loading = true;

  _Period? _selectedPeriod;
  final Set<String> _selectedGenres = {};
  List<String> _availableGenres = [];

  // Per-movie interaction state
  final Set<int> _skipped = {};
  final Set<int> _watchlisted = {};

  List<Movie> get _visible =>
      _filtered.where((m) => !_skipped.contains(m.id)).toList();

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    // V1 : recommandations = films au hasard de la BDD (côté backend).
    final movies = await MovieService.getRecommendations();
    final genres = <String>{};
    for (final m in movies) {
      for (final g in (m.genres ?? [])) {
        genres.add(g.name);
      }
    }
    setState(() {
      _allMovies = movies;
      _availableGenres = genres.toList()..sort();
      _loading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final filtered = _allMovies.where((m) {
      if (_selectedPeriod != null &&
          !_selectedPeriod!.matches(m.releaseDate)) return false;
      if (_selectedGenres.isNotEmpty) {
        final movieGenres = (m.genres ?? []).map((g) => g.name).toSet();
        if (!_selectedGenres.any((g) => movieGenres.contains(g))) return false;
      }
      return true;
    }).toList();

    setState(() {
      _filtered = filtered;
      _skipped.clear();
      _watchlisted.clear();
    });
  }

  // "Dislike" : retire le film des recommandations courantes.
  void _skip(int id) => setState(() => _skipped.add(id));

  Future<void> _toggleWatchlist(int id) async {
    final wasWatchlisted = _watchlisted.contains(id);
    // Optimiste : on met à jour l'UI tout de suite.
    setState(() {
      if (wasWatchlisted) {
        _watchlisted.remove(id);
      } else {
        _watchlisted.add(id);
      }
    });
    try {
      if (wasWatchlisted) {
        await MovieService.removeFromWatchlist(id);
      } else {
        await MovieService.addToWatchlist(id);
      }
    } catch (_) {
      // Échec : on annule le changement optimiste.
      if (!mounted) return;
      setState(() {
        if (wasWatchlisted) {
          _watchlisted.add(id);
        } else {
          _watchlisted.remove(id);
        }
      });
    }
  }

  void _showFilterSheet(AppLocalizations l10n) {
    _Period? tempPeriod = _selectedPeriod;
    final Set<String> tempGenres = Set.from(_selectedGenres);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, sc) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Text(l10n.filterTitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setSheet(() {
                        tempPeriod = null;
                        tempGenres.clear();
                      }),
                      child: Text(l10n.clearFilters,
                          style: const TextStyle(
                              color: AppTheme.textDim, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(l10n.periodFilter,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _kPeriods.map((p) {
                        final sel = tempPeriod == p;
                        return ChoiceChip(
                          label: Text(p.label),
                          selected: sel,
                          onSelected: (_) =>
                              setSheet(() => tempPeriod = sel ? null : p),
                          selectedColor: AppTheme.primaryPurple,
                          backgroundColor: Colors.white10,
                          labelStyle: TextStyle(
                              color: sel ? Colors.white : AppTheme.textDim,
                              fontSize: 13),
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(l10n.genreFilter,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableGenres.map((g) {
                        final sel = tempGenres.contains(g);
                        return FilterChip(
                          label: Text(g),
                          selected: sel,
                          onSelected: (_) => setSheet(() =>
                              sel ? tempGenres.remove(g) : tempGenres.add(g)),
                          selectedColor: AppTheme.primaryPurple,
                          backgroundColor: Colors.white10,
                          labelStyle: TextStyle(
                              color: sel ? Colors.white : AppTheme.textDim,
                              fontSize: 13),
                          side: BorderSide.none,
                          checkmarkColor: Colors.white,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _selectedPeriod = tempPeriod;
                        _selectedGenres
                          ..clear()
                          ..addAll(tempGenres);
                      });
                      Navigator.pop(ctx);
                      _applyFilters();
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(l10n.applyFilters,
                        style: const TextStyle(fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _activeFilterChips() {
    final chips = <Widget>[];
    if (_selectedPeriod != null) {
      chips.add(_ActiveChip(
        label: _selectedPeriod!.label,
        onRemove: () {
          setState(() => _selectedPeriod = null);
          _applyFilters();
        },
      ));
    }
    for (final g in _selectedGenres) {
      chips.add(_ActiveChip(
        label: g.toUpperCase(),
        onRemove: () {
          setState(() => _selectedGenres.remove(g));
          _applyFilters();
        },
      ));
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _visible;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.watchlist),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryPurple))
          : CustomScrollView(
              slivers: [
                // ── Header ───────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.auto_awesome,
                              size: 12, color: AppTheme.primaryPurple),
                          const SizedBox(width: 6),
                          Text(
                            l10n.deckardAi.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.primaryPurple,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text(
                            l10n.movieRecommendations.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.auto_awesome,
                              size: 16, color: AppTheme.secondaryPurple),
                        ]),
                        const SizedBox(height: 2),
                        Text(l10n.basedOnYourTastes,
                            style: const TextStyle(
                                color: AppTheme.textDim, fontSize: 13)),
                      ],
                    ),
                  ),
                ),

                // ── Filter row ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 2),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showFilterSheet(l10n),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppTheme.primaryPurple, width: 1.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(children: [
                                Text(
                                  l10n.addFilters.toUpperCase(),
                                  style: const TextStyle(
                                      color: AppTheme.primaryPurple,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.tune,
                                    size: 14, color: AppTheme.primaryPurple),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ..._activeFilterChips(),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Count ─────────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        l10n.moviesCount(visible.length),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── List ──────────────────────────────────────────────────────
                visible.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.movie_filter_outlined,
                                    size: 48, color: AppTheme.textDim),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.noRecommendationsFound,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppTheme.textDim, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final movie = visible[i];
                              final wl = _watchlisted.contains(movie.id);
                              return _RecommendationCard(
                                key: ValueKey(movie.id),
                                movie: movie,
                                watchlisted: wl,
                                onSkip: () => _skip(movie.id),
                                onToggleWatchlist: () =>
                                    _toggleWatchlist(movie.id),
                              );
                            },
                            childCount: visible.length,
                          ),
                        ),
                      ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendation card
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final Movie movie;
  final bool watchlisted;
  final VoidCallback onSkip;
  final VoidCallback onToggleWatchlist;

  static const double _posterW = 100;
  static const double _posterH = 150;

  const _RecommendationCard({
    super.key,
    required this.movie,
    required this.watchlisted,
    required this.onSkip,
    required this.onToggleWatchlist,
  });

  @override
  Widget build(BuildContext context) {
    final director = movie.crew
        ?.firstWhere(
          (c) => c.job == 'Director',
          orElse: () => Crew(id: 0, name: '', job: '', department: ''),
        )
        .name;
    final year = movie.releaseDate?.split('-').first ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Poster ──────────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: _posterW,
                  height: _posterH,
                  child: CachedNetworkImage(
                    imageUrl: movie.posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: Colors.grey[900]),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.movie,
                          color: Colors.white10, size: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ── Info ────────────────────────────────────────────────────
              Expanded(
                child: SizedBox(
                  height: _posterH,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Genre chips
                      if ((movie.genres ?? []).isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: (movie.genres ?? []).take(2).map((g) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple
                                    .withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                g.name.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.secondaryPurple,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        movie.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Year + director
                      if (year.isNotEmpty || (director != null && director.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            [if (year.isNotEmpty) year,
                             if (director != null && director.isNotEmpty) director]
                                .join(' · '),
                            style: const TextStyle(
                                color: AppTheme.textDim, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      const SizedBox(height: 6),

                      // Synopsis
                      if ((movie.overview ?? '').isNotEmpty)
                        Expanded(
                          child: Text(
                            movie.overview!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              height: 1.45,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      const Spacer(),

                      // ── Action buttons ───────────────────────────────────
                      Row(
                        children: [
                          // Skip (hidden when watchlisted)
                          if (!watchlisted)
                            _IconBtn(
                              icon: Icons.thumb_down_off_alt,
                              filled: false,
                              onTap: onSkip,
                            ),
                          const Spacer(),

                          // Watchlist toggle
                          _IconBtn(
                            icon: watchlisted
                                ? Icons.bookmark_remove_outlined
                                : Icons.bookmark_add_outlined,
                            filled: watchlisted,
                            onTap: onToggleWatchlist,
                            label: watchlisted
                                ? AppLocalizations.of(context)!.removeWatchlist
                                : AppLocalizations.of(context)!.watchlistAdd,
                          ),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small icon button (circle) or pill (icon + label)
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  final String? label;

  const _IconBtn({
    required this.icon,
    required this.filled,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = filled ? Colors.white : Colors.white54;
    final bg = filled ? AppTheme.primaryPurple : Colors.transparent;
    final border = filled ? null : Border.all(color: Colors.white24, width: 1.5);

    if (label == null) {
      // Circle
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: bg, border: border),
          child: Icon(icon, size: 17, color: color),
        ),
      );
    }

    // Pill
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(17),
          border: border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label!,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active filter chip
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryPurple.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                color: AppTheme.secondaryPurple,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              )),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 13, color: AppTheme.secondaryPurple),
          ),
        ],
      ),
    );
  }
}
