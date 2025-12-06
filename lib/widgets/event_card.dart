import 'package:flutter/material.dart';
import '../models/event.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Fixed dimensions for consistent card size
    // Width: Screen width - 32px (16px margin on each side)
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth - 32.0; // 16px margin left + 16px margin right
    const double cardHeight = 200.0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: cardWidth,
          height: cardHeight,
          child: event.imageUrl != null && event.imageUrl!.isNotEmpty
              ? Image.network(
                  event.imageUrl!,
                  width: cardWidth,
                  height: cardHeight,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: cardWidth,
                      height: cardHeight,
                      color: Colors.grey.shade300,
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 48,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: cardWidth,
                      height: cardHeight,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                )
              : Container(
                  width: cardWidth,
                  height: cardHeight,
                  color: Colors.grey.shade300,
                  child: const Icon(
                    Icons.image,
                    color: Colors.grey,
                    size: 48,
                  ),
                ),
        ),
      ),
    );
  }
}

