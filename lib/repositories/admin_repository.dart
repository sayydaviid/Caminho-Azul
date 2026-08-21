import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_models.dart';
import '../services/auth_service.dart';

class AdminRepositoryException implements Exception {
  const AdminRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class AdminRepository {
  Stream<List<Institution>> watchInstitutions();
  Stream<List<Professional>> watchProfessionals();
  Stream<List<LocalNetwork>> watchLocalNetworks();
  Stream<List<AdminUser>> watchUsers();
  Stream<List<AdminParameter>> watchParameters();
  Future<List<Institution>> getActiveInstitutions();
  Future<List<Institution>> getInstitutions();
  Future<List<Professional>> getProfessionals();
  Future<List<AdminUser>> getUsers();
  Future<void> createUserProfile(
    String uid,
    UserFormData value, {
    required String actorUid,
  });
  Future<void> updateUser(
    AdminUser user,
    UserFormData value, {
    required String actorUid,
  });
  Future<void> deleteUser(
    AdminUser user, {
    required String actorUid,
  });
  Future<void> saveInstitution(Institution value, {required String actorUid});
  Future<void> saveProfessional(Professional value, {required String actorUid});
  Future<void> saveLocalNetwork(LocalNetwork value, {required String actorUid});
  Future<void> saveParameter(AdminParameter value, {required String actorUid});
}

class FirebaseAdminRepository implements AdminRepository {
  FirebaseAdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Institution>> watchInstitutions() => _firestore
      .collection('institutions')
      .snapshots()
      .map((event) => _sorted(event.docs.map(Institution.fromFirestore)));

  @override
  Stream<List<Professional>> watchProfessionals() => _firestore
      .collection('professionals')
      .snapshots()
      .map((event) => _sorted(event.docs.map(Professional.fromFirestore)));

  @override
  Stream<List<LocalNetwork>> watchLocalNetworks() => _firestore
      .collection('localNetworks')
      .snapshots()
      .map((event) => _sorted(event.docs.map(LocalNetwork.fromFirestore)));

  @override
  Stream<List<AdminUser>> watchUsers() => _firestore
      .collection('users')
      .snapshots()
      .map((event) => _sorted(event.docs.map(AdminUser.fromFirestore)));

  @override
  Stream<List<AdminParameter>> watchParameters() => _firestore
      .collection('adminParameters')
      .snapshots()
      .map((event) => _sorted(event.docs.map(AdminParameter.fromFirestore)));

  List<T> _sorted<T>(Iterable<T> values) {
    final list = values.toList();
    list.sort((a, b) {
      final first = switch (a) {
        Institution(:final name) => name,
        Professional(:final name) => name,
        LocalNetwork(:final name) => name,
        AdminUser(:final name) => name,
        AdminParameter(:final title) => title,
        _ => '',
      };
      final second = switch (b) {
        Institution(:final name) => name,
        Professional(:final name) => name,
        LocalNetwork(:final name) => name,
        AdminUser(:final name) => name,
        AdminParameter(:final title) => title,
        _ => '',
      };
      return first.toLowerCase().compareTo(second.toLowerCase());
    });
    return List.unmodifiable(list);
  }

  @override
  Future<List<Institution>> getActiveInstitutions() async {
    final snapshot = await _firestore
        .collection('institutions')
        .where('active', isEqualTo: true)
        .get();
    return _sorted(snapshot.docs.map(Institution.fromFirestore));
  }

  @override
  Future<List<Institution>> getInstitutions() async {
    final snapshot = await _firestore.collection('institutions').get();
    return _sorted(snapshot.docs.map(Institution.fromFirestore));
  }

  @override
  Future<List<Professional>> getProfessionals() async {
    final snapshot = await _firestore.collection('professionals').get();
    return _sorted(snapshot.docs.map(Professional.fromFirestore));
  }

  @override
  Future<List<AdminUser>> getUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return _sorted(snapshot.docs.map(AdminUser.fromFirestore));
  }

  @override
  Future<void> createUserProfile(
    String uid,
    UserFormData value, {
    required String actorUid,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final existing = await userRef.get();
    if (existing.exists) {
      throw const AdminRepositoryException('Este usuário já está cadastrado.');
    }
    await _validateUserProfessional(value.professionalId, uid);

    final after = <String, Object?>{
      'firstName': value.firstName.trim(),
      'lastName': value.lastName.trim(),
      'name': value.fullName,
      'email': value.normalizedEmail,
      'role': value.role.value,
      'schoolRole': value.role == UserRole.school
          ? (value.schoolRole ?? SchoolRole.teacher).value
          : null,
      'active': value.active,
      'professionalId': value.professionalId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': actorUid,
      'lastAccessAt': null,
    };
    final batch = _firestore.batch()..set(userRef, after);
    if (value.professionalId != null) {
      batch.update(
        _firestore.collection('professionals').doc(value.professionalId),
        {
          'userId': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    _addAudit(
      batch,
      action: 'user.create',
      actorUid: actorUid,
      targetType: 'user',
      targetId: uid,
      before: null,
      after: after,
    );
    await batch.commit();
  }

  @override
  Future<void> updateUser(
    AdminUser user,
    UserFormData value, {
    required String actorUid,
  }) async {
    if (user.id == actorUid &&
        (!value.active || value.role != UserRole.administration)) {
      throw const AdminRepositoryException(
        'Você não pode desativar a própria conta nem remover sua role administrativa.',
      );
    }
    if (value.normalizedEmail != user.email.trim().toLowerCase()) {
      throw const AdminRepositoryException(
        'O e-mail de uma conta existente não pode ser alterado sem um servidor administrativo.',
      );
    }
    await _validateUserProfessional(value.professionalId, user.id);

    final userRef = _firestore.collection('users').doc(user.id);
    final before = await userRef.get();
    if (!before.exists) {
      throw const AdminRepositoryException('Usuário não encontrado.');
    }
    final oldProfessionalId = before.data()?['professionalId'] as String?;
    final after = <String, Object?>{
      'firstName': value.firstName.trim(),
      'lastName': value.lastName.trim(),
      'name': value.fullName,
      'role': value.role.value,
      'schoolRole': value.role == UserRole.school
          ? (value.schoolRole ?? SchoolRole.teacher).value
          : null,
      'active': value.active,
      'professionalId': value.professionalId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = _firestore.batch()..update(userRef, after);
    if (oldProfessionalId != null &&
        oldProfessionalId != value.professionalId) {
      batch.update(
          _firestore.collection('professionals').doc(oldProfessionalId), {
        'userId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    if (value.professionalId != null) {
      batch.update(
        _firestore.collection('professionals').doc(value.professionalId),
        {
          'userId': user.id,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    _addAudit(
      batch,
      action: 'user.update',
      actorUid: actorUid,
      targetType: 'user',
      targetId: user.id,
      before: before.data(),
      after: after,
    );
    if (user.role != value.role || user.schoolRole != value.schoolRole) {
      _addAudit(
        batch,
        action: 'user.role.update',
        actorUid: actorUid,
        targetType: 'user',
        targetId: user.id,
        before: {
          'role': user.role.value,
          'schoolRole': user.schoolRole?.value,
        },
        after: {
          'role': value.role.value,
          'schoolRole': value.schoolRole?.value,
        },
      );
    }
    if (user.active != value.active) {
      _addAudit(
        batch,
        action: value.active ? 'user.activate' : 'user.deactivate',
        actorUid: actorUid,
        targetType: 'user',
        targetId: user.id,
        before: {'active': user.active},
        after: {'active': value.active},
      );
    }
    if (user.professionalId != value.professionalId) {
      _addAudit(
        batch,
        action: 'association.update',
        actorUid: actorUid,
        targetType: 'user',
        targetId: user.id,
        before: {'professionalId': user.professionalId},
        after: {'professionalId': value.professionalId},
      );
    }
    await batch.commit();
  }

  @override
  Future<void> deleteUser(
    AdminUser user, {
    required String actorUid,
  }) async {
    if (user.id == actorUid) {
      throw const AdminRepositoryException(
        'Você não pode excluir a própria conta administrativa.',
      );
    }

    final userRef = _firestore.collection('users').doc(user.id);
    final before = await userRef.get();
    if (!before.exists) {
      throw const AdminRepositoryException('Usuário não encontrado.');
    }

    final professionalId = before.data()?['professionalId'] as String?;
    final professionals = _firestore.collection('professionals');
    final linkedProfessionals =
        await professionals.where('userId', isEqualTo: user.id).get();
    final batch = _firestore.batch()..delete(userRef);
    final unlinkedProfessionalIds = <String>{};
    for (final professional in linkedProfessionals.docs) {
      unlinkedProfessionalIds.add(professional.id);
      batch.update(professional.reference, {
        'userId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _addAudit(
        batch,
        action: 'association.delete',
        actorUid: actorUid,
        targetType: 'professional',
        targetId: professional.id,
        before: {'userId': user.id},
        after: {'userId': null},
      );
    }
    if (professionalId != null &&
        !unlinkedProfessionalIds.contains(professionalId)) {
      final professionalRef = professionals.doc(professionalId);
      final professional = await professionalRef.get();
      if (professional.exists && professional.data()?['userId'] == user.id) {
        batch.update(professionalRef, {
          'userId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _addAudit(
          batch,
          action: 'association.delete',
          actorUid: actorUid,
          targetType: 'professional',
          targetId: professionalId,
          before: {'userId': user.id},
          after: {'userId': null},
        );
      }
    }
    _addAudit(
      batch,
      action: 'user.delete',
      actorUid: actorUid,
      targetType: 'user',
      targetId: user.id,
      before: before.data(),
      after: null,
    );
    await batch.commit();
  }

  @override
  Future<void> saveInstitution(
    Institution value, {
    required String actorUid,
  }) async {
    final collection = _firestore.collection('institutions');
    final ref = value.id.isEmpty ? collection.doc() : collection.doc(value.id);
    final before = await ref.get();
    final data = <String, Object?>{
      ...value.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!before.exists) ...{
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': actorUid,
      },
    };
    final batch = _firestore.batch()..set(ref, data, SetOptions(merge: true));
    _addAudit(
      batch,
      action: before.exists ? 'institution.update' : 'institution.create',
      actorUid: actorUid,
      targetType: 'institution',
      targetId: ref.id,
      before: before.data(),
      after: value.toMap(),
    );
    await batch.commit();
  }

  @override
  Future<void> saveProfessional(
    Professional value, {
    required String actorUid,
  }) async {
    await _ensureActiveInstitutions(value.institutionIds);
    final professionals = _firestore.collection('professionals');
    final ref =
        value.id.isEmpty ? professionals.doc() : professionals.doc(value.id);
    final before = await ref.get();
    final previousUserId = before.data()?['userId'] as String?;
    final nextUserId = value.userId;

    if (nextUserId == null) {
      throw const AdminRepositoryException(
        'Selecione o usuário vinculado ao profissional.',
      );
    }
    final duplicates =
        await professionals.where('userId', isEqualTo: nextUserId).get();
    if (duplicates.docs.any((doc) => doc.id != ref.id)) {
      throw const AdminRepositoryException(
        'Este usuário já está vinculado a outro profissional.',
      );
    }
    final user = await _firestore.collection('users').doc(nextUserId).get();
    final userData = user.data();
    if (!user.exists || userData == null || userData['active'] != true) {
      throw const AdminRepositoryException(
        'Selecione um usuário existente e ativo.',
      );
    }
    final linkedProfessional = userData['professionalId'] as String?;
    if (linkedProfessional != null && linkedProfessional != ref.id) {
      throw const AdminRepositoryException(
        'Este usuário já está vinculado a outro profissional.',
      );
    }

    String text(Object? field) => field is String ? field.trim() : '';
    final storedName = text(userData['name']);
    final nameParts = storedName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final firstName = text(userData['firstName']).isNotEmpty
        ? text(userData['firstName'])
        : nameParts.firstOrNull ?? '';
    final lastName = text(userData['lastName']).isNotEmpty
        ? text(userData['lastName'])
        : nameParts.skip(1).join(' ');
    final fullName =
        storedName.isNotEmpty ? storedName : '$firstName $lastName'.trim();
    final email = text(userData['email']).toLowerCase();
    if (fullName.isEmpty || email.isEmpty) {
      throw const AdminRepositoryException(
        'O usuário selecionado possui nome ou e-mail incompleto.',
      );
    }
    final professionalData = <String, Object?>{
      ...value.toMap(),
      'firstName': firstName,
      'lastName': lastName,
      'name': fullName,
      'email': email,
      'userId': nextUserId,
    };

    final data = <String, Object?>{
      ...professionalData,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!before.exists) ...{
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': actorUid,
      },
    };
    final batch = _firestore.batch()..set(ref, data, SetOptions(merge: true));
    if (previousUserId != null && previousUserId != nextUserId) {
      batch.update(_firestore.collection('users').doc(previousUserId), {
        'professionalId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_firestore.collection('users').doc(nextUserId), {
      'professionalId': ref.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _addAudit(
      batch,
      action: before.exists ? 'professional.update' : 'professional.create',
      actorUid: actorUid,
      targetType: 'professional',
      targetId: ref.id,
      before: before.data(),
      after: professionalData,
    );
    await batch.commit();
  }

  @override
  Future<void> saveLocalNetwork(
    LocalNetwork value, {
    required String actorUid,
  }) async {
    await _ensureActiveInstitutions(value.institutionIds);
    final collection = _firestore.collection('localNetworks');
    final ref = value.id.isEmpty ? collection.doc() : collection.doc(value.id);
    final before = await ref.get();
    final data = <String, Object?>{
      ...value.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!before.exists) ...{
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': actorUid,
      },
    };
    final batch = _firestore.batch()..set(ref, data, SetOptions(merge: true));
    _addAudit(
      batch,
      action: before.exists ? 'localNetwork.update' : 'localNetwork.create',
      actorUid: actorUid,
      targetType: 'localNetwork',
      targetId: ref.id,
      before: before.data(),
      after: value.toMap(),
    );
    await batch.commit();
  }

  @override
  Future<void> saveParameter(
    AdminParameter value, {
    required String actorUid,
  }) async {
    final collection = _firestore.collection('adminParameters');
    final ref = value.id.isEmpty ? collection.doc() : collection.doc(value.id);
    final before = await ref.get();
    final after = <String, Object?>{
      'title': value.title.trim(),
      'items': value.items,
      'active': value.active,
    };
    final batch = _firestore.batch()
      ..set(
          ref,
          {
            ...after,
            'updatedAt': FieldValue.serverTimestamp(),
            if (!before.exists) ...{
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': actorUid,
            },
          },
          SetOptions(merge: true));
    _addAudit(
      batch,
      action: before.exists ? 'parameter.update' : 'parameter.create',
      actorUid: actorUid,
      targetType: 'parameter',
      targetId: ref.id,
      before: before.data(),
      after: after,
    );
    await batch.commit();
  }

  Future<void> _ensureActiveInstitutions(List<String> ids) async {
    if (ids.isEmpty) return;
    final docs = await Future.wait(
      ids.map((id) => _firestore.collection('institutions').doc(id).get()),
    );
    if (docs.any((doc) => !doc.exists || doc.data()?['active'] != true)) {
      throw const AdminRepositoryException(
        'Uma das instituições selecionadas não está mais ativa.',
      );
    }
  }

  Future<void> _validateUserProfessional(
    String? professionalId,
    String uid,
  ) async {
    if (professionalId == null) return;
    final professional =
        await _firestore.collection('professionals').doc(professionalId).get();
    if (!professional.exists || professional.data()?['active'] != true) {
      throw const AdminRepositoryException(
        'Selecione um profissional existente e ativo.',
      );
    }
    final linkedUid = professional.data()?['userId'] as String?;
    if (linkedUid != null && linkedUid != uid) {
      throw const AdminRepositoryException(
        'Este profissional já está vinculado a outro usuário.',
      );
    }
  }

  void _addAudit(
    WriteBatch batch, {
    required String action,
    required String actorUid,
    required String targetType,
    required String targetId,
    required Map<String, dynamic>? before,
    required Map<String, Object?>? after,
  }) {
    final ref = _firestore.collection('adminAuditLogs').doc();
    batch.set(ref, {
      'action': action,
      'actorUid': actorUid,
      'targetType': targetType,
      'targetId': targetId,
      'before': before,
      'after': after,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
