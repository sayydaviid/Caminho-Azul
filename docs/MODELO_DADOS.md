# Modelo de dados — Caminho Azul

> P0-03 (22/11/2026). Fonte de verdade das coleções, campos, permissões e consultas do domínio. As regras estão em [`firestore.rules`](../firestore.rules), os testes em [`scripts/test/domain.rules.test.js`](../scripts/test/domain.rules.test.js) e os índices em [`firestore.indexes.json`](../firestore.indexes.json).

## 1. Princípios

1. **Metadados × conteúdo.** `cases` e `referrals` guardam só metadados administrativos (IDs, status, instituições, responsáveis). Conteúdo pedagógico e de saúde fica em documentos próprios, com regras próprias. O admin lê os metadados e **não** lê o conteúdo (D-11). Nada depende de esconder campos na interface.
2. **Roles canônicas em inglês (D-08).** As regras do domínio aceitam só `role` ∈ {`admin`, `school`, `health`, `family`}, `schoolRole` ∈ {`teacher`, `director`} e `healthRole` ∈ {`ubs_director`, `psychologist`}. Documentos com valores antigos (`escola`, `professor` etc.) ou sem subrole **não** operam no domínio (testado). O app passa a gravar os valores em inglês em P1-17.
3. **Autoria e tempo confiáveis.** `createdBy`/`updatedBy`/`authorUid`/`actorUid` == `request.auth.uid`; `createdAt`/`updatedAt` == `request.time` (usar `serverTimestamp()`); `authorName`/`actorName` == `users/{uid}.name`.
4. **Transições amarradas a eventos.** Toda mudança de status em `cases` ou `referrals` grava `lastEventId` novo e, **no mesmo batch**, o evento `cases/{caseId}/timelineEvents/{lastEventId}` do tipo esperado, do mesmo autor. O evento só pode ser criado junto da alteração que o originou. Justificativas e devolutivas usam o **mesmo ID** do evento.
5. **Histórico imutável.** Eventos, devolutivas, notas, `private/details` e auditoria não têm `update` nem `delete`. Casos, encaminhamentos e estudantes não são excluídos.
6. **Limite de leituras nas regras.** Desnormalização (`users.institutionIds`, `users.studentIds`, `referrals.studentId`/`studentName`) mantém cada operação com poucos `get()`. Os batches mais pesados dos testes passam sem estourar o limite.

## 2. Perfil do usuário (`users/{uid}`) — campos usados pelo domínio

| Campo | Uso |
|---|---|
| `role`, `schoolRole`, `healthRole`, `active` | Identificação do perfil (sem fallback). |
| `institutionIds[]` | Escolas ou UBS do profissional. Cópia de `professionals.institutionIds`, sincronizada pelo admin (P1-10). |
| `studentIds[]` | Estudantes da conta `family` (D-10). Alterado só pelo admin, no mesmo batch de `students.familyUid`. |
| `name` | Usado para validar `authorName` e `actorName`. |

## 3. Coleções do domínio

### `students/{studentId}` (D-09)

| Campo | Tipo | Observação |
|---|---|---|
| `name` | string (2–120) | |
| `grade` | string? (≤ 60) | Ano ou turma. |
| `schoolInstitutionId` | string | Imutável. |
| `familyUid` | string? | Definido **só pelo admin**, consistente com `users/{familyUid}.studentIds`. |
| `active` | bool | |
| `createdAt`, `updatedAt`, `createdBy`, `updatedBy` | carimbos | |

### `cases/{caseId}` (metadados)

| Campo | Tipo | Observação |
|---|---|---|
| `studentId`, `studentName` | string | Conferidos com `students` na criação; imutáveis. |
| `schoolInstitutionId` | string | Imutável. |
| `primaryTeacherUid`, `teacherUids[]` | string, lista (1–10) | O principal precisa ser professor ativo da mesma escola. |
| `status` | enum | `rascunho` → `aguardando_analise` ⇄ `complementacao_solicitada` → `aprovado` → `encaminhado` → `em_acompanhamento` → `concluido` (único terminal, D-12). |
| `familyVisible` | bool | Vira `true` na aprovação; libera à família o histórico administrativo completo (D-16). |
| `approvedAt`, `approvedBy` | timestamp?, string? | Gravados na aprovação (`request.time`, Direção). |
| `complementOpen` | bool | Complementação pedida pela UBS e repassada ao professor (D-20). |
| `activeReferrals` | mapa `{referralId: ubsId}` | Começa `{}`. A Direção escolar adiciona o encaminhamento no batch de criação (um ativo por UBS). A Direção UBS remove no batch de devolução, recusa ou finalização. `concluido` exige mapa vazio (D-12). |
| `lastEventId` | string | Evento da última alteração. |
| `createdAt`, `updatedAt`, `createdBy`, `updatedBy` | carimbos | |

### `cases/{caseId}/observations/{id}` e `cases/{caseId}/pedagogicalRecords/{id}` (conteúdo interno)

- **Observação:** `authorUid`, `authorName`, `context` (1–200), `description` (1–5000), `observedAt`, `createdAt`, `updatedAt`.
- **Registro pedagógico:** `authorUid`, `authorName`, `summary` (1–5000), `actions[]` (≤ 20), `observationIds[]` (≤ 50), `createdAt`, `updatedAt`.
- `pedagogicalRecords` existe porque o RF09 pede um registro que reúne observações e ações, com ciclo próprio.
- Ambos são escritos pelo professor vinculado em `rascunho`, `complementacao_solicitada` ou com `complementOpen`. Só o autor edita. Leem apenas os professores vinculados e a Direção da escola.

### `cases/{caseId}/timelineEvents/{eventId}` (imutável)

| Campo | Observação |
|---|---|
| `type` | Ver catálogo abaixo. |
| `visibility` | `familia`, `interno` ou `restrito` (fixa por tipo; só a devolutiva depende da audiência). |
| `audience[]` | `[]`; ou `['school']` para eventos `restrito`. |
| `referralId`, `refId` | Encaminhamento relacionado; observação, registro ou devolutiva relacionada. |
| `actorUid`, `actorName`, `actorRole`, `createdAt` | Autoria e carimbo verificados. `actorRole`: `school/teacher`, `school/director`, `health/ubs_director` ou `health/psychologist`. |

| Quem cria | Tipos | Visibilidade |
|---|---|---|
| Professor vinculado | `case.created`, `case.submitted`, `case.complemented` | familia |
| Professor vinculado | `observation.created`, `pedagogicalRecord.created` | interno |
| Direção escolar | `case.complementRequested`, `case.approved`, `case.concluded`, `referral.sent`, `referral.complementAnswered` | familia |
| Direção escolar | `case.teachersUpdated`, `case.ubsComplementForwarded`, `case.ubsComplementClosed` | interno |
| Direção UBS (destino) | `referral.received`, `referral.assigned`, `referral.transferred`, `referral.complementRequested`, `referral.returned`, `referral.refused`, `referral.finalized` | familia (só o fato) |
| Psicólogo atribuído | `referral.statusChanged` | familia |
| Psicólogo atribuído | `healthReturn.created` | familia, se a audiência inclui `family`; senão restrito `['school']` |

### `referrals/{referralId}` (metadados)

| Campo | Observação |
|---|---|
| `caseId`, `studentId`, `studentName`, `originInstitutionId` | Copiados do caso; imutáveis. |
| `destinationInstitutionId` | UBS ativa (`institutions.type == 'ubs'`); imutável. |
| `status` | `enviado` → `recebido` → `atribuido` → `em_atendimento` → `devolutiva_registrada` → `finalizado`. Também `complementacao_solicitada` (volta ao `previousStatus` com a resposta da Direção escolar) e os finais `devolvido`/`recusado` (com justificativa). |
| `previousStatus` | Usado na complementação. |
| `assignedPsychologistUid`, `assignedPsychologistName` | Psicólogo ativo da mesma UBS; um por vez. A transferência troca o valor e revoga o acesso anterior. |
| `lastEventId`, carimbos | |

Um caso pode ter **vários encaminhamentos simultâneos** para UBS diferentes. O primeiro leva o caso de `aprovado` para `encaminhado`; a primeira atribuição leva de `encaminhado` para `em_acompanhamento`. "No máximo um ativo por UBS" e "concluir só sem encaminhamentos ativos" são impostos pelas regras por meio de `cases.activeReferrals`.

### `referrals/{id}/private/details` (doc único, D-13)

`reason` (1–1000), `summary` (resumo mínimo, 1–5000), `createdAt`, `createdBy`. Criado junto com o encaminhamento. Leem: Direção escolar de origem, Direção UBS de destino e psicólogo atribuído. **Não** leem: admin, família, professor.

### `referrals/{id}/notes/{noteId}` (restrito, imutável)

| `kind` | Autor | `audience` | ID |
|---|---|---|---|
| `complementRequest`, `return`, `refusal` | Direção UBS | `['school','ubs']` | = `lastEventId` da transição |
| `complementAnswer` | Direção escolar | `['school','ubs','psychologist']` | = `lastEventId` |
| `progress` | Psicólogo atribuído | `['psychologist']` | livre |

### `healthReturns/{returnId}` (devolutiva, imutável)

`referralId`, `caseId`, `studentId`, `audience[]` ⊆ {`school`, `family`} (≥ 1), `content`, `authorUid`, `authorName`, `createdAt`. Criada só pelo psicólogo atribuído, no batch que leva o `referral` a `devolutiva_registrada`, com `returnId` == `lastEventId` == ID do evento.

- **Leem:** o autor e o psicólogo atribuído; Direção escolar e professores vinculados, se a audiência inclui `school`; a família, se inclui `family`.
- **Não leem:** admin e Direção UBS (D-11, D-13).

## 4. Batches que o app deve usar

| Ação | Escritas no mesmo batch |
|---|---|
| Criar caso | `cases/{id}` (status `rascunho`, `lastEventId=E`) + evento `E` `case.created` |
| Observação | observação `O` + evento `interno` com `refId=O` |
| Enviar, complementar, solicitar complemento, aprovar, concluir | `update cases/{id}` (`lastEventId=E`) + evento `E` |
| Encaminhar | `referrals/{R}` (`lastEventId=E`) + `referrals/{R}/private/details` + evento `E` `referral.sent` (`referralId=R`) + `update cases` (`activeReferrals.R = ubsId`, `lastEventId=E`; e `status=encaminhado` se estava `aprovado`) |
| Receber | `update referrals` + evento |
| Finalizar, devolver, recusar | `update referrals` + evento `E` (+ `notes/E` em devolução e recusa) + `update cases` (remove `activeReferrals.R`, `lastEventId=E`) |
| Atribuir | `update referrals` (`atribuido` + psicólogo) + evento `referral.assigned` + (se o caso está `encaminhado`) `update cases` para `em_acompanhamento` |
| Transferir | `update referrals` (novo psicólogo, mesmo status) + evento `referral.transferred` |
| Complementação UBS | `update referrals` + evento `E` + `notes/E` |
| Resposta da Direção escolar | `update referrals` (volta a `previousStatus`) + evento `E` `referral.complementAnswered` + `notes/E` |
| Devolutiva | `healthReturns/E` + `update referrals` (`devolutiva_registrada`, `lastEventId=E`) + evento `E` |
| Vincular família (admin) | `update students.familyUid` + `update users/{family}.studentIds` |

## 5. Consultas compatíveis com as regras

As regras **não filtram** resultados. Cada consulta precisa trazer os filtros que provam a permissão:

| Perfil | Consulta |
|---|---|
| Professor | `cases` where `schoolInstitutionId == X` and `teacherUids array-contains uid` (sem o filtro de escola: negado); `students` where `schoolInstitutionId == X`; `referrals` where `caseId == C`. |
| Direção escolar | `cases` / `students` where `schoolInstitutionId == X`; `referrals` where `caseId == C` **and** `originInstitutionId == X` (só `caseId` é negado: a regra da Direção depende da origem). |
| Direção UBS | `referrals` where `destinationInstitutionId == U`. |
| Psicólogo | `referrals` where `assignedPsychologistUid == uid`. |
| Família | `cases` where `studentId == S` and `familyVisible == true`; `referrals` where `studentId == S`; `healthReturns` where `studentId == S` and `audience array-contains 'family'`; `students` where `familyUid == uid`. |
| Linha do tempo | família: `visibility == 'familia'`; escola: `visibility in ['familia','interno']` + (restrito) `visibility == 'restrito'` **and** `audience array-contains 'school'`; saúde: `referralId == R` and `visibility == 'familia'`. |
| Direção UBS (caso) | `get cases/{id}` enquanto `activeReferrals` contiver a sua UBS (só metadados). |
| Psicólogos da UBS | `professionals` where `active == true`, `institutionIds array-contains U`, `subrole == 'psychologist'`. |
| Admin | `cases`, `referrals`, `students` sem filtro (só metadados). |

## 6. Privacidade no cliente

- Persistência em disco do Firestore desativada (`Settings(persistenceEnabled: false)`).
- O logout executa `terminate()` + `clearPersistence()` no Android, para que um próximo usuário do mesmo aparelho não receba resultados em cache da sessão anterior (defeito encontrado em P1-19). Na Web a instância não é encerrada (D-A09) e a sessão fica só em memória.

## 7. Lacunas antigas (resolvidas)

As lacunas registradas aqui em 22/11 foram resolvidas: listas de professores e psicólogos por `professionals` (P1-02, P1-16), identificadores em inglês (P1-17) e tipo de instituição controlado (P1-19, P2-05).

## 8. Acréscimos de 24/11/2026 (P2-05, P2-06, notificações e PDF)

### 8.1 Auditoria imposta (P2-05)

| Campo/coleção | Regra |
|---|---|
| `lastAuditId` em `users`, `professionals`, `institutions`, `localNetworks`, `adminParameters` | Toda gravação do admin troca `lastAuditId` e grava, **no mesmo batch**, `adminAuditLogs/{lastAuditId}` com `actorUid` = admin, `createdAt` = horário do servidor, `targetType`/`targetId` do alvo e `action` válida para o tipo. |
| Logs complementares | `{id}-role` (`user.role.update`, obrigatório quando role/subrole muda), `{id}-active` (`user.activate`/`user.deactivate`, quando o status muda sem ser pelo "Excluir usuário"), `{id}-assoc` (`association.update`). |
| `adminAuditLogs` | Só nasce se o alvo apontar para ele no mesmo batch (log avulso ou forjado é negado); campos fixos; imutável; leitura só do admin. |
| `students.familyUid` (admin) | Só muda junto da conta familiar auditada no mesmo batch. |

Schema validado nas regras (sonda P14): `institutions` (`type ∈ {school, ubs}`, imutável depois de canônico), `professionals` (até 5 instituições, função igual à da conta), `localNetworks`, `adminParameters`. Contas da Escola só atuam em escolas ativas e as da Saúde só em UBS ativas (até 5, verificadas por índice). Leitura de `professionals`: admin e Direções (escolar/UBS), só profissionais ativos das suas instituições (sonda P9).

### 8.2 Unicidade (P2-06)

| Vínculo | Garantia |
|---|---|
| Conta ↔ profissional | Bidirecional; ao trocar, o lado anterior precisa ser solto no mesmo batch. |
| Estudante ↔ família | `familyUid` só passa de `null` a uma conta (ou volta a `null`); duas contas simultâneas: só uma é aceita. |
| Estudante ↔ caso | `caseLocks/{studentId}` `{caseId, schoolInstitutionId, createdAt, createdBy}` gravada com o caso. Um caso em andamento por estudante (RN-20); a trava só é reocupada depois da conclusão. Nunca apagada. |
| Professor ↔ caso | `teacherUids` sem repetição. |
| Psicólogo/UBS ↔ encaminhamento | Já impostos pelo estado do documento (um psicólogo, um ativo por UBS). |

As regras são avaliadas no commit com o estado atual: operações concorrentes conflitantes resultam em exatamente uma aceita (testado).

### 8.3 `notifications/{caseId}_{eventId}` (N-01..N-04)

`{studentId, caseId, eventId, referralId, type, createdAt, createdBy, readAt}`. Nasce no mesmo batch do evento da linha do tempo, do mesmo autor, quando o tipo é relevante e o evento é visível à família (`case.approved`, `referral.sent/received/assigned/transferred/statusChanged/complementRequested/returned/refused/finalized`, `healthReturn.created` para a família, `case.concluded`). O evento relevante **não** é aceito sem a notificação. Não guarda texto: título e mensagem são fixos no app. Leitura: família do estudante (`where studentId == S`). Atualização: só `readAt`, uma vez, com o horário do servidor. Índice: `studentId` ASC + `createdAt` DESC.

### 8.4 `documentExports/{auto}` (R-07)

`{kind, action, caseId, referralId, actorUid, itemCount, createdAt}`, sem conteúdo. `kind ∈ {pedagogical, school, health, ubs, family}`, cada um só para o perfil que o gera e para o caso/encaminhamento que ele lê. `action ∈ {generated, share_opened, print_opened, downloaded}` (abrir o menu não comprova a entrega). Leitura: admin (metadados).

### 8.5 Batches alterados

| Operação | Acréscimo |
|---|---|
| Criar caso | `caseLocks/{studentId}` |
| Transições com evento relevante para a família | `notifications/{caseId}_{eventId}` |
| Toda gravação administrativa | `lastAuditId` no alvo + `adminAuditLogs/{id}` (e sufixos) |
