import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/mock_data.dart';
import '../widgets/custom_button.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';

class RelatorioScreen extends StatelessWidget {
  const RelatorioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(
          title: 'Relatorio Pedagogico',
          subtitle: 'Lucas Oliveira - Emitido em 03/04/2026',
          trailing: StatusBadge(label: 'Finalizado', tone: 'success', icon: Icons.check_circle_outline),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Text('Relatorio Pedagogico', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary)),
                    const Text('Sistema Caminho Azul', style: TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              const Divider(height: 34),
              const _ReportSection(
                title: '1. Identificacao do Aluno',
                child: Column(
                  children: [
                    _ReportField('Nome', 'Lucas Oliveira'),
                    _ReportField('Data de nascimento', '15/06/2019'),
                    _ReportField('Escola', 'EM Monteiro Lobato'),
                    _ReportField('Turma', '2o ano B - Matutino'),
                    _ReportField('Professor', 'Prof. Carla Mendes'),
                    _ReportField('Data do relatorio', '03/04/2026'),
                  ],
                ),
              ),
              const _ReportSection(
                title: '2. Contexto Escolar',
                child: Text(
                  'Lucas frequenta a escola regularmente, com presenca de 92% no periodo avaliado. Demonstra boa adaptacao, mas apresenta dificuldades em atividades de interacao social em grupo.',
                  style: _reportText,
                ),
              ),
              const _ReportSection(
                title: '3. Sintese das Observacoes',
                child: Text(
                  'Foram identificados preferencia por atividades individuais, dificuldade em transicoes e resposta intensa a estimulos sonoros.',
                  style: _reportText,
                ),
              ),
              const _ReportSection(
                title: '4. Marcos do Desenvolvimento',
                child: _ReportMilestones(),
              ),
              const _ReportSection(
                title: '5. Potencialidades',
                child: _BulletList(items: MockData.reportStrengths),
              ),
              const _ReportSection(
                title: '6. Sinais Identificados',
                child: _BulletList(items: MockData.reportSigns),
              ),
              const _ReportSection(
                title: '7. Recomendacao de Encaminhamento',
                child: AppCard(
                  color: Color(0xFFF4F8FF),
                  child: Text(
                    'Prioridade: Media\n\nRecomenda-se encaminhamento para avaliacao multidisciplinar, com foco em avaliacao neuropsicologica e fonoaudiologica.',
                    style: _reportText,
                  ),
                ),
              ),
              const Divider(height: 34),
              const Center(
                child: Text(
                  'Documento gerado pelo sistema Caminho Azul em 03/04/2026\nResponsavel: Dra. Ana Silva - Coordenacao Escolar',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Acoes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CustomButton(label: 'Exportar PDF', icon: Icons.download_outlined, onPressed: () {}),
                  CustomButton(label: 'Editar relatorio', icon: Icons.edit_outlined, onPressed: () {}),
                  CustomButton(label: 'Compartilhar', icon: Icons.share_outlined, onPressed: () {}),
                  CustomButton(label: 'Enviar para familia', icon: Icons.send_outlined, primary: true, onPressed: () {}),
                  CustomButton(label: 'Anexar documento', icon: Icons.attach_file, onPressed: () {}),
                  CustomButton(label: 'Imprimir', icon: Icons.print_outlined, onPressed: () {}),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Anexos', style: Theme.of(context).textTheme.titleMedium),
              const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.description_outlined, color: AppColors.primary), title: Text('PEI_Lucas_2026.pdf'), subtitle: Text('PEI - 01/04/2026')),
              const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.description_outlined, color: AppColors.primary), title: Text('PEE_Monteiro_Lobato.pdf'), subtitle: Text('PEE - 15/03/2026')),
              const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.description_outlined, color: AppColors.primary), title: Text('Ficha_Complementar.pdf'), subtitle: Text('Ficha - 28/03/2026')),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

const _reportText = TextStyle(color: AppColors.muted, height: 1.7, fontSize: 14);

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ReportField extends StatelessWidget {
  const _ReportField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text('$label:', style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow(this.area, this.status, this.description);

  final String area;
  final String status;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(area, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          StatusBadge(label: status, tone: status),
          const SizedBox(height: 6),
          Text(description, style: _reportText),
        ],
      ),
    );
  }
}

class _ReportMilestones extends StatelessWidget {
  const _ReportMilestones();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: MockData.reportMilestones
          .map((item) => _MilestoneRow(item.area, item.status, item.description))
          .toList(),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('-  ', style: _reportText), Expanded(child: Text(item, style: _reportText))]),
              ))
          .toList(),
    );
  }
}
