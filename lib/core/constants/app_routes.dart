// lib/core/constants/app_routes.dart

class AppRoutes {
  // Auth
  static const String splash          = '/';
  static const String welcome         = '/welcome';
  static const String login           = '/login';
  static const String registerStudent = '/register-student';
  static const String registerCompany = '/register-company';

  // Student
  static const String studentHome         = '/student/home';
  static const String studentProfile      = '/student/profile';
  static const String editProfile         = '/student/edit-profile';
  static const String studentApplications = '/student/applications';
  static const String studentActivity     = '/student/activity';
  static const String aiFeedback          = '/student/ai-feedback';

  // Company
  static const String companyHome         = '/company/home';
  static const String companyVacancies    = '/company/vacancies';
  static const String companyCreateVacancy= '/company/vacancies/create';
  static const String companyEditVacancy  = '/company/vacancies/edit'; // + /:id
  static const String companyCandidates   = '/company/candidates';
  static const String companyProfile      = '/company/profile';

  // Common
  static const String settings = '/settings';
  static const String premium  = '/premium';

  // Helper para navegar a editar vacante con ID
  static String editVacancyPath(int id) => '/company/vacancies/edit/$id';
}