// lib/core/constants/app_routes.dart

class AppRoutes {
  // Auth
  static const splash          = '/';
  static const welcome         = '/welcome';
  static const login           = '/login';
  static const registerStudent = '/register-student';
  static const registerCompany = '/register-company';

  // Estudiante
  static const studentHome         = '/student/home';
  static const studentProfile      = '/student/profile';
  static const editProfile         = '/student/edit-profile';
  static const studentApplications = '/student/applications';
  static const studentActivity     = '/student/activity';
  static const aiFeedback          = '/student/ai-feedback';
  static const studentSettings     = '/student/settings';   // ← NUEVO
  static const studentPremium      = '/student/premium';    // ← NUEVO

  // Empresa
  static const companyHome        = '/company/home';
  static const companyVacancies   = '/company/vacancies';
  static const companyCreateVacancy = '/company/vacancies/create';
  static const companyEditProfile = '/company/edit-profile'; // ← NUEVO separado
  static const companyCandidates  = '/company/candidates';
  static const companyProfile     = '/company/profile';
  static const companySettings    = '/company/settings';    // ← NUEVO
  static const companyPremium     = '/company/premium';     // ← NUEVO

  // Ruta dinámica editar vacante
  static const companyEditVacancy = '/company/vacancies/edit';
  static String editVacancyPath(int id) => '/company/vacancies/edit/$id';

  // Común
  static const settings = '/settings';
  static const premium  = '/premium';
}