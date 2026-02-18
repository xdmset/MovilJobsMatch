import 'package:flutter/material.dart';

class VacanciesListScreen extends StatelessWidget {
  const VacanciesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Vacancies')),
      body: const Center(child: Text('Vacancies List - Coming Soon')),
    );
  }
}