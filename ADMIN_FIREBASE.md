# Administração Firebase pelo aplicativo

O módulo administrativo funciona pelo próprio aplicativo Flutter, usando
Firebase Authentication e Cloud Firestore no plano Spark. Não há Cloud
Functions, Neon ou ferramenta administrativa local para o uso cotidiano.

## Usuários

Ao tocar em `Novo cadastro` na seção Usuários, o administrador informa nome
completo, e-mail, role, status e o profissional opcional. O nome completo é
separado internamente em `firstName` e `lastName`, mantendo também `name` para
compatibilidade.

Para usuários da Escola, `role` permanece como `escola` e a função é salva em
`schoolRole`, inicialmente com os valores `professor` ou `direcao`. Essa
separação permite atribuições diferentes sem quebrar os documentos antigos.
Usuários antigos de Escola sem `schoolRole` são interpretados como Professor
até que um administrador atualize o cadastro.

A tela inicial de acesso continua exibindo somente Escola, Família, Saúde e
Administração. Professor e Direção aparecem apenas no cadastro administrativo;
ao entrar por Escola, a aplicação lê a subrole já salva no perfil.

A criação usa uma instância secundária do Firebase Authentication. Assim, a
nova conta é criada sem substituir ou desconectar a sessão do administrador.
Uma senha temporária aleatória é usada somente durante essa chamada, nunca é
exibida, registrada ou persistida. Depois, o Firebase envia ao novo usuário o
e-mail para definição de senha.

O ícone de caneta abre o mesmo formulário para edição. Nome, role, status e
vínculo profissional são atualizados no Firestore. Mudanças de role e status
exigem confirmação, e o administrador não pode remover a própria role nem
desativar a própria conta.

Na edição de outra pessoa, `Excluir usuário` remove o documento `users/{uid}`,
desfaz o vínculo correspondente em `professionals/{professionalId}` e registra
`user.delete` em `adminAuditLogs`. A própria conta administrativa nunca pode ser
excluída pelo painel. Uma sessão já aberta perde o perfil observado e é
desconectada.

### Limitações sem backend privilegiado

O SDK cliente do Firebase não permite alterar o e-mail nem o campo `disabled`
de outra conta do Authentication. Por isso:

- o e-mail de uma conta existente fica somente para leitura;
- `active: false` bloqueia o usuário pelo perfil, pelas rotas e pelas regras do
  Firestore, embora o registro técnico permaneça no Authentication;
- a exclusão pelo painel remove o acesso e o perfil do Firestore, mas não pode
  apagar a conta de outra pessoa no Authentication. Para reutilizar o mesmo
  e-mail, essa conta técnica precisa ser removida manualmente no Console do
  Firebase;
- ao tentar entrar, um usuário inativo é imediatamente desconectado e não
  consegue ler dados protegidos.

Essas limitações não afetam a criação de usuários, a troca de role ou a
ativação/desativação dentro do Caminho Azul.

## Profissionais

Todo novo profissional deve selecionar um usuário ativo ainda não vinculado a
outro profissional. Nome, sobrenome e e-mail são copiados desse usuário tanto
pela interface quanto novamente pelo repositório. O formulário solicita apenas
usuário vinculado, telefone, registro profissional, instituições e status. O
campo legado `specialty` continua sendo aceito na leitura, mas não aparece em
novos cadastros.

Como a criação usa o SDK cliente, o endpoint público do Authentication também
pode criar uma conta Auth sem perfil. Isso não concede acesso ao Caminho Azul:
sem um `users/{uid}` criado por um administrador, o login é bloqueado e as
regras negam os dados. Impedir até mesmo a criação técnica dessas contas exige
um backend privilegiado ou recursos pagos do Identity Platform.

## Administrador atual

O administrador é reconhecido quando a conta autenticada possui um documento
`users/{uid}` com:

```json
{
  "active": true,
  "role": "admin"
}
```

Documentos antigos que possuem somente `name` continuam compatíveis. Para
preparar uma primeira conta Auth já existente, há um script de bootstrap:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/c/FirebaseSecrets/caminhoazul-admin.json"
export ADMIN_UID="UID_JA_EXISTENTE"
export ADMIN_NAME="David Tavares"
npm --prefix scripts run create:first-admin
```

Esse script é necessário apenas para o primeiro administrador. Guarde qualquer
JSON de conta de serviço fora do repositório.

## Regras e índices

Depois de alterar as regras, publique somente Firestore:

```bash
firebase.cmd deploy --only "firestore:rules,firestore:indexes" --project caminhoazul
```

Não execute deploy de Functions. As consultas atuais não exigem índices
compostos; `firestore.indexes.json` mantém a lista vazia explicitamente.

## Emulator Suite

Para executar o app com Authentication e Firestore locais:

```bash
firebase emulators:start --only auth,firestore --project caminhoazul
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

Em dispositivo físico, informe o IP da máquina:

```bash
flutter run --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=192.168.1.10
```

Os testes automatizados das regras usam um projeto `demo-*` isolado e a porta
8180, podendo rodar mesmo quando o emulador principal está aberto:

```bash
npm --prefix scripts test
```
