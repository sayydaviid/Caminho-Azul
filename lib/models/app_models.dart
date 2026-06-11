class DashboardStat {
  const DashboardStat(this.label, this.value, this.tone);

  final String label;
  final int value;
  final String tone;
}

class CaseRecord {
  const CaseRecord({
    required this.name,
    required this.school,
    required this.stage,
    required this.status,
    required this.updatedAt,
  });

  final String name;
  final String school;
  final String stage;
  final String status;
  final String updatedAt;
}

class NoticeRecord {
  const NoticeRecord(this.text, this.date, this.tone);

  final String text;
  final String date;
  final String tone;
}

class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.date,
    required this.user,
    required this.origin,
    required this.size,
    required this.validated,
  });

  final int id;
  final String name;
  final String type;
  final String date;
  final String user;
  final String origin;
  final String size;
  final bool validated;

  bool matches(String category, String query) {
    final categoryMatches = category == 'Todos' || type == category;
    return categoryMatches && name.toLowerCase().contains(query.toLowerCase());
  }
}

class ReferralRecord {
  const ReferralRecord({
    required this.name,
    required this.school,
    required this.date,
    required this.reason,
    required this.status,
    required this.priority,
  });

  final String name;
  final String school;
  final String date;
  final String reason;
  final String status;
  final String priority;
}

class TimelineRecord {
  const TimelineRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.owner,
    required this.summary,
    required this.status,
    required this.documents,
  });

  final int id;
  final String title;
  final String date;
  final String time;
  final String owner;
  final String summary;
  final String status;
  final List<String> documents;
}

class InstitutionRecord {
  const InstitutionRecord({
    required this.name,
    required this.type,
    required this.address,
    required this.contact,
    required this.owner,
    required this.active,
  });

  final String name;
  final String type;
  final String address;
  final String contact;
  final String owner;
  final bool active;
}

class ProfessionalRecord {
  const ProfessionalRecord({
    required this.name,
    required this.role,
    required this.area,
    required this.institution,
    required this.profile,
    required this.active,
  });

  final String name;
  final String role;
  final String area;
  final String institution;
  final String profile;
  final bool active;
}
