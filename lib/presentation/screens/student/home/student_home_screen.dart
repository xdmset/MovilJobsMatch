import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/bottom_nav_bar.dart';
import 'widgets/vacancy_card.dart';
import 'widgets/swipe_buttons.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Cargar vacantes al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).loadVacancies();
    });
  }

  void _onNavBarTap(int index) {
  setState(() => _currentIndex = index);
  
  switch (index) {
    case 0:
      // Ya estamos en Home
      break;
    case 1:
      context.push(AppRoutes.studentApplications);
      break;
    case 2:
      context.push(AppRoutes.studentActivity);
      break;
    case 3:
      context.push(AppRoutes.studentProfile);
      break;
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<StudentProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                // Header
                _buildHeader(provider),

                // Vacancy Cards Stack
                Expanded(
                  child: _buildVacancyStack(provider),
                ),

                // Swipe Buttons
                if (provider.currentVacancy != null && !provider.hasReachedLimit)
                  SwipeButtons(
                    onLike: () => _handleLike(provider),
                    onDislike: () => _handleDislike(provider),
                  ),

                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavBarTap,
      ),
    );
  }

  Widget _buildHeader(StudentProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find Your Match',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: provider.hasReachedLimit
                          ? AppColors.error.withOpacity(0.1)
                          : AppColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 16,
                          color: provider.hasReachedLimit
                              ? AppColors.error
                              : AppColors.accentGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${provider.remainingSwipes} swipes left',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: provider.hasReachedLimit
                                ? AppColors.error
                                : AppColors.accentGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryPurple,
                width: 2,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, color: AppColors.primaryPurple),
              onPressed: () {
                // TODO: Mostrar filtros
                _showFiltersDialog();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacancyStack(StudentProvider provider) {
    if (provider.vacancies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_off_outlined,
              size: 80,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No vacancies available',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new opportunities',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    if (provider.hasReachedLimit) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Daily Limit Reached',
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You\'ve used all your daily swipes.\nUpgrade to Premium for unlimited matches!',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // TODO: Navegar a premium
                  context.push(AppRoutes.premium);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Upgrade to Premium',
                      style: AppTextStyles.button,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.currentVacancy == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppColors.accentGreen,
            ),
            const SizedBox(height: 16),
            Text(
              'You\'ve seen all vacancies!',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your applications or come back later',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push(AppRoutes.studentApplications),
              child: const Text('View Applications'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: VacancyCard(
        vacancy: provider.currentVacancy!,
        onSwipe: (direction) {
          if (direction == SwipeDirection.right) {
            _handleLike(provider);
          } else if (direction == SwipeDirection.left) {
            _handleDislike(provider);
          }
        },
      ),
    );
  }

  void _handleLike(StudentProvider provider) {
    if (provider.currentVacancy != null && !provider.hasReachedLimit) {
      provider.likeVacancy(provider.currentVacancy!);

      // Mostrar mensaje de match
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Liked ${provider.currentVacancy!.position}!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleDislike(StudentProvider provider) {
    if (!provider.hasReachedLimit) {
      provider.dislikeVacancy();
    }
  }

  void _showFiltersDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters', style: AppTextStyles.h4),
                  TextButton(
                    onPressed: () {
                      // TODO: Reset filters
                      Navigator.pop(context);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),

            // Filters content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Location', style: AppTextStyles.subtitle1),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip('Remote'),
                        _buildFilterChip('Hybrid'),
                        _buildFilterChip('On-site'),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text('Type', style: AppTextStyles.subtitle1),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip('Internship'),
                        _buildFilterChip('Part-time'),
                        _buildFilterChip('Full-time'),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Apply button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Apply filters
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return FilterChip(
      label: Text(label),
      selected: false,
      onSelected: (selected) {
        // TODO: Handle filter selection
      },
      backgroundColor: AppColors.surfaceGray,
      selectedColor: AppColors.primaryPurpleLight,
      checkmarkColor: Colors.white,
      labelStyle: AppTextStyles.bodySmall.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

enum SwipeDirection { left, right, none }