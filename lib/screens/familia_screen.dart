import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/mock_data.dart';
import '../widgets/custom_button.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/status_badge.dart';

class FamiliaScreen extends StatelessWidget {
  const FamiliaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.person_outline,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text('Lucas Oliveira',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text('6 anos - EM Monteiro Lobato - 2o ano B',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 10),
              const StatusBadge(label: 'Em avaliacao'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _FamilySection(
          icon: Icons.check_circle_outline,
          title: 'Status do acompanhamento',
          child: Column(
            children: MockData.familyStatus
                .map((item) =>
                    _StatusRow(item.label, item.value, _tone(item.tone)))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _FamilySection(
          icon: Icons.notifications_outlined,
          title: 'Notificacoes',
          child: Column(
            children: MockData.familyNotices
                .map(
                  (notice) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle,
                        size: 10, color: AppColors.primary),
                    title: Text(notice.text,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(notice.date),
                    onTap: () {},
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _FamilySection(
          icon: Icons.description_outlined,
          title: 'Documentos',
          child: Column(
            children: MockData.documents.take(4).map((document) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined,
                    color: AppColors.primary),
                title: Text(document.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${document.type} - ${document.date}'),
                trailing: const Icon(Icons.download_outlined),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _FamilySection(
          icon: Icons.location_on_outlined,
          title: 'Rede de assistencia',
          child: Column(
            children: MockData.familyNetwork
                .map((item) => _NetworkCard(
                    item.name, item.type, item.address, item.phone, item.hours))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CustomButton(
                label: 'Enviar documentos',
                icon: Icons.upload_file_outlined,
                onPressed: () {}),
            CustomButton(
                label: 'Atualizar dados',
                icon: Icons.refresh,
                onPressed: () {}),
            CustomButton(
                label: 'Tirar duvidas',
                icon: Icons.chat_bubble_outline,
                onPressed: () {}),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  static Color _tone(String value) {
    return switch (value) {
      'success' => AppColors.success,
      'warning' => AppColors.warning,
      'primary' => AppColors.primary,
      _ => AppColors.foreground,
    };
  }
}

class _FamilySection extends StatelessWidget {
  const _FamilySection(
      {required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 21),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child:
                  Text(label, style: const TextStyle(color: AppColors.muted))),
          const SizedBox(width: 12),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard(
      this.name, this.type, this.address, this.phone, this.hours);

  final String name;
  final String type;
  final String address;
  final String phone;
  final String hours;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(type,
              style: const TextStyle(color: AppColors.primary, fontSize: 12)),
          const SizedBox(height: 7),
          Text(address, style: const TextStyle(color: AppColors.muted)),
          Text('$phone - $hours',
              style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
