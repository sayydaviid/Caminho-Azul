'use strict';

// Seed sintético — fase B (P0-02): casos, observações, registros pedagógicos,
// encaminhamento, devolutiva, linha do tempo e notificações da família, todos
// coerentes entre si e com as regras. Usa a Escola B / UBS B e estudantes
// próprios, para não interferir nos testes integrados (que usam a Escola A).
// Nenhum dado real: nomes e textos são fictícios.

const DEMO_FAMILY = {
  uid: 'seed-familia-demo', email: 'familia.demo@caminhoazul.test', first: 'Família',
  last: 'Demonstração Sintética', role: 'family', studentIds: ['seed-estudante-demo-1'],
};

const students = [
  { id: 'seed-estudante-demo-1', name: 'Estudante Demonstração Um', schoolInstitutionId: 'seed-escola-b',
    grade: '4º ano A', familyUid: DEMO_FAMILY.uid, createdBy: 'seed-diretor-escola-b' },
  { id: 'seed-estudante-demo-2', name: 'Estudante Demonstração Dois', schoolInstitutionId: 'seed-escola-b',
    grade: '1º ano C', familyUid: null, createdBy: 'seed-diretor-escola-b' },
];

const PEOPLE = {
  teacher: { uid: 'seed-professor-b', name: 'Professora Escola B Sintética', role: 'school/teacher' },
  director: { uid: 'seed-diretor-escola-b', name: 'Diretor Escola B Sintético', role: 'school/director' },
  ubs: { uid: 'seed-diretor-ubs-b', name: 'Diretora UBS B Sintética', role: 'health/ubs_director' },
  psychologist: { uid: 'seed-psicologo-b', name: 'Psicólogo UBS B Sintético', role: 'health/psychologist' },
};

// Eventos que notificam a família (mesma lista das regras e do app).
const NOTIFIABLE = new Set(['case.approved', 'referral.sent', 'referral.received', 'referral.assigned',
  'referral.transferred', 'referral.statusChanged', 'referral.complementRequested', 'referral.returned',
  'referral.refused', 'healthReturn.created', 'referral.finalized', 'case.concluded']);
const INTERNAL = new Set(['observation.created', 'pedagogicalRecord.created', 'case.teachersUpdated',
  'case.ubsComplementForwarded', 'case.ubsComplementClosed']);

/**
 * Documentos da fase B como [caminho, dados]. [at] converte minutos desde o
 * início da história em data (permite ordem cronológica determinística).
 */
function buildDomain(at) {
  const docs = [];
  const put = (path, value) => docs.push([path, value]);

  for (const { id, ...student } of students) {
    put(`students/${id}`, {
      ...student, active: true, updatedBy: student.createdBy, createdAt: at(0), updatedAt: at(0),
    });
  }

  // ---------------------------------------------------------- caso 1 (completo)
  const C1 = 'seed-caso-demo-1';
  const R1 = 'seed-enc-demo-1';
  const S1 = 'seed-estudante-demo-1';
  let minute = 10;
  const events = [];
  const event = (id, type, person, extra = {}) => {
    minute += 37;
    const value = {
      type, visibility: extra.visibility || (INTERNAL.has(type) ? 'interno' : 'familia'),
      audience: extra.audience || [], referralId: extra.referralId || null, refId: extra.refId || null,
      actorUid: person.uid, actorName: person.name, actorRole: person.role, createdAt: at(minute),
    };
    events.push([id, value]);
    put(`cases/${C1}/timelineEvents/${id}`, value);
    return value;
  };

  event('ev-d1-01', 'case.created', PEOPLE.teacher);
  put(`cases/${C1}/observations/obs-d1-1`, {
    authorUid: PEOPLE.teacher.uid, authorName: PEOPLE.teacher.name, context: 'Sala de aula — roda de conversa',
    description: 'Participou da roda com apoio de cartões visuais. Respondeu a perguntas diretas e manteve '
      + 'a atenção por cerca de dez minutos. Preferiu sentar-se próximo à professora.',
    observedAt: at(minute - 600), createdAt: at(minute + 1), updatedAt: at(minute + 1),
  });
  event('ev-d1-02', 'observation.created', PEOPLE.teacher, { refId: 'obs-d1-1' });
  put(`cases/${C1}/observations/obs-d1-2`, {
    authorUid: PEOPLE.teacher.uid, authorName: PEOPLE.teacher.name, context: 'Recreio — interação com colegas',
    description: 'Brincou em dupla no parque e aceitou revezar o brinquedo após mediação. Demonstrou '
      + 'desconforto com o barulho do sinal de saída.',
    observedAt: at(minute - 300), createdAt: at(minute + 1), updatedAt: at(minute + 1),
  });
  event('ev-d1-03', 'observation.created', PEOPLE.teacher, { refId: 'obs-d1-2' });
  put(`cases/${C1}/pedagogicalRecords/rec-d1-1`, {
    authorUid: PEOPLE.teacher.uid, authorName: PEOPLE.teacher.name,
    summary: 'Síntese do bimestre: avanços na participação em atividades coletivas com apoio visual; '
      + 'sensibilidade a ruídos intensos em transições.',
    actions: ['Rotina visual no início da aula', 'Aviso prévio antes do sinal', 'Tempo extra nas atividades escritas'],
    observationIds: ['obs-d1-1', 'obs-d1-2'], createdAt: at(minute + 1), updatedAt: at(minute + 1),
  });
  event('ev-d1-04', 'pedagogicalRecord.created', PEOPLE.teacher, { refId: 'rec-d1-1' });
  event('ev-d1-05', 'case.submitted', PEOPLE.teacher);
  const approved = event('ev-d1-06', 'case.approved', PEOPLE.director);
  const sent = event('ev-d1-07', 'referral.sent', PEOPLE.director, { referralId: R1 });
  event('ev-d1-08', 'referral.received', PEOPLE.ubs, { referralId: R1 });
  event('ev-d1-09', 'referral.assigned', PEOPLE.ubs, { referralId: R1 });
  event('ev-d1-10', 'referral.statusChanged', PEOPLE.psychologist, { referralId: R1 });
  put(`healthReturns/hr-d1-1`, {
    referralId: R1, caseId: C1, studentId: S1, audience: ['school', 'family'],
    content: 'Devolutiva sintética: o estudante beneficia-se de rotina previsível e antecipação de '
      + 'mudanças. Orientamos manter os apoios visuais em casa e na escola e combinar sinais para pausas.',
    authorUid: PEOPLE.psychologist.uid, authorName: PEOPLE.psychologist.name, createdAt: at(minute + 37),
  });
  const last = event('hr-d1-1', 'healthReturn.created', PEOPLE.psychologist, { referralId: R1, refId: 'hr-d1-1' });

  put(`cases/${C1}`, {
    studentId: S1, studentName: students[0].name, schoolInstitutionId: 'seed-escola-b',
    primaryTeacherUid: PEOPLE.teacher.uid, teacherUids: [PEOPLE.teacher.uid], status: 'em_acompanhamento',
    familyVisible: true, complementOpen: false, approvedAt: approved.createdAt, approvedBy: PEOPLE.director.uid,
    activeReferrals: { [R1]: 'seed-ubs-b' }, createdAt: at(47), updatedAt: last.createdAt,
    createdBy: PEOPLE.teacher.uid, updatedBy: PEOPLE.ubs.uid, lastEventId: 'ev-d1-09',
  });
  put(`caseLocks/${S1}`, {
    caseId: C1, schoolInstitutionId: 'seed-escola-b', createdAt: at(47), createdBy: PEOPLE.teacher.uid,
  });
  put(`referrals/${R1}`, {
    caseId: C1, studentId: S1, studentName: students[0].name, originInstitutionId: 'seed-escola-b',
    destinationInstitutionId: 'seed-ubs-b', status: 'devolutiva_registrada', previousStatus: null,
    assignedPsychologistUid: PEOPLE.psychologist.uid, assignedPsychologistName: PEOPLE.psychologist.name,
    createdAt: sent.createdAt, updatedAt: last.createdAt, createdBy: PEOPLE.director.uid,
    updatedBy: PEOPLE.psychologist.uid, lastEventId: 'hr-d1-1',
  });
  put(`referrals/${R1}/private/details`, {
    reason: 'Sensibilidade sensorial e dificuldade em transições observadas pela escola.',
    summary: 'Estudante do 4º ano com bons resultados em atividades com apoio visual; solicita-se '
      + 'avaliação e orientações para escola e família.',
    createdAt: sent.createdAt, createdBy: PEOPLE.director.uid,
  });
  put(`referrals/${R1}/notes/note-d1-1`, {
    kind: 'progress', text: 'Nota restrita sintética do atendimento (só o psicólogo lê).',
    audience: ['psychologist'], authorUid: PEOPLE.psychologist.uid, authorName: PEOPLE.psychologist.name,
    createdAt: at(minute - 10),
  });

  // Notificações da família: só eventos relevantes e visíveis a ela, após a
  // aprovação. As duas primeiras já lidas, para a demonstração do contador.
  const notifiable = events.filter(([, e]) => NOTIFIABLE.has(e.type) && e.visibility === 'familia');
  notifiable.forEach(([eventId, e], index) => {
    put(`notifications/${C1}_${eventId}`, {
      studentId: S1, caseId: C1, eventId, referralId: e.referralId, type: e.type,
      createdAt: e.createdAt, createdBy: e.actorUid, readAt: index < 2 ? at(minute + 60) : null,
    });
  });

  // ------------------------------------------------- caso 2 (aguardando análise)
  const C2 = 'seed-caso-demo-2';
  const S2 = 'seed-estudante-demo-2';
  put(`cases/${C2}/timelineEvents/ev-d2-01`, {
    type: 'case.created', visibility: 'familia', audience: [], referralId: null, refId: null,
    actorUid: PEOPLE.teacher.uid, actorName: PEOPLE.teacher.name, actorRole: PEOPLE.teacher.role, createdAt: at(900),
  });
  put(`cases/${C2}/observations/obs-d2-1`, {
    authorUid: PEOPLE.teacher.uid, authorName: PEOPLE.teacher.name, context: 'Alfabetização',
    description: 'Reconhece as letras do próprio nome; prefere atividades com encaixe e cores.',
    observedAt: at(880), createdAt: at(905), updatedAt: at(905),
  });
  put(`cases/${C2}/timelineEvents/ev-d2-02`, {
    type: 'observation.created', visibility: 'interno', audience: [], referralId: null, refId: 'obs-d2-1',
    actorUid: PEOPLE.teacher.uid, actorName: PEOPLE.teacher.name, actorRole: PEOPLE.teacher.role, createdAt: at(905),
  });
  put(`cases/${C2}/timelineEvents/ev-d2-03`, {
    type: 'case.submitted', visibility: 'familia', audience: [], referralId: null, refId: null,
    actorUid: PEOPLE.teacher.uid, actorName: PEOPLE.teacher.name, actorRole: PEOPLE.teacher.role, createdAt: at(910),
  });
  put(`cases/${C2}`, {
    studentId: S2, studentName: students[1].name, schoolInstitutionId: 'seed-escola-b',
    primaryTeacherUid: PEOPLE.teacher.uid, teacherUids: [PEOPLE.teacher.uid], status: 'aguardando_analise',
    familyVisible: false, complementOpen: false, approvedAt: null, approvedBy: null, activeReferrals: {},
    createdAt: at(900), updatedAt: at(910), createdBy: PEOPLE.teacher.uid, updatedBy: PEOPLE.teacher.uid,
    lastEventId: 'ev-d2-03',
  });
  put(`caseLocks/${S2}`, {
    caseId: C2, schoolInstitutionId: 'seed-escola-b', createdAt: at(900), createdBy: PEOPLE.teacher.uid,
  });
  return docs;
}

module.exports = { DEMO_FAMILY, students, buildDomain, NOTIFIABLE };
