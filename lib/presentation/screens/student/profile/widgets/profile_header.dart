// lib/presentation/screens/student/profile/widgets/profile_header.dart

import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';

class ProfileHeader extends StatelessWidget {
  final String  name;
  final String  email;
  final String  university;
  final String  major;
  final String? fotoUrl;

  const ProfileHeader({
    super.key,
    required this.name, required this.email,
    required this.university, required this.major,
    this.fotoUrl,
  });

  String get _initials {
    final parts = name.trim().split(' ')
        .where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(children: [

        // ── Avatar circular compacto ────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: AppColors.primaryPurple.withOpacity(0.2),
              blurRadius: 10, offset: const Offset(0, 3),
            )],
          ),
          child: CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primaryPurpleLight,
            child: (fotoUrl == null || fotoUrl!.isEmpty)
                ? Text(_initials, style: AppTextStyles.h4.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold))
                : ClipOval(child: Image.network(
                    fotoUrl!,
                    width: 72, height: 72, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(_initials,
                        style: AppTextStyles.h4.copyWith(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child
                            : const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                  )),
          ),
        ),
        const SizedBox(width: 14),

        // ── Info ────────────────────────────────────────────────────────
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: AppTextStyles.h4.copyWith(
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(email, style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.school_outlined, size: 13,
                  color: AppColors.primaryPurple),
              const SizedBox(width: 4),
              Expanded(child: Text('$university · $major',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ],
        )),
      ]),
    );
  }
}