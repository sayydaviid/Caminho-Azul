import 'dart:async';

import 'package:flutter/material.dart';

import '../app/router.dart';
import '../repositories/notification_repository.dart';

/// Ícone da central de notificações da família (N-02) com o contador de não
/// lidas em tempo real. Com o app aberto, uma notificação nova também exibe
/// um aviso discreto (sem conteúdo do caso).
class NotificationBell extends StatefulWidget {
  const NotificationBell({
    required this.repository,
    required this.studentId,
    super.key,
  });

  final NotificationRepository repository;
  final String studentId;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  StreamSubscription<int>? _subscription;
  int? _count;

  @override
  void initState() {
    super.initState();
    _subscription =
        widget.repository.watchUnreadCount(widget.studentId).listen((count) {
      final previous = _count;
      if (!mounted) return;
      setState(() => _count = count);
      if (previous != null && count > previous) {
        ScaffoldMessenger.maybeOf(context)
          ?..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: const Text(
                'Uma nova atualização está disponível no acompanhamento.'),
            action: SnackBarAction(
              label: 'Ver',
              onPressed: () => Navigator.pushReplacementNamed(
                  context, AppRoutes.notifications),
            ),
          ));
      }
    }, onError: (_) {
      if (mounted) setState(() => _count = null);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _count ?? 0;
    final label = count == 0
        ? 'Notificações'
        : count == 1
            ? 'Notificações, 1 não lida'
            : 'Notificações, ${count > unreadCountCap ? '$unreadCountCap ou mais' : count} não lidas';
    return IconButton(
      key: const Key('notification-bell'),
      tooltip: label,
      onPressed: () {
        if (ModalRoute.of(context)?.settings.name == AppRoutes.notifications) {
          return;
        }
        Navigator.pushReplacementNamed(context, AppRoutes.notifications);
      },
      icon: Badge(
        isLabelVisible: count > 0,
        // P2-03: branco sobre vermelho escuro (contraste ≥ 4,5:1).
        backgroundColor: const Color(0xFFB91C1C),
        textColor: Colors.white,
        label: Text(count > unreadCountCap ? '$unreadCountCap+' : '$count',
            key: const Key('notification-count')),
        child: Icon(count > 0
            ? Icons.notifications_active_outlined
            : Icons.notifications_outlined),
      ),
    );
  }
}
