import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

class AllReviewsScreen extends StatelessWidget {
  final Movie movie;
  final List<Map<String, dynamic>> reviews;

  const AllReviewsScreen({
    super.key,
    required this.movie,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.allReviews,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              movie.title,
              style: const TextStyle(fontSize: 12, color: AppTheme.textDim),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: reviews.isEmpty
          ? Center(
              child: Text(
                l10n.noReviewsYet,
                style: const TextStyle(color: AppTheme.textDim),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: reviews.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: Colors.white10, height: 1),
              itemBuilder: (_, i) => _ReviewTile(review: reviews[i]),
            ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final String user = review['user'] as String;
    final String? userId = review['userId'] as String?;
    final double rating = (review['rating'] as num).toDouble();
    final String text = review['text'] as String;
    final String? date = review['date'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: userId != null
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(
                              userId: userId,
                              initialUsername: user,
                            ),
                          ),
                        )
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.surface,
                      radius: 16,
                      child: Text(
                        user.isNotEmpty ? user[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppTheme.secondaryPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      user,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: userId != null
                            ? AppTheme.secondaryPurple
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating.floor()
                        ? Icons.star
                        : (i < rating ? Icons.star_half : Icons.star_border),
                    size: 14,
                    color: i < rating
                        ? AppTheme.secondaryPurple
                        : Colors.white10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          if (date != null) ...[
            const SizedBox(height: 8),
            Text(
              date,
              style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
