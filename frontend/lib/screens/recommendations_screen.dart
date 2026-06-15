import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../theme/app_theme.dart';
import 'movie_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Period filter definition
// ─────────────────────────────────────────────────────────────────────────────

class _Period {
  final String label;
  final int? from; // inclusive
  final int? to;   // exclusive

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

class _RecommendationsScreenState extends State<RecommendationsScreen>
    with SingleTickerProviderStateMixin {
  // Data
  List<Movie> _allMovies = [];
  List<Movie> _filtered = [];
  int _index = 0;
  bool _loading = true;

  // Filters
  _Period? _selectedPeriod;
  final Set<String> _selectedGenres = {};
  List<String> _availableGenres = [];

  // Animation
  late final AnimationController _anim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280), value: 1.0);
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    final movies = await MovieService.getMockMovies();
    // Collect distinct genre names
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
          !_selectedPeriod!.matches(m.releaseDate)) {
        return false;
      }
      if (_selectedGenres.isNotEmpty) {
        final movieGenres = (m.genres ?? []).map((g) => g.name).toSet();
        if (!_selectedGenres.any((g) => movieGenres.contains(g))) return false;
      }
      return true;
    }).toList();

    setState(() {
      _filtered = filtered;
      _index = 0;
    });
    if (filtered.isNotEmpty) _playEnter();
  }

  void _playEnter() {
    _anim.forward(from: 0);
  }

  void _skip() {
    if (_index < _filtered.length - 1) {
      setState(() => _index++);
      _playEnter();
    } else {
      setState(() => _index = 0); // loop
      _playEnter();
    }
  }

  void _addToWatchlist() {
    final movie = _filtered[_index];
    // TODO: POST /users/me/watchlist { tmdb_id: movie.id }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${movie.title}" ${AppLocalizations.of(context)!.addedToWatchlist}'),
        backgroundColor: AppTheme.primaryPurple,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    _skip();
  }

  void _showFilterSheet(AppLocalizations l10n) {
    // Temp state for the sheet
    _Period? tempPeriod = _selectedPeriod;
    final Set<String> tempGenres = Set.from(_selectedGenres);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, sc) => Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
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
                      onPressed: () {
                        setSheet(() {
                          tempPeriod = null;
                          tempGenres.clear();
                        });
                      },
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
                    // Period
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
                    // Genres
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
                          onSelected: (_) => setSheet(() {
                            if (sel) {
                              tempGenres.remove(g);
                            } else {
                              tempGenres.add(g);
                            }
                          }),
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
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
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
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
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
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
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.basedOnYourTastes,
                        style: const TextStyle(
                            color: AppTheme.textDim, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Filter row ─────────────────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // ADD FILTERS button
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
                          child: Row(
                            children: [
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Active filter chips
                      ..._activeFilterChips(),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Card area ──────────────────────────────────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
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
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              // Movie card
                              Expanded(
                                child: FadeTransition(
                                  opacity: _fadeAnim,
                                  child: SlideTransition(
                                    position: _slideAnim,
                                    child: _MovieCard(
                                      movie: _filtered[_index],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              // Action buttons
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Skip
                                  _CircleButton(
                                    onTap: _skip,
                                    icon: Icons.close,
                                    filled: false,
                                    size: 58,
                                    iconSize: 26,
                                  ),
                                  // Counter
                                  Text(
                                    '${_index + 1} / ${_filtered.length}',
                                    style: const TextStyle(
                                        color: AppTheme.textDim, fontSize: 13),
                                  ),
                                  // Add to watchlist
                                  _CircleButton(
                                    onTap: _addToWatchlist,
                                    icon: Icons.bookmark_add_outlined,
                                    filled: true,
                                    size: 58,
                                    iconSize: 26,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Movie card
// ─────────────────────────────────────────────────────────────────────────────

class _MovieCard extends StatelessWidget {
  final Movie movie;

  const _MovieCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    final director = movie.crew
        ?.firstWhere(
          (c) => c.job == 'Director',
          orElse: () => Crew(id: 0, name: '', job: '', department: ''),
        )
        .name;
    final cast = movie.cast?.take(3).map((c) => c.name).join(' • ') ?? '';
    final year = movie.releaseDate?.split('-').first ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: AppTheme.surface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Poster ────────────────────────────────────────────────────
              Expanded(
                flex: 5,
                child: CachedNetworkImage(
                  imageUrl: movie.posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: Colors.grey[900]),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.movie,
                        color: Colors.white10, size: 48),
                  ),
                ),
              ),
              // ── Info ──────────────────────────────────────────────────────
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Genres
                      if ((movie.genres ?? []).isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: (movie.genres ?? []).take(2).map((g) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                g.name.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.secondaryPurple,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // Title + year
                      Text(
                        movie.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (year.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(year,
                            style: const TextStyle(
                                color: AppTheme.textDim, fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      // Overview
                      Expanded(
                        child: Text(
                          movie.overview ?? '',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.55,
                          ),
                          overflow: TextOverflow.fade,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Director
                      if (director != null && director.isNotEmpty) ...[
                        Text(
                          director,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                      ],
                      // Cast
                      if (cast.isNotEmpty)
                        Text(
                          cast,
                          style: const TextStyle(
                              color: AppTheme.textDim, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
// Circle action button
// ─────────────────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final bool filled;
  final double size;
  final double iconSize;

  const _CircleButton({
    required this.onTap,
    required this.icon,
    required this.filled,
    this.size = 56,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppTheme.primaryPurple : Colors.transparent,
          border: filled
              ? null
              : Border.all(color: Colors.white30, width: 1.5),
        ),
        child: Icon(icon,
            color: filled ? Colors.white : Colors.white60,
            size: iconSize),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active filter chip (removable)
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
        border:
            Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.secondaryPurple,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
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
