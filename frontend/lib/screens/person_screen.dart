import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../theme/app_theme.dart';

class PersonScreen extends StatefulWidget {
  final int personId;
  final String name;
  final String? profileUrl;

  /// Subtitle shown under the name (character name for cast, job title for crew).
  final String role;

  /// Optional bio — shown only if non-null and non-empty.
  /// TODO: fetch from backend GET /persons/{id}
  final String? bio;

  const PersonScreen({
    super.key,
    required this.personId,
    required this.name,
    required this.role,
    this.profileUrl,
    this.bio,
  });

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  late Future<List<Movie>> _filmographyFuture;

  @override
  void initState() {
    super.initState();
    _filmographyFuture = _loadFilmography();
  }

  /// Cross-reference all mock movies to find ones featuring this person.
  Future<List<Movie>> _loadFilmography() async {
    final all = await MovieService.getMockMovies();
    return all.where((m) {
      final inCast = m.cast?.any((c) => c.id == widget.personId) ?? false;
      final inCrew = m.crew?.any((c) => c.id == widget.personId) ?? false;
      return inCast || inCrew;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App bar with photo ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.background,
            flexibleSpace: FlexibleSpaceBar(
              background: _PersonHeader(
                name: widget.name,
                role: widget.role,
                profileUrl: widget.profileUrl,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Bio (conditionnelle) ─────────────────────────────────────
                if (widget.bio != null && widget.bio!.isNotEmpty) ...[
                  _SectionTitle(l10n.biography),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text(
                      widget.bio!,
                      style: const TextStyle(
                          color: AppTheme.textDim,
                          fontSize: 14,
                          height: 1.6),
                    ),
                  ),
                ],

                // ── Filmographie ─────────────────────────────────────────────
                _SectionTitle(l10n.filmography),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // ── Grid filmographie ────────────────────────────────────────────
          FutureBuilder<List<Movie>>(
            future: _filmographyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }

              final movies = snapshot.data ?? [];

              if (movies.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.noFilmography,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.textDim, fontSize: 14),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _FilmTile(movie: movies[i]),
                    childCount: movies.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2 / 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header : photo + nom + rôle
// ─────────────────────────────────────────────────────────────────────────────

class _PersonHeader extends StatelessWidget {
  final String name;
  final String role;
  final String? profileUrl;

  const _PersonHeader(
      {required this.name, required this.role, this.profileUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        profileUrl != null && profileUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surface,
            AppTheme.background,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48), // space for back button
            // Photo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.primaryPurple.withOpacity(0.5),
                    width: 2),
              ),
              child: ClipOval(
                child: hasPhoto
                    ? CachedNetworkImage(
                        imageUrl: profileUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey[850]),
                        errorWidget: (_, __, ___) =>
                            _PlaceholderAvatar(name: name),
                      )
                    : _PlaceholderAvatar(name: name),
              ),
            ),
            const SizedBox(height: 14),
            // Nom
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 4),
            // Rôle
            if (role.isNotEmpty)
              Text(
                role,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textDim),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderAvatar extends StatelessWidget {
  final String name;
  const _PlaceholderAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ').take(2).map((w) => w[0]).join();
    return Container(
      color: AppTheme.surface,
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryPurple),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Titre de section
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: AppTheme.textDim,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tuile film dans la filmographie
// ─────────────────────────────────────────────────────────────────────────────

class _FilmTile extends StatelessWidget {
  final Movie movie;
  const _FilmTile({required this.movie});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: movie.posterUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey[850]),
            errorWidget: (_, __, ___) =>
                Container(color: Colors.grey[850]),
          ),
          // Gradient + titre
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
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
                movie.title,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
