import 'package:flutter/material.dart';
import '../../data/models/vacancy_model.dart';

class StudentProvider extends ChangeNotifier {
  List<VacancyModel> _vacancies = [];
  List<VacancyModel> _likedVacancies = [];
  int _currentIndex = 0;
  int _dailySwipes = 0;
  final int _maxDailySwipes = 10; // Límite para usuarios gratuitos

  List<VacancyModel> get vacancies => _vacancies;
  List<VacancyModel> get likedVacancies => _likedVacancies;
  int get currentIndex => _currentIndex;
  int get dailySwipes => _dailySwipes;
  int get maxDailySwipes => _maxDailySwipes;
  bool get hasReachedLimit => _dailySwipes >= _maxDailySwipes;
  int get remainingSwipes => _maxDailySwipes - _dailySwipes;

  VacancyModel? get currentVacancy {
    if (_currentIndex < _vacancies.length) {
      return _vacancies[_currentIndex];
    }
    return null;
  }

  void loadVacancies() {
    // Mock data
    _vacancies = _getMockVacancies();
    notifyListeners();
  }

  void likeVacancy(VacancyModel vacancy) {
    if (hasReachedLimit) return;

    _likedVacancies.add(vacancy);
    _dailySwipes++;
    _currentIndex++;
    notifyListeners();
  }

  void dislikeVacancy() {
    if (hasReachedLimit) return;

    _dailySwipes++;
    _currentIndex++;
    notifyListeners();
  }

  void resetDailySwipes() {
    _dailySwipes = 0;
    notifyListeners();
  }

  List<VacancyModel> _getMockVacancies() {
    return [
      VacancyModel(
        id: '1',
        companyName: 'Spotify Inc.',
        position: 'UX Design Intern',
        location: 'New York, NY (Hybrid)',
        salary: '\$30 - \$40 /hr',
        type: 'Summer 2024 • Remote • Entry Level',
        description: 'Join our Design Systems team to help build beautiful user experiences...',
        requirements: ['Figma', 'Adobe XD', 'User Research'],
        companyLogo: '🎵',
      ),
      VacancyModel(
        id: '2',
        companyName: 'Google',
        position: 'Software Engineer Intern',
        location: 'Mountain View, CA',
        salary: '\$50 - \$60 /hr',
        type: 'Summer 2024 • On-site • Entry Level',
        description: 'Work on cutting-edge technologies with world-class engineers...',
        requirements: ['Python', 'Java', 'Algorithms'],
        companyLogo: '🔍',
      ),
      VacancyModel(
        id: '3',
        companyName: 'Tesla',
        position: 'Mechanical Engineering Intern',
        location: 'Fremont, CA',
        salary: '\$35 - \$45 /hr',
        type: 'Fall 2024 • On-site • Entry Level',
        description: 'Help design and test next-generation electric vehicles...',
        requirements: ['CAD', 'SolidWorks', 'Manufacturing'],
        companyLogo: '⚡',
      ),
      VacancyModel(
        id: '4',
        companyName: 'Microsoft',
        position: 'Data Science Intern',
        location: 'Redmond, WA (Hybrid)',
        salary: '\$45 - \$55 /hr',
        type: 'Summer 2024 • Hybrid • Entry Level',
        description: 'Apply machine learning to solve real-world problems...',
        requirements: ['Python', 'SQL', 'Machine Learning'],
        companyLogo: '💻',
      ),
      VacancyModel(
        id: '5',
        companyName: 'Amazon',
        position: 'Marketing Intern',
        location: 'Seattle, WA',
        salary: '\$28 - \$38 /hr',
        type: 'Summer 2024 • On-site • Entry Level',
        description: 'Create and execute marketing campaigns for Amazon Prime...',
        requirements: ['Marketing', 'Analytics', 'Communication'],
        companyLogo: '📦',
      ),
    ];
  }
}