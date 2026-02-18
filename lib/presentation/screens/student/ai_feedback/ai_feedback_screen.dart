import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class AIFeedbackScreen extends StatefulWidget {
  final String? applicationId;
  final String? companyName;
  final String? position;

  const AIFeedbackScreen({
    super.key,
    this.applicationId,
    this.companyName,
    this.position,
  });

  @override
  State<AIFeedbackScreen> createState() => _AIFeedbackScreenState();
}

class _AIFeedbackScreenState extends State<AIFeedbackScreen> {
  bool _isAnalyzing = false;
  bool _analysisComplete = false;

  // Mock AI Analysis Results
  final Map<String, dynamic> _aiAnalysis = {
    'overallScore': 72,
    'strengths': [
      'Strong academic background in Computer Science',
      'Relevant project experience with mobile development',
      'Good communication skills demonstrated in portfolio',
    ],
    'weaknesses': [
      'Limited professional work experience',
      'Missing advanced React.js skills required for this position',
      'No mention of Node.js backend experience',
    ],
    'missingSkills': [
      {
        'skill': 'React.js (Advanced)',
        'importance': 'High',
        'currentLevel': 'Beginner',
        'requiredLevel': 'Advanced',
      },
      {
        'skill': 'Node.js',
        'importance': 'High',
        'currentLevel': 'None',
        'requiredLevel': 'Intermediate',
      },
      {
        'skill': 'TypeScript',
        'importance': 'Medium',
        'currentLevel': 'Beginner',
        'requiredLevel': 'Intermediate',
      },
    ],
    'recommendations': [
      {
        'title': 'Complete React Advanced Course',
        'description':
            'Focus on hooks, context API, and performance optimization',
        'platform': 'Udemy',
        'duration': '6 weeks',
        'priority': 'High',
      },
      {
        'title': 'Build Full-Stack Project',
        'description':
            'Create a MERN stack application to demonstrate end-to-end skills',
        'platform': 'Self-Study',
        'duration': '4 weeks',
        'priority': 'High',
      },
      {
        'title': 'Learn TypeScript Fundamentals',
        'description': 'Master TypeScript basics and integration with React',
        'platform': 'FreeCodeCamp',
        'duration': '3 weeks',
        'priority': 'Medium',
      },
    ],
    'studyPlan': {
      'totalWeeks': 12,
      'weeklyHours': 15,
      'phases': [
        {
          'phase': 'Foundation (Weeks 1-3)',
          'focus': 'TypeScript fundamentals and React basics',
          'goals': [
            'Complete TypeScript course',
            'Build 2 small React projects',
            'Practice daily coding challenges',
          ],
        },
        {
          'phase': 'Advanced Skills (Weeks 4-8)',
          'focus': 'Advanced React and Node.js',
          'goals': [
            'Master React hooks and patterns',
            'Learn Node.js and Express',
            'Build REST API',
          ],
        },
        {
          'phase': 'Portfolio Project (Weeks 9-12)',
          'focus': 'Full-stack application',
          'goals': [
            'Design and build MERN stack app',
            'Deploy to production',
            'Document and showcase',
          ],
        },
      ],
    },
    'employerFeedback':
        'While we appreciate your interest, we were looking for more hands-on experience with React and Node.js. Your portfolio shows great potential, but we need someone who can contribute immediately to our production codebase.',
  };

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    setState(() => _isAnalyzing = true);
    // Simulate AI analysis
    await Future.delayed(const Duration(seconds: 3));
    setState(() {
      _isAnalyzing = false;
      _analysisComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Career Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isAnalyzing
          ? _buildAnalyzingView()
          : _analysisComplete
              ? _buildAnalysisResults()
              : const SizedBox(),
    );
  }

  Widget _buildAnalyzingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: AppColors.purpleGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Analyzing Your Profile',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 16),
          Text(
            'Our AI is reviewing your CV and comparing it\nwith the job requirements...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildAnalysisResults() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Card
        _buildHeaderCard(),

        const SizedBox(height: 24),

        // Employer Feedback
        _buildEmployerFeedback(),

        const SizedBox(height: 24),

        // Overall Score
        _buildOverallScore(),

        const SizedBox(height: 24),

        // Strengths
        _buildSection(
          'Your Strengths 💪',
          _aiAnalysis['strengths'],
          AppColors.accentGreen,
          Icons.check_circle,
        ),

        const SizedBox(height: 24),

        // Areas to Improve
        _buildSection(
          'Areas to Improve 📈',
          _aiAnalysis['weaknesses'],
          AppColors.accentOrange,
          Icons.error_outline,
        ),

        const SizedBox(height: 24),

        // Missing Skills
        _buildMissingSkills(),

        const SizedBox(height: 24),

        // Learning Recommendations
        _buildRecommendations(),

        const SizedBox(height: 24),

        // Study Plan
        _buildStudyPlan(),

        const SizedBox(height: 24),

        // CTA Buttons
        _buildCTAButtons(),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.purpleGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Analysis Complete',
                      style: AppTextStyles.h4.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.companyName ?? 'Company',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.position ?? 'Position',
            style: AppTextStyles.h4.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployerFeedback() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
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
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'EMPLOYER FEEDBACK',
                style: AppTextStyles.overline.copyWith(
                  color: AppColors.accentRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _aiAnalysis['employerFeedback'],
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallScore() {
    final score = _aiAnalysis['overallScore'];
    final color = score >= 80
        ? AppColors.accentGreen
        : score >= 60
            ? AppColors.accentOrange
            : AppColors.accentRed;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Profile Match Score',
            style: AppTextStyles.h4,
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score%',
                    style: AppTextStyles.h1.copyWith(
                      color: color,
                      fontSize: 48,
                    ),
                  ),
                  Text(
                    'Match',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'You need to improve your skills to increase your match score',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      String title, List<String> items, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h4),
          const SizedBox(height: 16),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMissingSkills() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Missing Skills 🎯', style: AppTextStyles.h4),
          const SizedBox(height: 16),
          ..._aiAnalysis['missingSkills'].map<Widget>((skill) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          skill['skill'],
                          style: AppTextStyles.subtitle1.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: skill['importance'] == 'High'
                              ? AppColors.accentRed.withOpacity(0.1)
                              : AppColors.accentOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          skill['importance'],
                          style: AppTextStyles.bodySmall.copyWith(
                            color: skill['importance'] == 'High'
                                ? AppColors.accentRed
                                : AppColors.accentOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              skill['currentLevel'],
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        color: AppColors.textTertiary,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Required',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              skill['requiredLevel'],
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Learning Recommendations 📚', style: AppTextStyles.h4),
          const SizedBox(height: 16),
          ..._aiAnalysis['recommendations'].map<Widget>((rec) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: rec['priority'] == 'High'
                      ? AppColors.primaryPurple.withOpacity(0.3)
                      : AppColors.borderLight,
                  width: rec['priority'] == 'High' ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rec['title'],
                          style: AppTextStyles.subtitle1.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (rec['priority'] == 'High')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.purpleGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PRIORITY',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rec['description'],
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        rec['platform'],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        rec['duration'],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStudyPlan() {
    final studyPlan = _aiAnalysis['studyPlan'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personalized Study Plan 📅', style: AppTextStyles.h4),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryPurpleLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${studyPlan['totalWeeks']}',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    Text(
                      'Weeks',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.borderMedium,
                ),
                Column(
                  children: [
                    Text(
                      '${studyPlan['weeklyHours']}',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    Text(
                      'Hours/Week',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...studyPlan['phases'].map<Widget>((phase) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phase['phase'],
                    style: AppTextStyles.subtitle1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Focus: ${phase['focus']}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Goals:',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...phase['goals'].map<Widget>((goal) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: AppColors.accentGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              goal,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCTAButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Export study plan
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.download, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Study plan exported successfully!'),
                    ],
                  ),
                  backgroundColor: AppColors.accentGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Download Study Plan'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              context.push('/edit-profile');
            },
            icon: const Icon(Icons.edit),
            label: const Text('Update My Profile'),
          ),
        ),
      ],
    );
  }
}