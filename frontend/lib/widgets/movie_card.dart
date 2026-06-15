import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final double? width;
  final VoidCallback? onTap;

  const MovieCard({
    super.key,
    required this.movie,
    this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Poster aspect ratio is typically 2:3 (width:height)
    const double aspectRatio = 2 / 3;

    Widget card = CachedNetworkImage(
      imageUrl: movie.posterUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[900],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[900],
        child: const Icon(Icons.movie, color: Colors.white24, size: 50),
      ),
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        child: card,
      );
    }

    if (width != null) {
      return SizedBox(
        width: width,
        height: width! / aspectRatio,
        child: card,
      );
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: card,
    );
  }
}
