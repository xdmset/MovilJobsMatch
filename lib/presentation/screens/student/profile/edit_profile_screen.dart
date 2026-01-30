import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController(text: 'Alex Johnson');
  final _emailController =
      TextEditingController(text: 'alex.johnson@stanford.edu');
  final _phoneController = TextEditingController(text: '+1 (650) 555-0123');
  final _universityController =
      TextEditingController(text: 'Stanford University');
  final _majorController = TextEditingController(text: 'Computer Science');
  final _bioController = TextEditingController(
    text:
        'Passionate computer science student with a focus on mobile development and UI/UX design.',
  );
  final _linkedinController =
      TextEditingController(text: 'linkedin.com/in/alexjohnson');
  final _githubController = TextEditingController(text: 'github.com/alexj');
  final _portfolioController = TextEditingController(text: 'alexjohnson.dev');

  String _selectedYear = 'Junior';
  final List<String> _selectedSkills = [
    'Python',
    'Flutter',
    'React',
    'UI/UX Design'
  ];

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

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _universityController.dispose();
    _majorController.dispose();
    _bioController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _portfolioController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      // TODO: Save profile to backend
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile updated successfully!'),
            ],
          ),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              'Save',
              style: AppTextStyles.button.copyWith(
                color: AppColors.primaryPurple,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Picture
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.primaryPurpleLight,
                    child: Text(
                      'AJ',
                      style: AppTextStyles.h1.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.purpleGradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.cardBackground,
                          width: 3,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: () {
                          _showImagePickerOptions();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Personal Information Section
            _buildSectionHeader('Personal Information'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty || !value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio',
                prefixIcon: Icon(Icons.description_outlined),
                hintText: 'Tell companies about yourself...',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 500,
            ),

            const SizedBox(height: 32),

            // Academic Information Section
            _buildSectionHeader('Academic Information'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _universityController,
              decoration: const InputDecoration(
                labelText: 'University',
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _majorController,
              decoration: const InputDecoration(
                labelText: 'Major',
                prefixIcon: Icon(Icons.book_outlined),
              ),
            ),

            const SizedBox(height: 16),

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
                setState(() => _selectedYear = value!);
              },
            ),

            const SizedBox(height: 32),

            // Skills Section
            _buildSectionHeader('Skills'),
            const SizedBox(height: 16),

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
                      if (selected) {
                        _selectedSkills.add(skill);
                      } else {
                        _selectedSkills.remove(skill);
                      }
                    });
                  },
                  backgroundColor: AppColors.surfaceGray,
                  selectedColor: AppColors.primaryPurple,
                  checkmarkColor: Colors.white,
                  labelStyle: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Social Links Section
            _buildSectionHeader('Social Links'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _linkedinController,
              decoration: const InputDecoration(
                labelText: 'LinkedIn',
                prefixIcon: Icon(Icons.link),
                hintText: 'linkedin.com/in/yourprofile',
              ),
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _githubController,
              decoration: const InputDecoration(
                labelText: 'GitHub',
                prefixIcon: Icon(Icons.code),
                hintText: 'github.com/yourusername',
              ),
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _portfolioController,
              decoration: const InputDecoration(
                labelText: 'Portfolio Website',
                prefixIcon: Icon(Icons.language),
                hintText: 'yourportfolio.com',
              ),
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Save Changes'),
              ),
            ),
        const SizedBox(height: 16),
      ],
    ),
  ),
);
}
        Widget _buildSectionHeader(String title) {
        return Text(
        title,
        style: AppTextStyles.h4,
        );
        }
        void _showImagePickerOptions() {
        showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
        decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        Container(
        margin: const EdgeInsets.only(top: 12, bottom: 20),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(2),
        ),
        ),
        ListTile(
        leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
        Icons.camera_alt,
        color: AppColors.accentBlue,
        ),
        ),
        title: const Text('Take Photo'),
        onTap: () {
        Navigator.pop(context);
        // TODO: Open camera
        },
        ),
        ListTile(
        leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
        Icons.photo_library,
        color: AppColors.primaryPurple,
        ),
        ),
        title: const Text('Choose from Gallery'),
        onTap: () {
        Navigator.pop(context);
        // TODO: Open gallery
        },
        ),
        if (_fullNameController.text.isNotEmpty)
        ListTile(
        leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
        Icons.delete,
        color: AppColors.error,
        ),
        ),
        title: const Text(
        'Remove Photo',
        style: TextStyle(color: AppColors.error),
        ),
        onTap: () {
        Navigator.pop(context);
        // TODO: Remove photo
        },
        ),
        const SizedBox(height: 16),
        ],
        ),
        ),
        ),
        );
        }
        }
