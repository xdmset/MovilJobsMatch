// lib/presentation/screens/student/profile/widgets/profile_header.dart

import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String university;
  final String major;
  final String? fotoUrl;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.email,
    required this.university,
    required this.major,
    this.fotoUrl,
  });

  String get _initials {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -50),
      child: Column(
        children: [
          // ── Foto ────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBackground, width: 4),
              boxShadow: [BoxShadow(
                color: AppColors.textPrimary.withOpacity(0.1),
                blurRadius: 20, offset: const Offset(0, 10),
              )],
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.primaryPurpleLight,
              // Usamos Image.network con errorBuilder en lugar de backgroundImage
              // para manejar fallos de DNS/red sin crash
              child: (fotoUrl == null || fotoUrl!.isEmpty)
                  ? Text(_initials, style: AppTextStyles.h1.copyWith(color: Colors.white))
                  : ClipOval(
                      child: Image.network(
                        fotoUrl!,
                        width: 120, height: 120, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          _initials,
                          style: AppTextStyles.h1.copyWith(color: Colors.white),
                        ),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const SizedBox(
                                width: 120, height: 120,
                                child: Center(child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)),
                              ),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Nombre ───────────────────────────────────────────────────────
          Text(name, style: AppTextStyles.h2),
          const SizedBox(height: 4),

          // ── Email ─────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(email, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            ],
          ),

          const SizedBox(height: 12),

          // ── Universidad ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceGray,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school, size: 18, color: AppColors.primaryPurple),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(university, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                    Text(major, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}