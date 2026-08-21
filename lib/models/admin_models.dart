import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';

enum AdminSection {
  institutions('Instituições'),
  professionals('Profissionais'),
  localNetwork('Rede local'),
  users('Usuários'),
  parameters('Parâmetros');

  const AdminSection(this.label);
  final String label;
}

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;
String? _nullableText(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? null : text;
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.schoolRole,
    this.professionalId,
    this.createdAt,
    this.updatedAt,
    this.lastAccessAt,
    this.createdBy,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String name;
  final String email;
  final UserRole role;
  final SchoolRole? schoolRole;
  final bool active;
  final String? professionalId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastAccessAt;
  final String? createdBy;

  factory AdminUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final fullName = _nullableText(data['name']) ?? '';
    final explicitFirst = _nullableText(data['firstName']);
    final explicitLast = _nullableText(data['lastName']);
    final parts =
        fullName.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final role = UserRole.fromValue(data['role'] as String?) ?? UserRole.family;
    return AdminUser(
      id: doc.id,
      firstName: explicitFirst ?? (parts.isEmpty ? '' : parts.first),
      lastName:
          explicitLast ?? (parts.length < 2 ? '' : parts.skip(1).join(' ')),
      name: fullName.isNotEmpty
          ? fullName
          : [explicitFirst, explicitLast].whereType<String>().join(' '),
      email: (_nullableText(data['email']) ?? '').toLowerCase(),
      role: role,
      schoolRole: role == UserRole.school
          ? SchoolRole.fromValue(data['schoolRole'] as String?) ??
              SchoolRole.teacher
          : null,
      active: data['active'] != false,
      professionalId: _nullableText(data['professionalId']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      lastAccessAt: _date(data['lastAccessAt']),
      createdBy: _nullableText(data['createdBy']),
    );
  }

  String get accessLabel => role == UserRole.school
      ? 'Escola • ${(schoolRole ?? SchoolRole.teacher).label}'
      : role.label;
}

class UserFormData {
  const UserFormData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.active,
    this.schoolRole,
    this.professionalId,
  });

  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  final SchoolRole? schoolRole;
  final bool active;
  final String? professionalId;

  String get normalizedEmail => email.trim().toLowerCase();
  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();

  Map<String, Object?> toCallableMap({String? uid}) => {
        if (uid != null) 'uid': uid,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': normalizedEmail,
        'role': role.value,
        'schoolRole': role == UserRole.school
            ? (schoolRole ?? SchoolRole.teacher).value
            : null,
        'active': active,
        'professionalId': professionalId,
      };
}

class Address {
  const Address({
    required this.street,
    required this.number,
    required this.district,
    required this.city,
    required this.state,
    required this.zipCode,
    this.complement,
  });

  final String street;
  final String number;
  final String? complement;
  final String district;
  final String city;
  final String state;
  final String zipCode;

  factory Address.fromMap(Object? raw) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return Address(
      street: _nullableText(map['street']) ?? '',
      number: _nullableText(map['number']) ?? '',
      complement: _nullableText(map['complement']),
      district: _nullableText(map['district']) ?? '',
      city: _nullableText(map['city']) ?? '',
      state: _nullableText(map['state']) ?? '',
      zipCode: _nullableText(map['zipCode']) ?? '',
    );
  }

  Map<String, Object?> toMap() => {
        'street': street.trim(),
        'number': number.trim(),
        'complement': _nullableText(complement),
        'district': district.trim(),
        'city': city.trim(),
        'state': state.trim().toUpperCase(),
        'zipCode': zipCode.trim(),
      };

  String get formatted => [
        [street, number].where((e) => e.isNotEmpty).join(', '),
        district,
        [city, state].where((e) => e.isNotEmpty).join(' - '),
      ].where((e) => e.isNotEmpty).join(' • ');
}

class Institution {
  const Institution({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.active,
    this.cnpj,
    this.email,
    this.phone,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String name;
  final String type;
  final String? cnpj;
  final String? email;
  final String? phone;
  final Address address;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory Institution.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Institution(
      id: doc.id,
      name: _nullableText(data['name']) ?? '',
      type: _nullableText(data['type']) ?? '',
      cnpj: _nullableText(data['cnpj']),
      email: _nullableText(data['email']),
      phone: _nullableText(data['phone']),
      address: Address.fromMap(data['address']),
      active: data['active'] != false,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      createdBy: _nullableText(data['createdBy']),
    );
  }

  Map<String, Object?> toMap() => {
        'name': name.trim(),
        'type': type.trim(),
        'cnpj': _nullableText(cnpj),
        'email': _nullableText(email)?.toLowerCase(),
        'phone': _nullableText(phone),
        'address': address.toMap(),
        'active': active,
      };
}

class Professional {
  const Professional({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.institutionIds,
    required this.active,
    this.email,
    this.phone,
    this.specialty,
    this.registrationNumber,
    this.userId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String name;
  final String? email;
  final String? phone;
  final String? specialty;
  final String? registrationNumber;
  final String? userId;
  final List<String> institutionIds;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory Professional.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final name = _nullableText(data['name']) ?? '';
    final parts =
        name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return Professional(
      id: doc.id,
      firstName: _nullableText(data['firstName']) ??
          (parts.isEmpty ? '' : parts.first),
      lastName: _nullableText(data['lastName']) ??
          (parts.length < 2 ? '' : parts.skip(1).join(' ')),
      name: name,
      email: _nullableText(data['email']),
      phone: _nullableText(data['phone']),
      specialty: _nullableText(data['specialty']),
      registrationNumber: _nullableText(data['registrationNumber']),
      userId: _nullableText(data['userId']),
      institutionIds: List<String>.unmodifiable(
        (data['institutionIds'] as List? ?? const []).whereType<String>(),
      ),
      active: data['active'] != false,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      createdBy: _nullableText(data['createdBy']),
    );
  }

  Map<String, Object?> toMap() => {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'name': '${firstName.trim()} ${lastName.trim()}'.trim(),
        'email': _nullableText(email)?.toLowerCase(),
        'phone': _nullableText(phone),
        'specialty': _nullableText(specialty),
        'registrationNumber': _nullableText(registrationNumber),
        'userId': _nullableText(userId),
        'institutionIds': institutionIds,
        'active': active,
      };
}

class LocalNetwork {
  const LocalNetwork({
    required this.id,
    required this.name,
    required this.institutionIds,
    required this.active,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String name;
  final String? description;
  final List<String> institutionIds;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory LocalNetwork.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return LocalNetwork(
      id: doc.id,
      name: _nullableText(data['name']) ?? '',
      description: _nullableText(data['description']),
      institutionIds: List<String>.unmodifiable(
        (data['institutionIds'] as List? ?? const []).whereType<String>(),
      ),
      active: data['active'] != false,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      createdBy: _nullableText(data['createdBy']),
    );
  }

  Map<String, Object?> toMap() => {
        'name': name.trim(),
        'description': _nullableText(description),
        'institutionIds': institutionIds,
        'active': active,
      };
}

class AdminParameter {
  const AdminParameter({
    required this.id,
    required this.title,
    required this.items,
    required this.active,
  });

  final String id;
  final String title;
  final List<String> items;
  final bool active;

  factory AdminParameter.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminParameter(
      id: doc.id,
      title: _nullableText(data['title']) ?? '',
      items: List<String>.unmodifiable(
        (data['items'] as List? ?? const []).whereType<String>(),
      ),
      active: data['active'] != false,
    );
  }
}
