import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';

class SwipeButtons extends StatelessWidget {
  final VoidCallback onDislike;
  final VoidCallback onLike;

  const SwipeButtons({
    super.key,
    required this.onDislike,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Dislike Button
          _buildButton(
            icon: Icons.close,
            color: AppColors.accentRed,
            onPressed: onDislike,
            size: 60,
          ),

          const SizedBox(width: 24),

          // Like Button
          _buildButton(
            icon: Icons.favorite,
            color: AppColors.primaryPurple,
            onPressed: onLike,
            size: 70,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: 3,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: size * 0.4,
            ),
          ),
        ),
      ),
    );
  }
}