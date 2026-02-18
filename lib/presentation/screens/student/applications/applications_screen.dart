import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../widgets/bottom_nav_bar.dart';
import 'widgets/application_card.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 1;

  // Mock data
  final List<Map<String, dynamic>> _allApplications = [
    {
      'id': '1',
      'company': 'TechCorp Inc.',
      'position': 'Software Engineer Intern',
      'logo': '💻',
      'location': 'San Francisco, CA',
      'appliedDate': '2024-01-15',
      'status': 'viewed',
      'salary': '\$45 - \$55 /hr',
    },
    {
      'id': '2',
      'company': 'DesignStudio',
      'position': 'UX Design Intern',
      'logo': '🎨',
      'location': 'New York, NY (Hybrid)',
      'appliedDate': '2024-01-18',
      'status': 'in_process',
      'salary': '\$30 - \$40 /hr',
    },
    {
      'id': '3',
      'company': 'Retail Giant',
      'position': 'Marketing Intern',
      'logo': '📦',
      'location': 'Remote',
      'appliedDate': '2024-01-10',
      'status': 'rejected',
      'salary': '\$25 - \$35 /hr',
      'feedback': 'Great interview, but we decided to move forward with candidates who have more marketing experience.',
    },
    {
      'id': '4',
      'company': 'The Coffee House',
      'position': 'Barista',
      'logo': '☕',
      'location': 'Palo Alto, CA',
      'appliedDate': '2024-01-20',
      'status': 'sent',
      'salary': '\$18 - \$22 /hr',
    },
    {
      'id': '5',
      'company': 'NextGen Startups',
      'position': 'Product Manager Intern',
      'logo': '🚀',
      'location': 'Austin, TX',
      'appliedDate': '2024-01-12',
      'status': 'in_process',
      'salary': '\$35 - \$45 /hr',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onNavBarTap(int index) {
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        context.go(AppRoutes.studentHome);
        break;
      case 1:
        // Ya estamos aquí
        break;
      case 2:
        context.go(AppRoutes.studentActivity);
        break;
      case 3:
        context.go(AppRoutes.studentProfile);
        break;
    }
  }

  List<Map<String, dynamic>> _getFilteredApplications(String status) {
    if (status == 'all') return _allApplications;
    return _allApplications.where((app) => app['status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Application Status & Feedback'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primaryPurple,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primaryPurple,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: AppTextStyles.bodyMedium,
          tabs: [
            Tab(
              child: Row(
                children: [
                  const Text('All'),
                  const SizedBox(width: 8),
                  _buildBadge(_allApplications.length),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('In Process'),
                  const SizedBox(width: 8),
                  _buildBadge(_getFilteredApplications('in_process').length),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Viewed'),
                  const SizedBox(width: 8),
                  _buildBadge(_getFilteredApplications('viewed').length),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Rejected'),
                  const SizedBox(width: 8),
                  _buildBadge(_getFilteredApplications('rejected').length),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApplicationsList(_allApplications),
          _buildApplicationsList(_getFilteredApplications('in_process')),
          _buildApplicationsList(_getFilteredApplications('viewed')),
          _buildApplicationsList(_getFilteredApplications('rejected')),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavBarTap,
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.primaryPurple,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildApplicationsList(List<Map<String, dynamic>> applications) {
    if (applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No applications yet',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start swiping to find your perfect match!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.studentHome),
              child: const Text('Browse Vacancies'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: applications.length,
      itemBuilder: (context, index) {
        final application = applications[index];
        return ApplicationCard(
          application: application,
          onTap: () => _showApplicationDetails(application),
        );
      },
    );
  }

  void _showApplicationDetails(Map<String, dynamic> application) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
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

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGray,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  application['logo'],
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
                                    application['company'],
                                    style: AppTextStyles.h4,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    application['position'],
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Status
                        _buildDetailRow(
                          icon: Icons.flag_outlined,
                          label: 'Status',
                          value: _getStatusText(application['status']),
                          valueColor: _getStatusColor(application['status']),
                        ),

                        const Divider(height: 32),

                        // Applied Date
                        _buildDetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Applied Date',
                          value: _formatDate(application['appliedDate']),
                        ),

                        const Divider(height: 32),

                        // Location
                        _buildDetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: application['location'],
                        ),

                        const Divider(height: 32),

                        // Salary
                        _buildDetailRow(
                          icon: Icons.attach_money,
                          label: 'Salary Range',
                          value: application['salary'],
                        ),

                        // Feedback section
                        if (application['status'] == 'rejected' &&
                            application['feedback'] != null) ...[
                          const Divider(height: 32),
                          _buildFeedbackSection(application['feedback']),
                        ],

                        // Timeline
                        const SizedBox(height: 32),
                        Text('Application Timeline', style: AppTextStyles.h4),
                        const SizedBox(height: 16),
                        _buildTimeline(application),

                        const SizedBox(height: 24),

                        // Action buttons
                        if (application['status'] == 'rejected')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                context.push(
                                  AppRoutes.aiFeedback, // Cambiado
                                  extra: {
                                    'applicationId': application['id'],
                                    'companyName': application['company'],
                                    'position': application['position'],
                                  },
                                );
                              },
                              icon: const Icon(Icons.psychology_outlined),
                              label: const Text('Get AI Career Analysis'),
                            ),
                          )
                        else if (application['status'] == 'in_process')
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Withdraw application
                              },
                              icon: const Icon(Icons.close),
                              label: const Text('Withdraw Application'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(
                                    color: AppColors.error, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackSection(String feedback) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentRed.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.feedback_outlined,
                color: AppColors.accentRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'EMPLOYER FEEDBACK',
                style: AppTextStyles.overline.copyWith(
                  color: AppColors.accentRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            feedback,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'While we appreciate your interest, we\'ve decided to move forward with another candidate for this Jr. position opening next month.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Map<String, dynamic> application) {
    final status = application['status'];
    final steps = [
      {
        'title': 'Application Sent',
        'date': application['appliedDate'],
        'completed': true,
      },
      {
        'title': 'CV Viewed',
        'date': '2024-01-16',
        'completed':
            status == 'viewed' || status == 'in_process' || status == 'rejected',
      },
      {
        'title': 'Interview Completed',
        'date': status == 'in_process' || status == 'rejected' ? '2024-01-18' : null,
        'completed': status == 'in_process' || status == 'rejected',
      },
      {
        'title': status == 'rejected' ? 'Not Selected' : 'Final Decision',
        'date': status == 'rejected' ? '2024-01-20' : null,
        'completed': status == 'rejected',
      },
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: step['completed'] == true
                        ? (status == 'rejected' && isLast
                            ? AppColors.accentRed
                            : AppColors.accentGreen)
                        : AppColors.borderLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: step['completed'] == true
                          ? (status == 'rejected' && isLast
                              ? AppColors.accentRed
                              : AppColors.accentGreen)
                          : AppColors.borderMedium,
                      width: 2,
                    ),
                  ),
                  child: step['completed'] == true
                      ? Icon(
                          status == 'rejected' && isLast
                              ? Icons.close
                              : Icons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: step['completed'] == true
                        ? AppColors.accentGreen
                        : AppColors.borderLight,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step['title'] as String,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: step['completed'] == true
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                    if (step['date'] != null)
                      Text(
                        _formatDate(step['date'] as String),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'sent':
        return 'Application Sent';
      case 'viewed':
        return 'CV Viewed';
      case 'in_process':
        return 'In Process';
      case 'rejected':
        return 'Not Selected';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent':
        return AppColors.statusSent;
      case 'viewed':
        return AppColors.statusViewed;
      case 'in_process':
        return AppColors.statusInProcess;
      case 'rejected':
        return AppColors.statusRejected;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}