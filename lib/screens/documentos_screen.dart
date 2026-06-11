import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/mock_data.dart';
import '../models/app_models.dart';
import '../widgets/custom_button.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  static const categories = ['Todos', 'Laudos', 'Receitas', 'Exames', 'Relatorios', 'Encaminhamentos', 'Outros'];
  String category = 'Todos';
  String query = '';
  bool gridMode = false;

  @override
  Widget build(BuildContext context) {
    final filtered = MockData.documents.where((item) => item.matches(category, query)).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'Portfolio de Documentos',
          subtitle: 'Lucas Oliveira - ${MockData.documents.length} documentos',
        ),
        const SizedBox(height: 14),
        CustomButton(label: 'Anexar documento', icon: Icons.upload_file_outlined, primary: true, fullWidth: true, onPressed: () {}),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((item) {
              return Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  label: Text(item),
                  selected: category == item,
                  onSelected: (_) => setState(() => category = item),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  hintText: 'Buscar documento...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.view_list_outlined)),
                ButtonSegment(value: true, icon: Icon(Icons.grid_view_outlined)),
              ],
              selected: {gridMode},
              showSelectedIcon: false,
              onSelectionChanged: (value) => setState(() => gridMode = value.first),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (gridMode)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.68,
            ),
            itemBuilder: (_, index) => _DocumentCard(item: filtered[index]),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: filtered.map((item) => _DocumentTile(item: item)).toList()),
          ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Nenhum documento encontrado.', style: TextStyle(color: AppColors.muted))),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.item});

  final DocumentRecord item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFDBEAFE),
        child: Icon(Icons.description_outlined, color: AppColors.primary),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item.type} - ${item.user}\n${item.date} - ${item.size}'),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'view', child: Text('Visualizar')),
          PopupMenuItem(value: 'download', child: Text('Baixar')),
          PopupMenuItem(value: 'share', child: Text('Compartilhar')),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.item});

  final DocumentRecord item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFDBEAFE),
            child: Icon(Icons.description_outlined, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text('${item.type} - ${item.size}', style: Theme.of(context).textTheme.bodySmall),
          Text(item.user, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          StatusBadge(label: item.validated ? 'Validado' : 'Pendente', tone: item.validated ? 'success' : 'warning'),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(onPressed: () {}, tooltip: 'Visualizar', icon: const Icon(Icons.visibility_outlined, size: 19)),
              IconButton(onPressed: () {}, tooltip: 'Baixar', icon: const Icon(Icons.download_outlined, size: 19)),
            ],
          ),
        ],
      ),
    );
  }
}
