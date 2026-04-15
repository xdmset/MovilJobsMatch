import 'package:flutter/material.dart';

class VacancyProvider extends ChangeNotifier {
  // Por ahora vacío, lo usaremos más adelante para empresas
  final List<Map<String, dynamic>> _companyVacancies = [];

  List<Map<String, dynamic>> get companyVacancies => _companyVacancies;
}