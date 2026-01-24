import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../widgets/bottom_nav_bar.dart';
import 'widgets/activity_item.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 2;

  // Mock data
  final List<Map<String, dynamic>> _allActivities = [
    {
      'id': '1',
      'type': 'match',
      'company': 'TechCorp Inc.',
      'position': 'Software Engineer Intern',
      'logo': '💻',
      'timestamp': '2024-01-22T10:30:00',
      'description': 'You matched with TechCorp Inc.',
    },
    {
      'id': '2',
      'type': 'application',
      'company': 'DesignStudio',
      'position': 'UX Design Intern',
      'logo': '🎨',
      'timestamp': '2024-01-22T09:15:00',
      'description': 'Application submitted successfully',
    },
    {
      'id': '3',
      'type': 'discard',
      'company': 'Marketing Co.',
      'position': 'Marketing Intern',
      'logo': '📢',
      'timestamp': '2024-01-22T08:45:00',
      'description': 'You passed on this opportunity',
    },
    {
      'id': '4',
      'type': 'match',
      'company': 'StartupHub',
      'position': 'Product Manager Intern',
      'logo': '🚀',
      'timestamp': '2024-01-21T16:20:00',
      'description': 'You matched with StartupHub',
    },
    {
      'id': '5',
      'type': 'view',
      'company': 'E-commerce Giant',
      'position': 'Data Analyst Intern',
      'logo': '📊',
      'timestamp': '2024-01-21T14:00:00',
      'description': 'Viewed vacancy details',
    },
    {
      'id': '6',
      'type': 'feedback',
      'company': 'Retail Giant',
      'position': 'Marketing Intern',
      'logo': '📦',
      'timestamp': '2024-01-21T11:30:00',
      'description': 'Received feedback from employer',
    },
    {
      'id': '7',
      'type': 'discard',
      'company': 'Finance Corp',
      'position': 'Financial Analyst Intern',
      'logo': '💰',
      'timestamp': '2024-01-20T15:45:00',
      'description': 'You passed on this opportunity',
    },
    {
      'id': '8',
      'type': 'match',
      'company': 'Tech Innovations',
      'position': 'Mobile Developer Intern',
      'logo': '📱',
      'timestamp': '2024-01-20T10:00:00',
      'description': 'You matched with Tech Innovations',
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
        context.go(AppRoutes.studentApplications);
        break;
      case 2:
        // Ya estamos aquí
        break;
      case 3:
        context.go(AppRoutes.studentProfile);
        break;
    }
  }

  List<Map<String, dynamic>> _getFilteredActivities(String type) {
    if (type == 'all') return _allActivities;
    return _allActivities.where((activity) => activity['type'] == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Activity History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
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
                  _buildBadge(_allActivities.length),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Matches'),
                  const SizedBox(width: 8),
                  _buildBadge(_getFilteredActivities('match').length),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Applications'),
                  const SizedBox(width: 8),
                  _buildBadge(_getFilteredActivities('application').length),
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Discarded'),
                  const SizedBox(width: 8),
                  _buildBadge(_getFilteredActivities('discard').length),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityList(_allActivities),
          _buildActivityList(_getFilteredActivities('match')),
          _buildActivityList(_getFilteredActivities('application')),
          _buildActivityList(_getFilteredActivities('discard')),
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

  Widget _buildActivityList(List<Map<String, dynamic>> activities) {
    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No activity yet',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start swiping to see your activity here',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    // Agrupar por fecha
    final groupedActivities = _groupActivitiesByDate(activities);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedActivities.length,
      itemBuilder: (context, index) {
        final dateGroup = groupedActivities[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de fecha
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 12),
              child: Text(
                dateGroup['date'],
                style: AppTextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Actividades de ese día
            ...dateGroup['activities'].map<Widget>((activity) {
              return ActivityItem(
                activity: activity,
                onTap: () => _showActivityDetails(activity),
              );
            }).toList(),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _groupActivitiesByDate(
      List<Map<String, dynamic>> activities) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var activity in activities) {
      final date = DateTime.parse(activity['timestamp']);
      final dateKey = _formatDateHeader(date);

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(activity);
    }

    return grouped.entries
        .map((entry) => {
              'date': entry.key,
              'activities': entry.value,
            })
        .toList();
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final activityDate = DateTime(date.year, date.month, date.day);

    if (activityDate == today) {
      return 'Today';
    } else if (activityDate == yesterday) {
      return 'Yesterday';
    } else {
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  void _showActivityDetails(Map<String, dynamic> activity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Company logo and info
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
                      activity['logo'],
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
                        activity['company'],
                        style: AppTextStyles.h4,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity['position'],
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

            // Activity type
            _buildDetailRow(
              'Activity Type',
              _getActivityTypeText(activity['type']),
              _getActivityIcon(activity['type']),
              _getActivityColor(activity['type']),
            ),

            const Divider(height: 32),

            // Timestamp
            _buildDetailRow(
              'Date & Time',
              _formatDateTime(activity['timestamp']),
              Icons.access_time,
              AppColors.textSecondary,
            ),

            const SizedBox(height: 24),

            // Action buttons
            if (activity['type'] == 'match')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.studentApplications);
                  },
                  child: const Text('View Application'),
                ),
              )
            else if (activity['type'] == 'discard')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: Reactivar vacante
                  },
                  child: const Text('Find Similar Jobs'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getActivityTypeText(String type) {
    switch (type) {
      case 'match':
        return 'Matched';
      case 'application':
        return 'Applied';
      case 'discard':
        return 'Passed';
      case 'view':
        return 'Viewed';
      case 'feedback':
        return 'Received Feedback';
      default:
        return 'Unknown';
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'match':
        return Icons.favorite;
      case 'application':
        return Icons.send;
      case 'discard':
        return Icons.close;
      case 'view':
        return Icons.visibility;
      case 'feedback':
        return Icons.feedback;
      default:
        return Icons.help_outline;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'match':
        return AppColors.accentGreen;
      case 'application':
        return AppColors.accentBlue;
      case 'discard':
        return AppColors.accentRed;
      case 'view':
        return AppColors.primaryPurple;
      case 'feedback':
        return AppColors.accentOrange;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDateTime(String timestamp) {
    final date = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
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
      return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Date Range'),
              onTap: () {
                // TODO: Implementar filtro de fecha
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('By Company'),
              onTap: () {
                // TODO: Implementar filtro por empresa
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}