import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/profile_models.dart';
import '../providers/locale_provider.dart';
import '../services/auth_service.dart';
import '../services/movie_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'movie_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data bundle loaded once for the whole screen
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileData {
  final ProfileUser user;
  final List<ProfileMovieCard> favorites;
  final List<ProfileMovieCard> watched;
  final List<ProfileRating> ratings;

  _ProfileData({
    required this.user,
    required this.favorites,
    required this.watched,
    required this.ratings,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  /// If null → shows the currently authenticated user's profile (editable).
  /// If provided → shows another user's profile (read-only).
  final String? userId;

  /// Display name shown in the AppBar while data is loading (optional).
  final String? initialUsername;

  const ProfileScreen({super.key, this.userId, this.initialUsername});

  bool get isOwnProfile => userId == null;

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<_ProfileData> _dataFuture;
  final _service = ProfileService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _dataFuture = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_ProfileData> _load() async {
    if (widget.isOwnProfile) {
      final results = await Future.wait([
        _service.getMe(),
        _service.getMyFavorites(),
        _service.getMyWatched(),
        _service.getMyRatings(),
      ]);
      return _ProfileData(
        user: results[0] as ProfileUser,
        favorites: results[1] as List<ProfileMovieCard>,
        watched: results[2] as List<ProfileMovieCard>,
        ratings: results[3] as List<ProfileRating>,
      );
    } else {
      final uid = widget.userId!;
      final results = await Future.wait([
        _service.getUser(uid),
        _service.getUserFavorites(uid),
        _service.getUserWatched(uid),
        _service.getUserRatings(uid),
      ]);
      return _ProfileData(
        user: results[0] as ProfileUser,
        favorites: results[1] as List<ProfileMovieCard>,
        watched: results[2] as List<ProfileMovieCard>,
        ratings: results[3] as List<ProfileRating>,
      );
    }
  }

  void reload() => setState(() {
        _dataFuture = _load();
      });

  void _refresh() => reload();

  Future<void> _onMovieTap(int tmdbId) async {
    final opened = await _openDetail(context, tmdbId);
    if (opened && mounted) _refresh();
  }

  Future<void> _confirmLogout(
      BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(l10n.logOut,
            style: const TextStyle(color: AppTheme.textMain)),
        content: Text(l10n.logOutConfirm,
            style: const TextStyle(color: AppTheme.textDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel,
                style: const TextStyle(color: AppTheme.textDim)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent),
            child: Text(l10n.logOut),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await AuthService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<_ProfileData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _scaffold(
            l10n,
            username: widget.initialUsername,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _scaffold(
            l10n,
            username: widget.initialUsername,
            body: _ErrorState(
              message: snapshot.error.toString(),
              onRetry: _refresh,
              l10n: l10n,
            ),
          );
        }

        final data = snapshot.data!;
        return _buildLoaded(context, l10n, data);
      },
    );
  }

  Widget _scaffold(
    AppLocalizations l10n, {
    required String? username,
    required Widget body,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Text(username ?? l10n.profile),
        centerTitle: !widget.isOwnProfile,
      ),
      body: body,
    );
  }

  Widget _buildLoaded(
      BuildContext context, AppLocalizations l10n, _ProfileData data) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOwnProfile ? l10n.profile : data.user.username.toUpperCase()),
        centerTitle: !widget.isOwnProfile,
        actions: [
          if (widget.isOwnProfile) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editProfile,
              onPressed: () => _showEditSheet(context, l10n, data.user),
            ),
            IconButton(
              icon: const Icon(Icons.logout, size: 20),
              tooltip: l10n.logOut,
              onPressed: () => _confirmLogout(context, l10n),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _ProfileHeader(
            user: data.user,
            favoritesCount: data.favorites.length,
            watchedCount: data.watched.length,
            ratingsCount: data.ratings.length,
            l10n: l10n,
          ),
          _buildTabBar(l10n),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MovieGrid(
                  movies: data.favorites,
                  emptyLabel: l10n.noFavorites,
                  onMovieTap: _onMovieTap,
                ),
                _MovieGrid(
                  movies: data.watched,
                  emptyLabel: l10n.noWatched,
                  onMovieTap: _onMovieTap,
                ),
                _RatingsList(
                  ratings: data.ratings,
                  emptyLabel: l10n.noRatingsYet,
                  onMovieTap: _onMovieTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    return Container(
      color: AppTheme.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.secondaryPurple,
        unselectedLabelColor: AppTheme.textDim,
        indicatorColor: AppTheme.primaryPurple,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        tabs: [
          Tab(text: l10n.favoritesTab),
          Tab(text: l10n.watchedTab),
          Tab(text: l10n.ratingsTab),
        ],
      ),
    );
  }

  // ── Edit bottom sheet ──────────────────────────────────────────────────────

  void _showEditSheet(
      BuildContext context, AppLocalizations l10n, ProfileUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditProfileSheet(
        user: user,
        l10n: l10n,
        onSaved: ({username, email, language, currentPassword, newPassword}) async {
          if (username != null || email != null || language != null) {
            await _service.updateMe(
              username: username,
              email: email,
              language: language,
            );
          }
          if (currentPassword != null && newPassword != null) {
            await _service.changePassword(currentPassword, newPassword);
          }
          _refresh();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final ProfileUser user;
  final int favoritesCount;
  final int watchedCount;
  final int ratingsCount;
  final AppLocalizations l10n;

  const _ProfileHeader({
    required this.user,
    required this.favoritesCount,
    required this.watchedCount,
    required this.ratingsCount,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final initials = user.username.length >= 2
        ? user.username.substring(0, 2).toUpperCase()
        : user.username.toUpperCase();

    final year = user.createdAt.year.toString();

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.primaryPurple,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Username
          Text(
            user.username,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 4),
          // Member since
          Text(
            '${l10n.memberSince} $year',
            style: const TextStyle(fontSize: 12, color: AppTheme.textDim),
          ),
          const SizedBox(height: 16),
          // Stats row
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatItem(count: favoritesCount, label: l10n.favoritesTab),
                const VerticalDivider(
                    color: Colors.white12, width: 32, thickness: 1),
                _StatItem(count: watchedCount, label: l10n.watchedTab),
                const VerticalDivider(
                    color: Colors.white12, width: 32, thickness: 1),
                _StatItem(count: ratingsCount, label: l10n.ratingsTab),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;

  const _StatItem({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.secondaryPurple,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppTheme.textDim,
          ),
        ),
      ],
    );
  }
}

// Fetch the full movie detail from the backend, then open its screen.
// Returns true if the detail screen was opened (so the caller can refresh).
Future<bool> _openDetail(BuildContext context, int tmdbId) async {
  try {
    final full = await MovieService.getMovieDetail(tmdbId);
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: full)),
      );
      return true;
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Film introuvable')),
      );
    }
  }
  return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Movie grid (Favorites + Watched tabs)
// ─────────────────────────────────────────────────────────────────────────────

class _MovieGrid extends StatelessWidget {
  final List<ProfileMovieCard> movies;
  final String emptyLabel;
  final Future<void> Function(int tmdbId)? onMovieTap;

  const _MovieGrid({required this.movies, required this.emptyLabel, this.onMovieTap});

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(color: AppTheme.textDim, fontSize: 14),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: movies.length,
      itemBuilder: (_, i) => _PosterTile(movie: movies[i], onTap: onMovieTap),
    );
  }
}

class _PosterTile extends StatelessWidget {
  final ProfileMovieCard movie;
  final Future<void> Function(int tmdbId)? onTap;

  const _PosterTile({required this.movie, this.onTap});

  @override
  Widget build(BuildContext context) {
    final posterUrl = movie.posterUrl;

    Widget image;
    if (posterUrl != null && posterUrl.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: posterUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(color: Colors.grey[850]),
        errorWidget: (_, __, ___) => _fallback(),
      );
    } else {
      image = _fallback();
    }

    return GestureDetector(
      onTap: () => onTap != null ? onTap!(movie.tmdbId) : _openDetail(context, movie.tmdbId),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: image,
      ),
    );
  }

  Widget _fallback() => Container(
        color: Colors.grey[850],
        child: const Center(
          child: Icon(Icons.movie, color: Colors.white24, size: 32),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Ratings list (Notes tab)
// ─────────────────────────────────────────────────────────────────────────────

class _RatingsList extends StatelessWidget {
  final List<ProfileRating> ratings;
  final String emptyLabel;
  final Future<void> Function(int tmdbId)? onMovieTap;

  const _RatingsList({required this.ratings, required this.emptyLabel, this.onMovieTap});

  @override
  Widget build(BuildContext context) {
    if (ratings.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(color: AppTheme.textDim, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: ratings.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (_, i) => _RatingTile(rating: ratings[i], onTap: onMovieTap),
    );
  }
}

class _RatingTile extends StatelessWidget {
  final ProfileRating rating;
  final Future<void> Function(int tmdbId)? onTap;

  const _RatingTile({required this.rating, this.onTap});

  @override
  Widget build(BuildContext context) {
    final movie = rating.movie;
    final posterUrl = movie.posterUrl;

    return GestureDetector(
      onTap: () => onTap != null ? onTap!(movie.tmdbId) : _openDetail(context, movie.tmdbId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 48,
              height: 72,
              child: posterUrl != null && posterUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: Colors.grey[850]),
                      errorWidget: (_, __, ___) =>
                          Container(color: Colors.grey[850]),
                    )
                  : Container(
                      color: Colors.grey[850],
                      child: const Icon(Icons.movie,
                          color: Colors.white24, size: 20),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (movie.year.isNotEmpty)
                  Text(
                    movie.year,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textDim),
                  ),
                const SizedBox(height: 6),
                // Star rating
                _StarRow(stars: rating.stars),
                if (rating.review != null && rating.review!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    rating.review!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textDim,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double stars; // 0.0–5.0 in 0.5 steps

  const _StarRow({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < stars.floor();
        final half = !filled && i < stars;
        return Icon(
          filled
              ? Icons.star
              : half
                  ? Icons.star_half
                  : Icons.star_border,
          size: 14,
          color: AppTheme.secondaryPurple,
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit profile bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final ProfileUser user;
  final AppLocalizations l10n;
  final Future<void> Function({
    String? username,
    String? email,
    String? language,
    String? currentPassword,
    String? newPassword,
  }) onSaved;

  const _EditProfileSheet({
    required this.user,
    required this.l10n,
    required this.onSaved,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  final TextEditingController _currentPasswordCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  late String _language;
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _emailCtrl = TextEditingController(text: widget.user.email);
    final currentLocale = context.read<LocaleProvider>().locale.languageCode;
    _language = currentLocale == 'en' ? 'en-US' : 'fr-FR';
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final newUsername = _usernameCtrl.text.trim() != widget.user.username
        ? _usernameCtrl.text.trim()
        : null;
    final newEmail = _emailCtrl.text.trim() != widget.user.email
        ? _emailCtrl.text.trim()
        : null;
    final currentLocale = context.read<LocaleProvider>().locale.languageCode;
    final newLanguage = _language.startsWith(currentLocale) ? null : _language;
    final currentPw = _currentPasswordCtrl.text.isEmpty
        ? null
        : _currentPasswordCtrl.text;
    final newPw =
        _newPasswordCtrl.text.isEmpty ? null : _newPasswordCtrl.text;

    setState(() => _saving = true);
    try {
      await widget.onSaved(
        username: newUsername,
        email: newEmail,
        language: newLanguage,
        currentPassword: currentPw,
        newPassword: newPw,
      );
      if (!mounted) return;
      if (newLanguage != null) {
        context.read<LocaleProvider>().setLocale(
              Locale(newLanguage.startsWith('en') ? 'en' : 'fr'),
            );
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.editProfile,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 24),

            // ── Username ──────────────────────────────────────────────────
            _label(l10n.usernameLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameCtrl,
              style: const TextStyle(color: AppTheme.textMain),
              decoration: _inputDecoration(
                hint: 'john_doe',
                prefix: const Icon(Icons.person_outline,
                    size: 18, color: AppTheme.textDim),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 3) {
                  return '3 caractères minimum';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Email ─────────────────────────────────────────────────────
            _label(l10n.emailLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppTheme.textMain),
              decoration: _inputDecoration(
                hint: 'vous@exemple.com',
                prefix: const Icon(Icons.mail_outline,
                    size: 18, color: AppTheme.textDim),
              ),
              validator: (v) {
                if (v == null || !v.contains('@')) {
                  return 'Adresse e-mail invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Language toggle ───────────────────────────────────────────
            _label(l10n.languageLabel),
            const SizedBox(height: 8),
            _LanguageToggle(
              value: _language,
              onChanged: (v) => setState(() => _language = v),
            ),

            const SizedBox(height: 28),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),

            // ── Password section ──────────────────────────────────────────
            _label(l10n.changePasswordLabel),
            const SizedBox(height: 4),
            Text(
              l10n.changePasswordHint,
              style: const TextStyle(fontSize: 11, color: AppTheme.textDim),
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _currentPasswordCtrl,
              hint: l10n.currentPasswordLabel,
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
              validator: (v) {
                // Requis dès qu'un nouveau mot de passe est saisi.
                if (_newPasswordCtrl.text.isNotEmpty &&
                    (v == null || v.isEmpty)) {
                  return l10n.currentPasswordLabel;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _newPasswordCtrl,
              hint: l10n.newPasswordLabel,
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v != null && v.isNotEmpty && v.length < 8) {
                  return '8 caractères minimum';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _confirmPasswordCtrl,
              hint: l10n.confirmNewPasswordLabel,
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (_newPasswordCtrl.text.isNotEmpty &&
                    v != _newPasswordCtrl.text) {
                  return l10n.passwordMismatch;
                }
                return null;
              },
            ),

            const SizedBox(height: 28),

            // ── Save button ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        l10n.save,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12, color: AppTheme.textDim, letterSpacing: 0.8),
      );

  InputDecoration _inputDecoration({String? hint, Widget? prefix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: prefix,
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryPurple),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

class _LanguageToggle extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const _LanguageToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LangButton(
          flag: '🇫🇷',
          label: 'Français',
          code: 'fr-FR',
          selected: value == 'fr-FR',
          onTap: () => onChanged('fr-FR'),
        ),
        const SizedBox(width: 10),
        _LangButton(
          flag: '🇺🇸',
          label: 'English',
          code: 'en-US',
          selected: value == 'en-US',
          onTap: () => onChanged('en-US'),
        ),
      ],
    );
  }
}

class _LangButton extends StatelessWidget {
  final String flag;
  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  const _LangButton({
    required this.flag,
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryPurple.withOpacity(0.2)
                : AppTheme.background,
            border: Border.all(
              color: selected ? AppTheme.primaryPurple : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      selected ? AppTheme.secondaryPurple : AppTheme.textDim,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textMain),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: const Icon(Icons.lock_outline,
            size: 18, color: AppTheme.textDim),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 18,
            color: AppTheme.textDim,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryPurple),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: validator,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error states
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final AppLocalizations l10n;

  const _ErrorState(
      {required this.message, required this.onRetry, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.textDim),
            const SizedBox(height: 16),
            Text(
              message,
              style:
                  const TextStyle(color: AppTheme.textDim, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: Text(l10n.retry,
                  style:
                      const TextStyle(color: AppTheme.secondaryPurple)),
            ),
          ],
        ),
      ),
    );
  }
}
