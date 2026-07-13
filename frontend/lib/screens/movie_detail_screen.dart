import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/movie.dart';
import '../widgets/movie_card.dart';
import '../theme/app_theme.dart';
import '../services/movie_service.dart';
import 'all_reviews_screen.dart';
import 'person_screen.dart';
import 'profile_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  
  double _userRating = 0.0;
  bool _isSynopsisExpanded = false;
  final TextEditingController _reviewController = TextEditingController();
  List<double> _ratingDistribution = List.filled(10, 0.0);
  List<Movie> _similarMovies = [];
  List<MovieReview> _reviews = [];
  int _ratingsCount = 0;
  bool _showAppBarTitle = false;

  bool _isWatched = false;
  bool _isLiked = false;
  bool _isInWatchlist = false;

  bool _isTogglingWatched = false;
  bool _isTogglingFavorite = false;
  bool _isTogglingWatchlist = false;
  bool _isSubmittingRating = false;

  late Movie _movie;
  bool _isDataLoaded = false;
  double? _tmdbRating;
  bool _isTmdbRatingLoading = true;
  bool _isReviewsLoading = true;
  bool _isSimilarLoading = true;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    _tabController = TabController(length: 4, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // Fire all requests in parallel but don't block on each other.
    // Each updates the UI independently as it resolves, so the screen
    // renders progressively instead of waiting for the slowest call.
    _fetchDetail().whenComplete(() {
      if (mounted) setState(() => _isDataLoaded = true);
    });
    _fetchUserState();
    _fetchReviews();
    _loadSimilarMovies();
    _fetchTmdbRating();
  }

  Future<void> _fetchTmdbRating() async {
    try {
      final rating = await MovieService.getTmdbRating(_movie.id);
      if (mounted) {
        setState(() {
          _tmdbRating = rating;
          _isTmdbRatingLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isTmdbRatingLoading = false);
    }
  }

  Future<void> _fetchReviews() async {
    try {
      final r = await MovieService.getMovieReviews(_movie.id);
      final maxCount = r.distribution.isEmpty ? 0 : r.distribution.reduce(max);
      if (mounted) {
        setState(() {
          _reviews = r.reviews;
          _ratingsCount = r.count;
          _ratingDistribution = r.distribution
              .map((c) => maxCount > 0 ? c / maxCount : 0.0)
              .toList();
          _isReviewsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isReviewsLoading = false);
    }
  }

  Future<void> _fetchDetail() async {
    try {
      final full = await MovieService.getMovieDetail(_movie.id);
      if (mounted) {
        setState(() {
          _movie = full;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchUserState() async {
    try {
      final s = await MovieService.getUserState(_movie.id);
      if (mounted) {
        setState(() {
          _isLiked = s.isFavorite;
          _isInWatchlist = s.inWatchlist;
          _isWatched = s.isWatched;
          _userRating = s.userRating ?? 0.0;
          if (s.userReview != null) _reviewController.text = s.userReview!;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSimilarMovies() async {
    try {
      final movies = await MovieService.getSimilar(_movie.id);
      if (mounted) {
        setState(() {
          _similarMovies = movies;
          _isSimilarLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSimilarLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      bool shouldShow = _scrollController.offset > 140;
      if (shouldShow != _showAppBarTitle) {
        setState(() {
          _showAppBarTitle = shouldShow;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _launchTrailer() async {
    final url = _movie.officialTrailerUrl;
    if (url != null) {
      final uri = Uri.parse(url);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!_isDataLoaded) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryPurple),
        ),
      );
    }

    final directorCrew = _movie.crew?.firstWhere(
      (c) => c.job == 'Director',
      orElse: () => Crew(id: 0, name: 'Unknown', job: '', department: ''),
    );
    final director = directorCrew?.name ?? 'Unknown';

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(context, l10n),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(l10n, director, directorCrew),
                _buildSectionDivider(),
                _buildRatingsSection(l10n),
                _buildUserActionSection(l10n),
                const SizedBox(height: 20),
                _buildSectionDivider(),
                _buildTabsSection(l10n),
                _buildSectionDivider(),
                const SizedBox(height: 10),
                _buildReviewsSection(l10n),
                _buildSectionDivider(),
                const SizedBox(height: 10),
                _buildSimilarMoviesSection(l10n),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Divider(color: Colors.white10, height: 1),
    );
  }

  Widget _buildAppBar(BuildContext context, AppLocalizations l10n) {
    final hasBackdrop = _movie.backdropPath != null && _movie.backdropPath!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: hasBackdrop ? 200 : 0,
      pinned: true,
      backgroundColor: AppTheme.background,
      centerTitle: true,
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showAppBarTitle ? 1.0 : 0.0,
        child: Text(
          _movie.title.toUpperCase(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
      flexibleSpace: hasBackdrop ? FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: _movie.backdropUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    AppTheme.background,
                  ],
                ),
              ),
            ),
          ],
        ),
      ) : null,
    );
  }

  Widget _buildHeader(AppLocalizations l10n, String director, Crew? directorCrew) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MovieCard(movie: _movie, width: 100),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _movie.title.toUpperCase(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${_movie.releaseDate?.split('-').first ?? 'N/A'} • ',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    if (directorCrew != null && directorCrew.id != 0)
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PersonScreen(
                              personId: directorCrew.id,
                              name: directorCrew.name,
                              role: directorCrew.job,
                              profileUrl: directorCrew.profileUrl.isNotEmpty ? directorCrew.profileUrl : null,
                            ),
                          ),
                        ),
                        child: Text(
                          director,
                          style: const TextStyle(
                            color: AppTheme.secondaryPurple,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Text(
                        director,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _launchTrailer,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n.trailer),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                if (_movie.overview != null)
                  GestureDetector(
                    onTap: () => setState(() => _isSynopsisExpanded = true),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _movie.overview!,
                          style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
                          maxLines: _isSynopsisExpanded ? null : 4,
                          overflow: _isSynopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                        if (!_isSynopsisExpanded)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: Text('...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.ratings.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          if (_isReviewsLoading)
            const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondaryPurple)),
            )
          else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(10, (index) {
                      final isUserRating = _userRating == (index + 1) / 2.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isUserRating)
                                const Text('YOU', style: TextStyle(fontSize: 6, color: AppTheme.secondaryPurple, fontWeight: FontWeight.bold)),
                              Container(
                                height: max(2.0, 50 * _ratingDistribution[index]),
                                decoration: BoxDecoration(
                                  color: isUserRating ? AppTheme.secondaryPurple : Colors.white24,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Builder(builder: (_) {
                // Prefer Deckard community rating, fall back to TMDB.
                final avg5raw = _movie.voteAverage ?? _tmdbRating;
                final avg5 = avg5raw ?? 0;
                final halfStars = (avg5 * 2).round();
                final isLoading = avg5raw == null && _isTmdbRatingLoading;
                return Column(
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondaryPurple),
                      )
                    else
                      Text(
                        avg5raw != null ? avg5raw.toStringAsFixed(1) : '—',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    Row(
                      children: List.generate(5, (i) {
                        final full = (i + 1) * 2;
                        if (halfStars >= full) {
                          return const Icon(Icons.star, size: 10, color: AppTheme.secondaryPurple);
                        } else if (halfStars >= full - 1) {
                          return const Icon(Icons.star_half, size: 10, color: AppTheme.secondaryPurple);
                        } else {
                          return const Icon(Icons.star_border, size: 10, color: AppTheme.secondaryPurple);
                        }
                      }),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_ratingsCount',
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                  ],
                );
              })
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserActionSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: InkWell(
        onTap: () => _showRatingBottomSheet(context, l10n),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_userRating == 0)
                const Icon(Icons.add, color: AppTheme.secondaryPurple)
              else
                Row(
                  children: List.generate(5, (i) {
                    double starValue = i + 1.0;
                    if (_userRating >= starValue) {
                      return const Icon(Icons.star, color: AppTheme.secondaryPurple, size: 20);
                    } else if (_userRating >= starValue - 0.5) {
                      return const Icon(Icons.star_half, color: AppTheme.secondaryPurple, size: 20);
                    } else {
                      return const Icon(Icons.star_border, color: AppTheme.secondaryPurple, size: 20);
                    }
                  }),
                ),
              const SizedBox(width: 12),
              Text(
                _userRating == 0 ? l10n.logYourWatch : l10n.editYourRating,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRatingBottomSheet(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return SingleChildScrollView(
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _movie.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _movie.releaseDate?.split('-').first ?? '',
                    style: const TextStyle(color: Colors.white38),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildModalAction(
                        _isWatched ? Icons.visibility : Icons.visibility_outlined,
                        _isWatched ? l10n.watched : l10n.watch,
                        _isWatched,
                        () async {
                          await _toggleWatched();
                          setModalState(() {});
                        },
                        isLoading: _isTogglingWatched,
                      ),
                      _buildModalAction(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        _isLiked ? l10n.liked : l10n.like,
                        _isLiked,
                        () async {
                          await _toggleFavorite();
                          setModalState(() {});
                        },
                        isLoading: _isTogglingFavorite,
                      ),
                      _buildModalAction(
                        _isInWatchlist ? Icons.schedule : Icons.history_toggle_off,
                        l10n.watchlistAdd,
                        _isInWatchlist,
                        () async {
                          await _toggleWatchlist();
                          setModalState(() {});
                        },
                        isLoading: _isTogglingWatchlist,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),
                  _buildStarPicker(setModalState, l10n),
                  if (_userRating > 0) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _reviewController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: l10n.writeReview,
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmittingRating ? null : () async {
                          setModalState(() {});
                          await _submitRating();
                          setModalState(() {});
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmittingRating
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(l10n.submit, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => setState(() {}));
  }

  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite) return;
    setState(() => _isTogglingFavorite = true);
    final next = !_isLiked;
    try {
      if (next) {
        await MovieService.addFavorite(_movie.id);
      } else {
        await MovieService.removeFavorite(_movie.id);
      }
      if (mounted) setState(() { _isLiked = next; _isTogglingFavorite = false; });
    } catch (_) {
      if (mounted) setState(() => _isTogglingFavorite = false);
    }
  }

  Future<void> _toggleWatchlist() async {
    if (_isTogglingWatchlist) return;
    setState(() => _isTogglingWatchlist = true);
    final next = !_isInWatchlist;
    try {
      if (next) {
        await MovieService.addToWatchlist(_movie.id);
      } else {
        await MovieService.removeFromWatchlist(_movie.id);
      }
      if (mounted) setState(() { _isInWatchlist = next; _isTogglingWatchlist = false; });
    } catch (_) {
      if (mounted) setState(() => _isTogglingWatchlist = false);
    }
  }

  Future<void> _toggleWatched() async {
    if (_isTogglingWatched) return;
    setState(() => _isTogglingWatched = true);
    final next = !_isWatched;
    try {
      if (next) {
        await MovieService.markWatched(_movie.id);
      } else {
        await MovieService.unmarkWatched(_movie.id);
      }
      if (mounted) setState(() { _isWatched = next; _isTogglingWatched = false; });
    } catch (_) {
      if (mounted) setState(() => _isTogglingWatched = false);
    }
  }

  Future<void> _submitRating() async {
    if (_isSubmittingRating) return;
    setState(() => _isSubmittingRating = true);
    try {
      final futures = <Future>[
        MovieService.setRating(
          _movie.id,
          _userRating,
          _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
        ),
      ];
      if (!_isWatched) {
        futures.add(MovieService.markWatched(_movie.id));
      }
      await Future.wait(futures);
      if (mounted) setState(() => _isWatched = true);
      // Refresh reviews + user state in parallel (no need to refetch movie detail)
      _fetchReviews();
      _fetchUserState();
    } catch (_) {}
    if (mounted) setState(() => _isSubmittingRating = false);
  }

  Widget _buildModalAction(IconData icon, String label, bool isActive, VoidCallback onTap, {bool isLoading = false}) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      splashColor: AppTheme.secondaryPurple.withValues(alpha: 0.3),
      highlightColor: AppTheme.secondaryPurple.withValues(alpha: 0.1),
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            if (isLoading)
              const SizedBox(
                width: 32, height: 32,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondaryPurple),
              )
            else
              Icon(
                icon,
                size: 32,
                color: isActive ? AppTheme.secondaryPurple : Colors.white70,
              ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarPicker(StateSetter setModalState, AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTapDown: (details) {
                double tapPosition = details.localPosition.dx;
                double starWidth = 50.0;
                setModalState(() {
                  if (tapPosition < starWidth / 2) {
                    _userRating = index + 0.5;
                  } else {
                    _userRating = index + 1.0;
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Icon(
                  _userRating >= index + 1
                      ? Icons.star
                      : (_userRating >= index + 0.5 ? Icons.star_half : Icons.star_border),
                  color: AppTheme.secondaryPurple,
                  size: 50,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        if (_userRating == 0) ...[
          Text(
            l10n.rate,
            style: const TextStyle(color: AppTheme.secondaryPurple, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
        ],
      ],
    );
  }

  Widget _buildTabsSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.secondaryPurple,
            dividerColor: Colors.white10,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: l10n.cast),
              Tab(text: l10n.crew),
              Tab(text: l10n.genres),
              Tab(text: l10n.details),
            ],
          ),
          SizedBox(
            height: 250,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCastList(),
                _buildCrewList(),
                _buildGenreList(),
                _buildDetailsList(l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCastList() {
    final cast = _movie.cast ?? [];
    if (cast.isEmpty) return const Center(child: Text('No data', style: TextStyle(color: Colors.white38)));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      itemCount: cast.length,
      itemBuilder: (context, index) {
        final member = cast[index];
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PersonScreen(
                personId: member.id,
                name: member.name,
                role: member.character,
                profileUrl: member.profilePath != null ? member.profileUrl : null,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white10,
                  backgroundImage: member.profileUrl.isNotEmpty ? CachedNetworkImageProvider(member.profileUrl) : null,
                  radius: 20,
                  child: member.profileUrl.isEmpty ? const Icon(Icons.person, color: Colors.white10) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.character,
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white10, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCrewList() {
    final crew = _movie.crew ?? [];
    if (crew.isEmpty) return const Center(child: Text('No data', style: TextStyle(color: Colors.white38)));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      itemCount: min(20, crew.length),
      itemBuilder: (context, index) {
        final member = crew[index];
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PersonScreen(
                personId: member.id,
                name: member.name,
                role: member.job,
                profileUrl: member.profileUrl.isNotEmpty ? member.profileUrl : null,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white10,
                  backgroundImage: member.profileUrl.isNotEmpty ? CachedNetworkImageProvider(member.profileUrl) : null,
                  radius: 20,
                  child: member.profileUrl.isEmpty ? const Icon(Icons.person, color: Colors.white10) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.job,
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white10, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGenreList() {
    final genres = _movie.genres ?? [];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 8,
        children: genres.map((g) => Chip(
          avatar: Icon(_getGenreIcon(g.name), size: 16, color: AppTheme.secondaryPurple),
          label: Text(g.name), 
          backgroundColor: Colors.white10,
          side: const BorderSide(color: Colors.white24),
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
        )).toList(),
      ),
    );
  }

  IconData _getGenreIcon(String name) {
    switch (name.toLowerCase()) {
      case 'action': return Icons.flash_on;
      case 'adventure': return Icons.explore;
      case 'animation': return Icons.toys;
      case 'comedy': return Icons.sentiment_very_satisfied;
      case 'crime': return Icons.gavel;
      case 'documentary': return Icons.videocam;
      case 'drama': return Icons.theater_comedy;
      case 'family': return Icons.child_care;
      case 'fantasy': return Icons.auto_fix_high;
      case 'history': return Icons.history_edu;
      case 'horror': return Icons.scuba_diving;
      case 'music': return Icons.music_note;
      case 'mystery': return Icons.search;
      case 'romance': return Icons.favorite;
      case 'science fiction': return Icons.rocket_launch;
      case 'tv movie': return Icons.tv;
      case 'thriller': return Icons.psychology;
      case 'war': return Icons.military_tech;
      case 'western': return Icons.agriculture;
      default: return Icons.movie;
    }
  }

  Widget _buildDetailsList(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _detailItem(l10n.originalTitle, _movie.title),
        _detailItem(l10n.releaseDate, _movie.releaseDate ?? 'N/A'),
        _detailItem(l10n.popularity, _movie.popularity?.toString() ?? 'N/A'),
      ],
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 14, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(AppLocalizations l10n) {
    final reviewMaps = _reviews.map((r) => <String, dynamic>{
      'user': r.username,
      'userId': r.userId,
      'rating': r.stars,
      'text': r.review,
      'date': r.createdAt.toIso8601String().split('T').first,
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reviews,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.2),
          ),
          const SizedBox(height: 25),
          if (_isReviewsLoading)
            const Center(child: Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondaryPurple),
            ))
          else if (reviewMaps.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(l10n.noReviewsYet, style: const TextStyle(color: Colors.white38, fontSize: 13)),
            )
          else ...[
            ...reviewMaps.take(3).map((r) => _reviewItem(r['user'], r['userId'], r['rating'], r['text'])),
            if (reviewMaps.length > 3)
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllReviewsScreen(movie: _movie, reviews: reviewMaps),
                    ),
                  ),
                  child: Text(l10n.allReviews, style: const TextStyle(color: AppTheme.secondaryPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _reviewItem(String user, String? userId, double rating, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: userId != null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId, initialUsername: user))) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.surface,
                      radius: 10,
                      child: Text(
                        user.isNotEmpty ? user[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppTheme.secondaryPurple, fontWeight: FontWeight.bold, fontSize: 9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: userId != null ? AppTheme.secondaryPurple : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(children: List.generate(5, (i) => Icon(Icons.star, size: 12, color: i < rating ? AppTheme.secondaryPurple : Colors.white10))),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildSimilarMoviesSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            l10n.similarMovies,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.2),
          ),
        ),
        if (_isSimilarLoading)
          const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondaryPurple)),
          )
        else if (_similarMovies.isEmpty)
          const SizedBox(
            height: 150,
            child: Center(child: Text('—', style: TextStyle(color: Colors.white38))),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _similarMovies.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: MovieCard(
                    movie: _similarMovies[index],
                    width: 90,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: _similarMovies[index])));
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
