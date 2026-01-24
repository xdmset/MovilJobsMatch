import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../data/models/vacancy_model.dart';
import '../student_home_screen.dart';

class VacancyCard extends StatefulWidget {
  final VacancyModel vacancy;
  final Function(SwipeDirection)? onSwipe;

  const VacancyCard({
    super.key,
    required this.vacancy,
    this.onSwipe,
  });

  @override
  State<VacancyCard> createState() => _VacancyCardState();
}

class _VacancyCardState extends State<VacancyCard> with SingleTickerProviderStateMixin {
  Offset _position = Offset.zero;
  bool _isDragging = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final angle = _position.dx / size.width * 0.5;

    return GestureDetector(
      onPanStart: (details) {
        setState(() => _isDragging = true);
      },
      onPanUpdate: (details) {
        setState(() {
          _position += details.delta;
        });
      },
      onPanEnd: (details) {
        setState(() => _isDragging = false);

        final swipeThreshold = size.width * 0.3;

        if (_position.dx.abs() > swipeThreshold) {
          // Swipe completado
          final direction = _position.dx > 0
              ? SwipeDirection.right
              : SwipeDirection.left;

          _animateCardOff(direction);
        } else {
          // Regresar a la posición original
          _resetPosition();
        }
      },
      child: AnimatedContainer(
        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(_position.dx, _position.dy)
          ..rotateZ(angle),
        child: Stack(
          children: [
            _buildCard(),
            if (_isDragging) _buildSwipeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con logo y empresa
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.purpleGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Logo de la empresa
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            widget.vacancy.companyLogo,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.vacancy.companyName,
                              style: AppTextStyles.subtitle1.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.vacancy.location,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '98%',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Contenido principal
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Posición
                    Text(
                      widget.vacancy.position,
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 8),

                    // Tipo y salario
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGray,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.vacancy.type,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Salario estimado
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.attach_money,
                            color: AppColors.accentGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ESTIMATED SALARY',
                            style: AppTextStyles.overline.copyWith(
                              color: AppColors.accentGreen,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            widget.vacancy.salary,
                            style: AppTextStyles.h4.copyWith(
                              color: AppColors.accentGreen,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Descripción
                    Text(
                      'Role Overview',
                      style: AppTextStyles.h4,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.vacancy.description,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Requisitos
                    Text(
                      'Top Skills',
                      style: AppTextStyles.h4,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.vacancy.requirements.map((req) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurpleLight.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryPurpleLight.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: AppColors.primaryPurple,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                req,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryPurple,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Botón de ver más
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          // TODO: Mostrar detalles completos
                        },
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Read full description'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeIndicator() {
    final opacity = (_position.dx.abs() / 100).clamp(0.0, 1.0);
    final isLike = _position.dx > 0;

    return Positioned(
      top: 50,
      left: isLike ? null : 40,
      right: isLike ? 40 : null,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: isLike ? -0.3 : 0.3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isLike ? AppColors.accentGreen : AppColors.accentRed,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
            ),
            child: Text(
              isLike ? 'LIKE' : 'PASS',
              style: AppTextStyles.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _animateCardOff(SwipeDirection direction) {
    final size = MediaQuery.of(context).size;
    final endX = direction == SwipeDirection.right ? size.width : -size.width;

    setState(() {
      _position = Offset(endX * 2, _position.dy);
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      widget.onSwipe?.call(direction);
      _resetPosition();
    });
  }

  void _resetPosition() {
    setState(() {
      _position = Offset.zero;
    });
  }
}