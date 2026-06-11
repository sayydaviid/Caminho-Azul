import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/mock_data.dart';
import '../models/app_models.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';

class LinhaTempoScreen extends StatefulWidget {
  const LinhaTempoScreen({super.key});

  @override
  State<LinhaTempoScreen> createState() => _LinhaTempoScreenState();
}

class _LinhaTempoScreenState extends State<LinhaTempoScreen> {
  String filter = 'todos';
  int? expanded = 6;

  @override
  Widget build(BuildContext context) {
    final items = filter == 'todos' ? MockData.timeline : MockData.timeline.where((item) => item.status == filter).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(
          title: 'Linha do Tempo',
          subtitle: 'Lucas Oliveira - EM Monteiro Lobato\nUltima atualizacao: 03/04/2026',
          trailing: StatusBadge(label: 'Acolhimento', tone: 'primary'),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'todos', label: Text('Todos')),
              ButtonSegment(value: 'concluido', label: Text('Concluidos')),
              ButtonSegment(value: 'atual', label: Text('Atual')),
              ButtonSegment(value: 'pendente', label: Text('Pendentes')),
            ],
            selected: {filter},
            onSelectionChanged: (value) => setState(() => filter = value.first),
          ),
        ),
        const SizedBox(height: 20),
        ...items.map((item) => _TimelineItem(
              item: item,
              expanded: expanded == item.id,
              onTap: () => setState(() => expanded = expanded == item.id ? null : item.id),
            )),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.item, required this.expanded, required this.onTap});

  final TimelineRecord item;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.status) {
      'concluido' => AppColors.success,
      'atual' => AppColors.primary,
      _ => AppColors.muted,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(_icon(item.id), color: color, size: 18),
            ),
            Container(width: 2, height: expanded ? 170 : 95, color: item.status == 'concluido' ? AppColors.success : AppColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: item.status == 'atual' ? const Color(0xFFF4F8FF) : Colors.white,
                  border: Border.all(color: item.status == 'atual' ? const Color(0xFFBFDBFE) : AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                        if (item.status == 'pendente') const Icon(Icons.error_outline, size: 17, color: AppColors.warning),
                        Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.muted),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.date == '-' ? item.owner : '${item.date} - ${item.time} | ${item.owner}', style: Theme.of(context).textTheme.bodySmall),
                    if (expanded) ...[
                      const Divider(height: 24),
                      Text(item.summary, style: const TextStyle(color: AppColors.muted, height: 1.5)),
                      if (item.documents.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: item.documents.map((document) => StatusBadge(label: document, icon: Icons.description_outlined)).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _icon(int id) {
    return const [
      Icons.visibility_outlined,
      Icons.assignment_outlined,
      Icons.check_circle_outline,
      Icons.send_outlined,
      Icons.favorite_outline,
      Icons.medical_services_outlined,
      Icons.psychology_outlined,
      Icons.play_arrow_outlined,
      Icons.refresh_outlined,
    ][id - 1];
  }
}
