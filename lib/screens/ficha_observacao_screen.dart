import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';

class FichaObservacaoScreen extends StatelessWidget {
  const FichaObservacaoScreen({super.key});

  static const milestones = [
    'Linguagem e comunicacao',
    'Interacao social',
    'Atencao e concentracao',
    'Autonomia',
    'Coordenacao motora',
    'Comportamento em sala',
    'Resposta a estimulos',
    'Rotina e adaptacao',
  ];

  static const signs = [
    'Dificuldade de comunicacao',
    'Pouca interacao social',
    'Sensibilidade a sons, luzes ou toque',
    'Repeticao de comportamentos',
    'Resistencia a mudancas',
    'Seletividade alimentar',
    'Dificuldades emocionais',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(
          title: 'Ficha de Observacao',
          subtitle: 'Lucas Oliveira - EM Monteiro Lobato - 2o ano B',
          trailing: StatusBadge(label: 'Rascunho', tone: 'warning'),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(
                      child: Text('Progresso do preenchimento',
                          style: TextStyle(color: AppColors.muted))),
                  Text('35%', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child:
                      const LinearProgressIndicator(value: 0.35, minHeight: 8)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _ObservationSection(
          title: '1. Identificacao basica',
          icon: Icons.person_outline,
          initiallyExpanded: true,
          child: Column(
            children: [
              CustomInput(label: 'Nome do aluno', hint: 'Lucas Oliveira'),
              SizedBox(height: 12),
              CustomInput(
                  label: 'Data de nascimento',
                  hint: '15/06/2019',
                  icon: Icons.calendar_today_outlined),
              SizedBox(height: 12),
              CustomInput(label: 'Turma', hint: '2o ano B'),
              SizedBox(height: 12),
              CustomInput(label: 'Escola', hint: 'EM Monteiro Lobato'),
              SizedBox(height: 12),
              CustomInput(
                  label: 'Professor responsavel', hint: 'Prof. Carla Mendes'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ObservationSection(
          title: '2. Marcos do desenvolvimento',
          icon: Icons.psychology_outlined,
          child: Column(
              children:
                  milestones.map((item) => _Milestone(label: item)).toList()),
        ),
        const SizedBox(height: 12),
        const _ObservationSection(
          title: '3. Potencialidades',
          icon: Icons.star_outline,
          child: Column(
            children: [
              CustomInput(
                  label: 'Habilidades cognitivas percebidas', maxLines: 3),
              SizedBox(height: 12),
              CustomInput(label: 'Interesses especificos', maxLines: 3),
              SizedBox(height: 12),
              CustomInput(label: 'Facilidades de aprendizagem', maxLines: 3),
              SizedBox(height: 12),
              CustomInput(label: 'Talentos observados', maxLines: 3),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ObservationSection(
          title: '4. Sinais observados',
          icon: Icons.warning_amber_outlined,
          child: Column(
            children: [
              ...signs.map((item) => _ToggleCheck(label: item)),
              const SizedBox(height: 8),
              const CustomInput(label: 'Outros sinais observados', maxLines: 3),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _ObservationSection(
          title: '5. Contexto escolar',
          icon: Icons.school_outlined,
          child: Column(
            children: [
              CustomInput(label: 'Frequencia', hint: 'Regular'),
              SizedBox(height: 12),
              CustomInput(label: 'Participacao em atividades', maxLines: 3),
              SizedBox(height: 12),
              CustomInput(label: 'Relacao com colegas', maxLines: 3),
              SizedBox(height: 12),
              CustomInput(
                  label: 'Observacoes do ambiente escolar', maxLines: 3),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _ObservationSection(
          title: '6. Encaminhamento sugerido',
          icon: Icons.send_outlined,
          child: Column(
            children: [
              CustomInput(
                  label: 'Necessidade de encaminhamento', hint: 'A avaliar'),
              SizedBox(height: 12),
              CustomInput(label: 'Prioridade', hint: 'Media'),
              SizedBox(height: 12),
              CustomInput(label: 'Justificativa pedagogica', maxLines: 4),
              SizedBox(height: 12),
              CustomInput(label: 'Observacoes complementares', maxLines: 4),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CustomButton(
            label: 'Anexar arquivo',
            icon: Icons.attach_file,
            fullWidth: true,
            onPressed: () {}),
        const SizedBox(height: 8),
        CustomButton(
            label: 'Salvar rascunho',
            icon: Icons.save_outlined,
            fullWidth: true,
            onPressed: () {}),
        const SizedBox(height: 8),
        CustomButton(
            label: 'Finalizar preenchimento',
            icon: Icons.check_circle_outline,
            primary: true,
            fullWidth: true,
            onPressed: () {}),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ObservationSection extends StatelessWidget {
  const _ObservationSection(
      {required this.title,
      required this.icon,
      required this.child,
      this.initiallyExpanded = false});

  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);

    return Material(
      color: Colors.white,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: borderRadius,
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFDBEAFE),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          children: [
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      ),
    );
  }
}

class _Milestone extends StatefulWidget {
  const _Milestone({required this.label});

  final String label;

  @override
  State<_Milestone> createState() => _MilestoneState();
}

class _MilestoneState extends State<_Milestone> {
  String value = 'Em desenvolvimento';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.secondary, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: value,
            items: ['Adequado', 'Em desenvolvimento', 'Requer atencao']
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (next) => setState(() => value = next ?? value),
          ),
          const SizedBox(height: 8),
          const TextField(
              decoration: InputDecoration(hintText: 'Observacoes...'),
              maxLines: 2),
        ],
      ),
    );
  }
}

class _ToggleCheck extends StatefulWidget {
  const _ToggleCheck({required this.label});

  final String label;

  @override
  State<_ToggleCheck> createState() => _ToggleCheckState();
}

class _ToggleCheckState extends State<_ToggleCheck> {
  bool value = false;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(widget.label, style: const TextStyle(fontSize: 14)),
      onChanged: (next) => setState(() => value = next ?? false),
    );
  }
}
