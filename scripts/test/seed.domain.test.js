'use strict';

// P0-02 fase B: coerência do seed de domínio (sem emulador).
const test = require('node:test');
const assert = require('node:assert');
const { buildDomain, NOTIFIABLE, DEMO_FAMILY } = require('../seed/domain');

const docs = buildDomain((minutes) => new Date(Date.UTC(2026, 10, 20) + minutes * 60000));
const byPath = new Map(docs);

test('fase B: caso, trava, encaminhamento e devolutiva coerentes', () => {
  const c = byPath.get('cases/seed-caso-demo-1');
  assert.equal(byPath.get(`caseLocks/${c.studentId}`).caseId, 'seed-caso-demo-1');
  assert.ok(byPath.get(`cases/seed-caso-demo-1/timelineEvents/${c.lastEventId}`));
  const r = byPath.get('referrals/seed-enc-demo-1');
  assert.equal(r.caseId, 'seed-caso-demo-1');
  assert.equal(c.activeReferrals['seed-enc-demo-1'], r.destinationInstitutionId);
  assert.ok(byPath.get(`cases/seed-caso-demo-1/timelineEvents/${r.lastEventId}`));
  const student = byPath.get(`students/${c.studentId}`);
  assert.equal(student.familyUid, DEMO_FAMILY.uid);
  assert.deepEqual(DEMO_FAMILY.studentIds, [c.studentId]);
});

test('fase B: notificações só de eventos relevantes, visíveis à família e sem texto livre', () => {
  const notifications = docs.filter(([p]) => p.startsWith('notifications/'));
  assert.ok(notifications.length >= 5);
  for (const [path, n] of notifications) {
    assert.equal(path, `notifications/${n.caseId}_${n.eventId}`);
    const event = byPath.get(`cases/${n.caseId}/timelineEvents/${n.eventId}`);
    assert.ok(event, path);
    assert.equal(event.visibility, 'familia');
    assert.ok(NOTIFIABLE.has(event.type));
    assert.equal(event.type, n.type);
    assert.equal(byPath.get(`cases/${n.caseId}`).familyVisible, true);
    assert.deepEqual(Object.keys(n).sort(), ['caseId', 'createdAt', 'createdBy', 'eventId', 'readAt', 'referralId', 'studentId', 'type']);
  }
  // Eventos internos nunca notificam; o caso não aprovado não tem notificação.
  assert.ok(!notifications.some(([, n]) => n.caseId === 'seed-caso-demo-2'));
});

test('fase B: somente dados sintéticos', () => {
  const text = JSON.stringify(docs);
  assert.ok(!/@(?!caminhoazul\.test)[a-z0-9.-]+\.[a-z]{2,}/i.test(text), 'e-mail fora do domínio de teste');
  assert.ok(/Sintétic|Demonstração/.test(text));
});
