import 'package:caminho_azul/models/case_models.dart';
import 'package:caminho_azul/models/referral_models.dart';
import 'package:caminho_azul/repositories/referral_repository.dart';
import 'package:caminho_azul/services/auth_service.dart';

/// Repositório de encaminhamentos vazio para testes de tela.
class EmptyReferralRepository implements ReferralRepository {
  @override
  Stream<List<Referral>> watchSchoolCaseReferrals(String caseId, String schoolId) =>
      Stream.value(const []);
  @override
  Stream<List<Referral>> watchUbsReferrals(String ubsId, {int limit = 30}) => Stream.value(const []);
  @override
  Stream<List<Referral>> watchPsychologistReferrals(String uid, {int limit = 30}) =>
      Stream.value(const []);
  @override
  Stream<Referral?> watchReferral(String referralId) => Stream.value(null);
  @override
  Future<ReferralDetails?> getDetails(String referralId) async => null;
  @override
  Stream<List<ReferralNote>> watchNotes(String referralId, String audience) =>
      Stream.value(const []);
  @override
  Stream<List<HealthReturn>> watchReturnsForReferral(String referralId,
          {String? audience, String? caseId}) =>
      Stream.value(const []);
  @override
  Stream<List<TimelineEvent>> watchReferralTimeline(String caseId, String referralId) =>
      Stream.value(const []);
  @override
  Future<List<InstitutionOption>> activeUbs() async => const [];
  @override
  Future<List<StaffOption>> psychologistsOf(String ubsId) async => const [];
  @override
  Future<Map<String, String>> institutionNames(Iterable<String> ids) async => {};
  @override
  Future<void> requestSchoolComplement(AppUser director, StudentCase value) async {}
  @override
  Future<void> approve(AppUser director, StudentCase value) async {}
  @override
  Future<String> send(AppUser director, StudentCase value,
          {required String ubsId, required String reason, required String summary}) async =>
      'r1';
  @override
  Future<void> conclude(AppUser director, StudentCase value) async {}
  @override
  Future<void> forwardComplementToTeacher(AppUser director, StudentCase value) async {}
  @override
  Future<void> answerUbsComplement(
      AppUser director, StudentCase value, Referral referral, String text) async {}
  @override
  Future<void> receive(AppUser ubsDirector, Referral referral) async {}
  @override
  Future<void> assign(AppUser ubsDirector, Referral referral, StaffOption psychologist,
      {required bool caseNeedsFollowUp}) async {}
  @override
  Future<void> requestUbsComplement(AppUser ubsDirector, Referral referral, String text) async {}
  @override
  Future<void> returnReferral(AppUser ubsDirector, Referral referral, String text) async {}
  @override
  Future<void> refuse(AppUser ubsDirector, Referral referral, String text) async {}
  @override
  Future<void> finalize(AppUser ubsDirector, Referral referral) async {}
  @override
  Future<void> startAttendance(AppUser psychologist, Referral referral) async {}
  @override
  Future<void> addProgressNote(AppUser psychologist, Referral referral, String text) async {}
  @override
  Future<void> registerReturn(AppUser psychologist, Referral referral,
      {required String content, required List<String> audience}) async {}
}
