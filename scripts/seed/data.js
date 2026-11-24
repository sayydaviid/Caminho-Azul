'use strict';

// Dados sintéticos compartilhados entre o seed (scripts/seed_emulator.js) e os
// testes de Security Rules. Nenhum dado real.

// Valores persistidos de role/subrole.
// CANONICAL_EN: decisão D-08, lido pelo app desde P1-17. LEGACY_PT: valores antigos, só para testar a normalização.
const ROLE_VALUES = {
  LEGACY_PT: {
    role: { admin: 'admin', school: 'escola', health: 'saude', family: 'familia' },
    schoolRole: { teacher: 'professor', director: 'direcao' },
  },
  CANONICAL_EN: {
    role: { admin: 'admin', school: 'school', health: 'health', family: 'family' },
    schoolRole: { teacher: 'teacher', director: 'director' },
  },
};
const HEALTH_ROLE = { ubsDirector: 'ubs_director', psychologist: 'psychologist' };

const STUDENT_ID = 'seed-estudante-1';

const institutions = [
  { id: 'seed-escola-a', name: 'Escola Municipal Azul (sintética)', type: 'school' },
  { id: 'seed-escola-b', name: 'Escola Municipal Verde (sintética)', type: 'school' },
  { id: 'seed-ubs-a', name: 'UBS Horizonte (sintética)', type: 'ubs' },
  { id: 'seed-ubs-b', name: 'UBS Aurora (sintética)', type: 'ubs' },
];

// role/subrole abstratos; o valor gravado vem de ROLE_VALUES.
const users = [
  { uid: 'seed-admin', email: 'admin@caminhoazul.test', first: 'Admin', last: 'Sintético', role: 'admin' },
  { uid: 'seed-diretor-escola', email: 'direcao.escola@caminhoazul.test', first: 'Diretora', last: 'Escolar Sintética', role: 'school', schoolRole: 'director', institutions: ['seed-escola-a'] },
  { uid: 'seed-professor', email: 'professor@caminhoazul.test', first: 'Professor', last: 'Sintético', role: 'school', schoolRole: 'teacher', institutions: ['seed-escola-a'] },
  { uid: 'seed-diretor-ubs', email: 'direcao.ubs@caminhoazul.test', first: 'Diretor', last: 'UBS Sintético', role: 'health', healthRole: 'ubsDirector', institutions: ['seed-ubs-a'] },
  { uid: 'seed-psicologo', email: 'psicologo@caminhoazul.test', first: 'Psicóloga', last: 'Sintética', role: 'health', healthRole: 'psychologist', institutions: ['seed-ubs-a'] },
  { uid: 'seed-psicologo-2', email: 'psicologo2@caminhoazul.test', first: 'Psicólogo', last: 'Dois Sintético', role: 'health', healthRole: 'psychologist', institutions: ['seed-ubs-a'] },
  { uid: 'seed-familia', email: 'familia@caminhoazul.test', first: 'Família', last: 'Sintética', role: 'family', studentIds: [STUDENT_ID] },
  { uid: 'seed-diretor-escola-b', email: 'direcao.escola.b@caminhoazul.test', first: 'Diretor', last: 'Escola B Sintético', role: 'school', schoolRole: 'director', institutions: ['seed-escola-b'] },
  { uid: 'seed-professor-b', email: 'professor.b@caminhoazul.test', first: 'Professora', last: 'Escola B Sintética', role: 'school', schoolRole: 'teacher', institutions: ['seed-escola-b'] },
  { uid: 'seed-diretor-ubs-b', email: 'direcao.ubs.b@caminhoazul.test', first: 'Diretora', last: 'UBS B Sintética', role: 'health', healthRole: 'ubsDirector', institutions: ['seed-ubs-b'] },
  { uid: 'seed-psicologo-b', email: 'psicologo.b@caminhoazul.test', first: 'Psicólogo', last: 'UBS B Sintético', role: 'health', healthRole: 'psychologist', institutions: ['seed-ubs-b'] },
  { uid: 'seed-inativo', email: 'inativo@caminhoazul.test', first: 'Conta', last: 'Inativa Sintética', role: 'family', active: false },
  { uid: 'seed-sem-perfil', email: 'semperfil@caminhoazul.test', first: 'Conta', last: 'Sem Perfil', noProfile: true },
];

const student = {
  id: STUDENT_ID,
  name: 'Estudante Sintético Um',
  schoolInstitutionId: 'seed-escola-a',
  grade: '3º ano A',
  familyUid: 'seed-familia',
  createdBy: 'seed-diretor-escola',
};

// Estudante ainda sem conta familiar (para o admin criar o acesso da família).
const unlinkedStudent = {
  id: 'seed-estudante-2',
  name: 'Estudante Sintético Dois',
  schoolInstitutionId: 'seed-escola-a',
  grade: '2º ano B',
  familyUid: null,
  createdBy: 'seed-diretor-escola',
};

const isProfessional = (user) => user.role === 'school' || user.role === 'health';
const professionalIdOf = (user) => `seed-prof-${user.uid.replace(/^seed-/, '')}`;
const fullName = (user) => `${user.first} ${user.last}`;

/** Documento users/{uid} com os valores do mapeamento escolhido. */
function userDoc(user, mapping, timestamps) {
  return {
    firstName: user.first,
    lastName: user.last,
    name: fullName(user),
    email: user.email,
    role: mapping.role[user.role],
    schoolRole: user.schoolRole ? mapping.schoolRole[user.schoolRole] : null,
    healthRole: user.healthRole ? HEALTH_ROLE[user.healthRole] : null,
    active: user.active ?? true,
    professionalId: isProfessional(user) ? professionalIdOf(user) : null,
    institutionIds: user.institutions ?? [],
    studentIds: user.studentIds ?? [],
    createdBy: 'seed-admin',
    lastAccessAt: null,
    ...timestamps,
  };
}

module.exports = {
  ROLE_VALUES,
  HEALTH_ROLE,
  STUDENT_ID,
  institutions,
  users,
  student,
  unlinkedStudent,
  isProfessional,
  professionalIdOf,
  fullName,
  userDoc,
};
