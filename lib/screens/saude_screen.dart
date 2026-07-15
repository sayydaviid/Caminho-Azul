import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/mock_data.dart';
import '../models/app_models.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';

class SaudeScreen extends StatefulWidget {
  const SaudeScreen({super.key});

  @override
  State<SaudeScreen> createState() => _SaudeScreenState();
}

class _SaudeScreenState extends State<SaudeScreen> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final current = MockData.referrals[selected];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(
            title: 'Painel da Saude',
            subtitle: 'Encaminhamentos, prontuario e contrarreferencia'),
        const SizedBox(height: 16),
        _HealthSection(
          title: 'Encaminhamentos recebidos',
          child: Column(
            children: [
              for (var index = 0; index < MockData.referrals.length; index++)
                _ReferralTile(
                  item: MockData.referrals[index],
                  selected: index == selected,
                  onTap: () => setState(() => selected = index),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _HealthSection(
          title: 'Prontuario pedagogico - ${current.name}',
          child: const Column(
            children: [
              _SummaryBox(
                icon: Icons.school_outlined,
                title: 'Sintese pedagogica',
                text:
                    'Frequencia regular e boa adaptacao, com dificuldades em interacoes sociais em grupo e sensibilidade sonora.',
              ),
              _SummaryBox(
                icon: Icons.star_outline,
                title: 'Potencialidades',
                text:
                    'Excelente memoria visual, interesse por numeros e capacidade de foco prolongado.',
              ),
              _SummaryBox(
                icon: Icons.warning_amber_outlined,
                title: 'Sinais observados',
                text:
                    'Dificuldade em interacoes reciprocas, sensibilidade auditiva e resistencia a mudancas.',
              ),
              _SummaryBox(
                icon: Icons.description_outlined,
                title: 'Documentos',
                text: 'Relatorio Pedagogico, Ficha de Observacao e PEI.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _HealthSection(
          title: 'Contrarreferencia',
          child: Column(
            children: [
              _ChoiceField(label: 'Acolhimento realizado?'),
              SizedBox(height: 12),
              CustomInput(
                  label: 'Conduta adotada', hint: 'Selecione a conduta'),
              SizedBox(height: 12),
              CustomInput(label: 'Observacoes do profissional', maxLines: 4),
              SizedBox(height: 12),
              CustomInput(label: 'Devolutiva para escola/familia', maxLines: 4),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _HealthSection(
          title: 'Inicio de terapia',
          child: Column(
            children: [
              _ChoiceField(label: 'Terapia iniciada?'),
              SizedBox(height: 12),
              CustomInput(
                  label: 'Data de inicio', icon: Icons.calendar_today_outlined),
              SizedBox(height: 12),
              CustomInput(
                  label: 'Tipo de atendimento',
                  hint: 'Fonoaudiologia, TO, Psicologia...'),
              SizedBox(height: 12),
              CustomInput(label: 'Frequencia', hint: 'Semanal'),
              SizedBox(height: 12),
              CustomInput(label: 'Orientacoes gerais', maxLines: 4),
              SizedBox(height: 12),
              CustomInput(label: 'Profissional responsavel'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _HealthSection(
          title: 'Resumo do caso',
          child: Column(
            children: [
              _InfoRow(Icons.person_outline, current.name),
              _InfoRow(Icons.school_outlined, current.school),
              _InfoRow(Icons.schedule_outlined, current.date),
              _InfoRow(Icons.error_outline, current.reason),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CustomButton(
                label: 'Solicitar informacoes',
                icon: Icons.chat_bubble_outline,
                onPressed: () {}),
            CustomButton(
                label: 'Anexar documento',
                icon: Icons.attach_file,
                onPressed: () {}),
            CustomButton(
                label: 'Registrar retorno',
                icon: Icons.send_outlined,
                primary: true,
                onPressed: () {}),
            CustomButton(
                label: 'Atualizar status',
                icon: Icons.refresh,
                onPressed: () {}),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _HealthSection extends StatelessWidget {
  const _HealthSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ReferralTile extends StatelessWidget {
  const _ReferralTile(
      {required this.item, required this.selected, required this.onTap});

  final ReferralRecord item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFF4F8FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          title: Text(item.name,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${item.school}\n${item.reason} - ${item.date}'),
          isThreeLine: true,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(label: item.status, tone: item.status),
              const SizedBox(height: 5),
              StatusBadge(label: item.priority, tone: item.priority),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox(
      {required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: AppColors.secondary, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700))
          ]),
          const SizedBox(height: 7),
          Text(text,
              style: const TextStyle(color: AppColors.muted, height: 1.5)),
        ],
      ),
    );
  }
}

class _ChoiceField extends StatefulWidget {
  const _ChoiceField({required this.label});

  final String label;

  @override
  State<_ChoiceField> createState() => _ChoiceFieldState();
}

class _ChoiceFieldState extends State<_ChoiceField> {
  String value = 'Sim';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Sim', label: Text('Sim')),
            ButtonSegment(value: 'Nao', label: Text('Nao'))
          ],
          selected: {value},
          onSelectionChanged: (next) => setState(() => value = next.first),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text))
      ]),
    );
  }
}
