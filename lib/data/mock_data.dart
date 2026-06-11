import '../models/app_models.dart';

abstract final class MockData {
  static const stats = [
    DashboardStat('Total de casos', 142, 'primary'),
    DashboardStat('Em acompanhamento', 87, 'success'),
    DashboardStat('Aguardando encaminhamento', 23, 'warning'),
    DashboardStat('Retorno pendente', 12, 'danger'),
    DashboardStat('Atendimentos agendados', 8, 'purple'),
    DashboardStat('Atualizacao recente', 34, 'primary'),
  ];

  static const cases = [
    CaseRecord(name: 'Lucas Oliveira', school: 'EM Monteiro Lobato', stage: 'Avaliacao', status: 'Em andamento', updatedAt: '02/04/2026'),
    CaseRecord(name: 'Maria Santos', school: 'EM Cecilia Meireles', stage: 'Encaminhamento', status: 'Pendente', updatedAt: '01/04/2026'),
    CaseRecord(name: 'Pedro Costa', school: 'EM Castro Alves', stage: 'Terapia iniciada', status: 'Ativo', updatedAt: '31/03/2026'),
    CaseRecord(name: 'Julia Lima', school: 'EM Drummond', stage: 'Identificacao', status: 'Novo', updatedAt: '03/04/2026'),
    CaseRecord(name: 'Gabriel Souza', school: 'EM Monteiro Lobato', stage: 'Acompanhamento', status: 'Ativo', updatedAt: '30/03/2026'),
  ];

  static const dashboardNotices = [
    NoticeRecord('Ficha incompleta: Lucas Oliveira', '', 'warning'),
    NoticeRecord('Encaminhamento sem resposta: Maria Santos', '', 'danger'),
    NoticeRecord('Documento pendente: Pedro Costa', '', 'warning'),
    NoticeRecord('Atualizacao clinica recebida: Gabriel Souza', '', 'success'),
    NoticeRecord('Prazo de retorno proximo: Julia Lima', '', 'danger'),
  ];

  static const familyNotices = [
    NoticeRecord('Novo relatorio pedagogico disponivel', '03/04/2026', 'primary'),
    NoticeRecord('Encaminhamento realizado para UBS Centro', '01/04/2026', 'success'),
    NoticeRecord('Documento solicitado pela escola', '30/03/2026', 'warning'),
    NoticeRecord('Atualizacao da escola sobre Lucas', '28/03/2026', 'primary'),
    NoticeRecord('Retorno da saude agendado', '25/03/2026', 'success'),
  ];

  static const documents = [
    DocumentRecord(id: 1, name: 'Relatorio_Pedagogico_Lucas_Mar2026.pdf', type: 'Relatorios', date: '03/04/2026', user: 'Dra. Ana Silva', origin: 'Escola', size: '245 KB', validated: true),
    DocumentRecord(id: 2, name: 'Laudo_Neuropsicologico.pdf', type: 'Laudos', date: '15/02/2026', user: 'Dr. Marcos Pereira', origin: 'Saude', size: '1.2 MB', validated: true),
    DocumentRecord(id: 3, name: 'Receita_Fonoaudiologia.pdf', type: 'Receitas', date: '10/02/2026', user: 'Dra. Paula Lima', origin: 'Saude', size: '89 KB', validated: true),
    DocumentRecord(id: 4, name: 'Exame_Audiometria.pdf', type: 'Exames', date: '05/02/2026', user: 'Lab. Santa Casa', origin: 'Saude', size: '456 KB', validated: false),
    DocumentRecord(id: 5, name: 'PEI_Lucas_2026.pdf', type: 'Relatorios', date: '01/04/2026', user: 'Prof. Carla Mendes', origin: 'Escola', size: '320 KB', validated: true),
    DocumentRecord(id: 6, name: 'Ficha_Observacao_Completa.pdf', type: 'Relatorios', date: '28/03/2026', user: 'Prof. Carla Mendes', origin: 'Escola', size: '198 KB', validated: true),
    DocumentRecord(id: 7, name: 'Guia_Encaminhamento_UBS.pdf', type: 'Encaminhamentos', date: '01/04/2026', user: 'Dra. Ana Silva', origin: 'Escola', size: '112 KB', validated: true),
    DocumentRecord(id: 8, name: 'Orientacoes_Familia.pdf', type: 'Outros', date: '25/03/2026', user: 'Dra. Ana Silva', origin: 'Escola', size: '67 KB', validated: false),
  ];

  static const referrals = [
    ReferralRecord(name: 'Lucas Oliveira', school: 'EM Monteiro Lobato', date: '01/04/2026', reason: 'Avaliacao multidisciplinar', status: 'Novo', priority: 'Media'),
    ReferralRecord(name: 'Maria Santos', school: 'EM Cecilia Meireles', date: '28/03/2026', reason: 'Fonoaudiologia', status: 'Em andamento', priority: 'Alta'),
    ReferralRecord(name: 'Pedro Costa', school: 'EM Castro Alves', date: '20/03/2026', reason: 'Neuropsicologia', status: 'Concluido', priority: 'Media'),
    ReferralRecord(name: 'Julia Lima', school: 'EM Drummond', date: '15/03/2026', reason: 'Terapia ocupacional', status: 'Aguardando', priority: 'Baixa'),
  ];

  static const timeline = [
    TimelineRecord(id: 1, title: 'Identificacao', date: '10/02/2026', time: '09:30', owner: 'Prof. Carla Mendes', summary: 'Observacao inicial de sinais durante atividades em grupo.', status: 'concluido', documents: ['Registro de observacao inicial']),
    TimelineRecord(id: 2, title: 'Preenchimento da ficha', date: '20/02/2026', time: '14:00', owner: 'Prof. Carla Mendes', summary: 'Ficha preenchida com marcos, potencialidades e sinais observados.', status: 'concluido', documents: ['Ficha de Observacao Completa']),
    TimelineRecord(id: 3, title: 'Validacao escolar', date: '28/02/2026', time: '10:00', owner: 'Dra. Ana Silva', summary: 'Coordenacao validou a ficha e elaborou o relatorio pedagogico.', status: 'concluido', documents: ['Relatorio Pedagogico', 'PEI']),
    TimelineRecord(id: 4, title: 'Encaminhamento', date: '01/04/2026', time: '11:00', owner: 'Dra. Ana Silva', summary: 'Encaminhamento realizado para UBS Centro.', status: 'concluido', documents: ['Guia de Encaminhamento']),
    TimelineRecord(id: 5, title: 'Recebimento pela familia', date: '02/04/2026', time: '16:00', owner: 'Familia Oliveira', summary: 'Familia recebeu notificacao e orientacoes iniciais.', status: 'concluido', documents: ['Carta de Orientacao']),
    TimelineRecord(id: 6, title: 'Acolhimento na saude', date: '10/04/2026', time: '09:00', owner: 'Dr. Marcos Pereira', summary: 'Acolhimento agendado na UBS Centro.', status: 'atual', documents: []),
    TimelineRecord(id: 7, title: 'Avaliacao', date: '-', time: '-', owner: '-', summary: 'Pendente realizacao da avaliacao multidisciplinar.', status: 'pendente', documents: []),
    TimelineRecord(id: 8, title: 'Inicio da terapia', date: '-', time: '-', owner: '-', summary: 'Aguardando definicao de conduta apos avaliacao.', status: 'pendente', documents: []),
    TimelineRecord(id: 9, title: 'Acompanhamento continuo', date: '-', time: '-', owner: '-', summary: 'Fase de acompanhamento entre escola, familia e saude.', status: 'pendente', documents: []),
  ];

  static const institutions = [
    InstitutionRecord(name: 'EM Monteiro Lobato', type: 'Escola', address: 'Rua das Acacias, 100', contact: '(11) 3333-0001', owner: 'Maria Souza', active: true),
    InstitutionRecord(name: 'EM Cecilia Meireles', type: 'Escola', address: 'Av. Central, 200', contact: '(11) 3333-0002', owner: 'Jose Santos', active: true),
    InstitutionRecord(name: 'UBS Centro', type: 'Unidade de Saude', address: 'Rua das Flores, 123', contact: '(11) 3333-1111', owner: 'Dr. Paulo Lima', active: true),
    InstitutionRecord(name: 'CAPS Infantil', type: 'Centro de Apoio', address: 'Av. Brasil, 456', contact: '(11) 3333-2222', owner: 'Dra. Lucia Ferreira', active: true),
    InstitutionRecord(name: 'Clinica Integrar', type: 'Clinica', address: 'Rua Harmonia, 789', contact: '(11) 3333-3333', owner: 'Dr. Roberto Alves', active: false),
  ];

  static const professionals = [
    ProfessionalRecord(name: 'Dra. Ana Silva', role: 'Coordenadora', area: 'Educacao', institution: 'EM Monteiro Lobato', profile: 'Escola', active: true),
    ProfessionalRecord(name: 'Prof. Carla Mendes', role: 'Professora', area: 'Educacao', institution: 'EM Monteiro Lobato', profile: 'Escola', active: true),
    ProfessionalRecord(name: 'Dr. Marcos Pereira', role: 'Pediatra', area: 'Saude', institution: 'UBS Centro', profile: 'Saude', active: true),
    ProfessionalRecord(name: 'Dra. Paula Lima', role: 'Fonoaudiologa', area: 'Saude', institution: 'CAPS Infantil', profile: 'Saude', active: true),
    ProfessionalRecord(name: 'Carlos Oliveira', role: 'Admin', area: 'TI', institution: 'Secretaria', profile: 'Administracao', active: true),
  ];

  static const familyStatus = <({String label, String value, String tone})>[
    (label: 'Etapa atual', value: 'Avaliacao multidisciplinar', tone: 'primary'),
    (label: 'Encaminhamento', value: 'Realizado em 01/04/2026', tone: 'success'),
    (label: 'Retorno da saude', value: 'Agendado para 10/04/2026', tone: 'warning'),
    (label: 'Pendencias', value: 'Nenhuma no momento', tone: 'success'),
    (label: 'Responsavel atual', value: 'Dra. Ana Silva', tone: 'foreground'),
  ];

  static const familyNetwork = <({String name, String type, String address, String phone, String hours})>[
    (name: 'UBS Centro', type: 'Atendimento primario', address: 'Rua das Flores, 123', phone: '(11) 3333-1111', hours: '7h - 17h'),
    (name: 'CAPS Infantil', type: 'Saude mental', address: 'Av. Brasil, 456', phone: '(11) 3333-2222', hours: '8h - 18h'),
    (name: 'Clinica Integrar', type: 'Multidisciplinar', address: 'Rua Harmonia, 789', phone: '(11) 3333-3333', hours: '8h - 20h'),
  ];

  static const adminUsers = <({String email, String profile, String lastAccess})>[
    (email: 'ana.silva@email.com', profile: 'Escola', lastAccess: '03/04/2026'),
    (email: 'carla.mendes@email.com', profile: 'Escola', lastAccess: '02/04/2026'),
    (email: 'marcos.pereira@email.com', profile: 'Saude', lastAccess: '01/04/2026'),
    (email: 'familia.oliveira@email.com', profile: 'Familia', lastAccess: '02/04/2026'),
    (email: 'admin@caminhoazul.com', profile: 'Administracao', lastAccess: '03/04/2026'),
  ];

  static const adminParameters = <({String title, List<String> items})>[
    (title: 'Tipos de status', items: ['Novo', 'Em andamento', 'Aguardando', 'Concluido', 'Cancelado']),
    (title: 'Categorias de documentos', items: ['Laudos', 'Receitas', 'Exames', 'Relatorios', 'Encaminhamentos', 'Outros']),
    (title: 'Perfis de acesso', items: ['Escola', 'Familia', 'Saude', 'Administracao']),
    (title: 'Regras de notificacao', items: ['Novo encaminhamento', 'Documento pendente', 'Retorno proximo', 'Atualizacao de caso']),
  ];

  static const reportMilestones = <({String area, String status, String description})>[
    (area: 'Linguagem', status: 'Em desenvolvimento', description: 'Vocabulario adequado, dificuldade em conversacao reciproca.'),
    (area: 'Interacao social', status: 'Requer atencao', description: 'Preferencia por atividades solitarias.'),
    (area: 'Atencao', status: 'Em desenvolvimento', description: 'Boa concentracao em areas de interesse.'),
    (area: 'Autonomia', status: 'Adequado', description: 'Realiza tarefas de autocuidado independentemente.'),
  ];

  static const reportStrengths = [
    'Excelente memoria visual e habilidade com quebra-cabecas',
    'Interesse intenso por numeros e padroes matematicos',
    'Capacidade de foco prolongado em atividades de interesse',
    'Boa relacao com a professora de referencia',
  ];

  static const reportSigns = [
    'Dificuldade em interacoes sociais reciprocas',
    'Sensibilidade auditiva moderada',
    'Comportamentos repetitivos em momentos de ansiedade',
    'Resistencia a mudancas na rotina escolar',
  ];
}
