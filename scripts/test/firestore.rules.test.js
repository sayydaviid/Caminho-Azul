'use strict';

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-caminhoazul',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8'),
    },
  });
});

test.beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/admin-1'), {
      name: 'Admin', email: 'admin@exemplo.com', role: 'admin', active: true,
    });
    await setDoc(doc(db, 'users/user-1'), {
      name: 'Pessoa', email: 'pessoa@exemplo.com', role: 'familia', active: true,
      professionalId: null,
    });
    await setDoc(doc(db, 'users/disabled-1'), {
      name: 'Inativo', email: 'inativo@exemplo.com', role: 'familia', active: false,
    });
    await setDoc(doc(db, 'institutions/active-1'), {
      name: 'Instituição ativa', type: 'Escola', active: true,
    });
  });
});

test.after(async () => environment.cleanup());

test('usuario comum nao cria conta nem eleva a propria role', async () => {
  const db = environment.authenticatedContext('user-1').firestore();
  await assertFails(setDoc(doc(db, 'users/new-user'), {
    name: 'Novo', email: 'novo@exemplo.com', role: 'admin', active: true,
  }));
  await assertFails(updateDoc(doc(db, 'users/user-1'), { role: 'admin' }));
});

test('administrador lista usuarios e usuario comum nao lista', async () => {
  const adminDb = environment.authenticatedContext('admin-1').firestore();
  const commonDb = environment.authenticatedContext('user-1').firestore();
  await assertSucceeds(getDocs(collection(adminDb, 'users')));
  await assertFails(getDocs(collection(commonDb, 'users')));
});

test('administrador cria usuario e altera role de outro usuario', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  const schoolUser = {
    firstName: 'Nova',
    lastName: 'Pessoa',
    name: 'Nova Pessoa',
    email: 'nova@exemplo.com',
    role: 'escola',
    schoolRole: 'professor',
    active: true,
    professionalId: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    createdBy: 'admin-1',
    lastAccessAt: null,
  };
  await assertSucceeds(setDoc(doc(db, 'users/new-user'), schoolUser));
  await assertFails(setDoc(doc(db, 'users/invalid-school-user'), {
    ...schoolUser,
    email: 'invalido@exemplo.com',
    schoolRole: 'coordenacao',
  }));
  await assertSucceeds(updateDoc(doc(db, 'users/new-user'), {
    schoolRole: 'direcao',
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(db, 'users/user-1'), {
    role: 'saude',
    updatedAt: serverTimestamp(),
  }));
});

test('administrador nao remove a propria role nem se desativa', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  await assertFails(updateDoc(doc(db, 'users/user-1'), {
    role: 'papel-invalido',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'users/admin-1'), {
    role: 'familia',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'users/admin-1'), {
    active: false,
    updatedAt: serverTimestamp(),
  }));
});

test('somente administrador exclui outro usuario e nunca a si mesmo', async () => {
  const adminDb = environment.authenticatedContext('admin-1').firestore();
  const commonDb = environment.authenticatedContext('user-1').firestore();

  await assertFails(deleteDoc(doc(commonDb, 'users/admin-1')));
  await assertFails(deleteDoc(doc(adminDb, 'users/admin-1')));
  await assertSucceeds(deleteDoc(doc(adminDb, 'users/user-1')));
});

test('somente administrador grava instituicoes', async () => {
  const adminDb = environment.authenticatedContext('admin-1').firestore();
  const commonDb = environment.authenticatedContext('user-1').firestore();
  const value = {
    name: 'Centro Azul', type: 'Centro', active: true,
    createdBy: 'admin-1', createdAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(adminDb, 'institutions/new-1'), value));
  await assertFails(setDoc(doc(commonDb, 'institutions/new-2'), {
    ...value, createdBy: 'user-1',
  }));
  await assertSucceeds(updateDoc(doc(adminDb, 'institutions/active-1'), {
    name: 'Instituição legada atualizada',
  }));
});

test('usuario desativado nao le dados protegidos', async () => {
  const activeDb = environment.authenticatedContext('user-1').firestore();
  const disabledDb = environment.authenticatedContext('disabled-1').firestore();
  await assertSucceeds(getDoc(doc(activeDb, 'institutions/active-1')));
  await assertFails(getDoc(doc(disabledDb, 'institutions/active-1')));
});
