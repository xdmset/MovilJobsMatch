class VacancyModel {
  final String id;
  final String companyName;
  final String position;
  final String location;
  final String salary;
  final String type;
  final String description;
  final List<String> requirements;
  final String companyLogo;

  VacancyModel({
    required this.id,
    required this.companyName,
    required this.position,
    required this.location,
    required this.salary,
    required this.type,
    required this.description,
    required this.requirements,
    required this.companyLogo,
  });

  factory VacancyModel.fromJson(Map<String, dynamic> json) {
    return VacancyModel(
      id: json['id'],
      companyName: json['companyName'],
      position: json['position'],
      location: json['location'],
      salary: json['salary'],
      type: json['type'],
      description: json['description'],
      requirements: List<String>.from(json['requirements']),
      companyLogo: json['companyLogo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyName': companyName,
      'position': position,
      'location': location,
      'salary': salary,
      'type': type,
      'description': description,
      'requirements': requirements,
      'companyLogo': companyLogo,
    };
  }
}