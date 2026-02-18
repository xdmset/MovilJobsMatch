import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';

class RegisterStudentScreen extends StatefulWidget {
  const RegisterStudentScreen({super.key});

  @override
  State<RegisterStudentScreen> createState() => _RegisterStudentScreenState();
}

class _RegisterStudentScreenState extends State<RegisterStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;

  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _universityController = TextEditingController();
  final _majorController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Selections
  String? _selectedYear;
  final List<String> _selectedSkills = [];
  final List<String> _selectedInterests = [];

  final List<String> _availableSkills = [
    'Python',
    'Java',
    'JavaScript',
    'React',
    'Flutter',
    'Node.js',
    'SQL',
    'MongoDB',
    'Git',
    'Figma',
    'Adobe XD',
    'UI/UX Design',
    'Marketing',
    'Data Analysis',
    'Machine Learning',
  ];

  final List<String> _availableInterests = [
    'Software Development',
    'Data Science',
    'UI/UX Design',
    'Marketing',
    'Business',
    'Cybersecurity',
    'Mobile Development',
    'Web Development',
    'AI/ML',
    'Cloud Computing',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _universityController.dispose();
    _majorController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      if (_validateCurrentPage()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _handleRegister();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        if (_fullNameController.text.isEmpty ||
            _emailController.text.isEmpty ||
            !_emailController.text.contains('@')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill all required fields')),
          );
          return false;
        }
        return true;
      case 1:
        if (_universityController.text.isEmpty ||
            _majorController.text.isEmpty ||
            _selectedYear == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please complete your academic info')),
          );
          return false;
        }
        return true;
      case 2:
        if (_passwordController.text.isEmpty ||
            _passwordController.text.length < 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Password must be at least 6 characters')),
          );
          return false;
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwords do not match')),
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  // Future<void> _handleRegister() async {
  //   if (!_formKey.currentState!.validate()) return;

  //   setState(() => _isLoading = true);

  //   final userData = {
  //     'name': _fullNameController.text,
  //     'email': _emailController.text,
  //     'university': _universityController.text,
  //     'major': _majorController.text,
  //     'year': _selectedYear,
  //     'skills': _selectedSkills,
  //     'interests': _selectedInterests,
  //   };

  //   final authProvider = Provider.of<AuthProvider>(context, listen: false);
  //   final success = await authProvider.register(userData, UserType.student);

  //   setState(() => _isLoading = false);

  //   if (success && mounted) {
  //     context.go(AppRoutes.studentHome);
  //   }
  // }

  Future<void> _handleRegister() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  final userData = {
    'name': _fullNameController.text,
    'email': _emailController.text,
    'university': _universityController.text,
    'major': _majorController.text,
    'year': _selectedYear,
    'skills': _selectedSkills,
    'interests': _selectedInterests,
  };

  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final success = await authProvider.register(userData, UserType.student);

  setState(() => _isLoading = false);

  if (success && mounted) {
    context.go(AppRoutes.studentHome);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentPage > 0) {
              _previousPage();
            } else {
              context.pop();
            }
          },
        ),
        title: Text('Sign Up (${_currentPage + 1}/3)'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  children: [
                    _buildPersonalInfoPage(),
                    _buildAcademicInfoPage(),
                    _buildSkillsAndPasswordPage(),
                  ],
                ),
              ),

              // Bottom buttons
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: index <= _currentPage
                    ? AppColors.primaryPurple
                    : AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Let\'s get you hired!',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your profile to start matching with top companies and internships.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Full Name
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'University Email',
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'example@university.edu',
            ),
          ),
          const SizedBox(height: 24),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentBlue.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.accentBlue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Use your university email to unlock exclusive opportunities',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.accentBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic Information',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 8),
          Text(
            'Help us match you with the right opportunities',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Current University
          TextFormField(
            controller: _universityController,
            decoration: const InputDecoration(
              labelText: 'Current University',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          // Major
          TextFormField(
            controller: _majorController,
            decoration: const InputDecoration(
              labelText: 'Major / Field of Study',
              prefixIcon: Icon(Icons.book_outlined),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          // Year
          DropdownButtonFormField<String>(
            value: _selectedYear,
            decoration: const InputDecoration(
              labelText: 'Current Year',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            items: ['Freshman', 'Sophomore', 'Junior', 'Senior', 'Graduate']
                .map((year) => DropdownMenuItem(
                      value: year,
                      child: Text(year),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() => _selectedYear = value);
            },
          ),
          const SizedBox(height: 24),

          // Interests
          Text(
            'Areas of Interest',
            style: AppTextStyles.subtitle1,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableInterests.map((interest) {
              final isSelected = _selectedInterests.contains(interest);
              return FilterChip(
                label: Text(interest),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedInterests.add(interest);
                    } else {
                      _selectedInterests.remove(interest);
                    }
                  });
                },
                backgroundColor: AppColors.surfaceGray,
                selectedColor: AppColors.primaryPurpleLight,
                checkmarkColor: Colors.white,
                labelStyle: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsAndPasswordPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Almost there!',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your skills and create a secure password',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Skills
          Text(
            'Top Skills',
            style: AppTextStyles.subtitle1,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableSkills.map((skill) {
              final isSelected = _selectedSkills.contains(skill);
              return FilterChip(
                label: Text(skill),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected && _selectedSkills.length < 10) {
                      _selectedSkills.add(skill);
                    } else if (!selected) {
                      _selectedSkills.remove(skill);
                    }
                  });
                },
                backgroundColor: AppColors.surfaceGray,
                selectedColor: AppColors.accentBlue,
                checkmarkColor: Colors.white,
                labelStyle: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Confirm Password
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentPage > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousPage,
                  child: const Text('Back'),
                ),
              ),
            if (_currentPage > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentPage > 0 ? 1 : 1,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _nextPage,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_currentPage < 2 ? 'Continue' : 'Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}