// lib/presentation/screens/common/notificaciones_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/notification_repository.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _repo = NotificationRepository.instance;

  List<Map<String, dynamic>> _notificaciones = [];
  int _noLeidas = 0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final results = await Future.wait([
      _repo.getNotificaciones(),
      _repo.getResumen(),
    ]);
    if (!mounted) return;
    setState(() {
      _notificaciones = results[0] as List<Map<String, dynamic>>;
      final resumen = results[1] as Map<String, dynamic>;
      _noLeidas = resumen['no_leidas'] as int? ?? 0;
      _cargando = false;
    });
  }

  Future<void> _marcarLeida(int id) async {
    await _repo.marcarLeida(id);
    setState(() {
      _notificaciones = _notificaciones.map((n) {
        if (n['id'] == id) return {...n, 'leida': true};
        return n;
      }).toList();
      _noLeidas = (_noLeidas - 1).clamp(0, 9999);
    });
  }

  Future<void> _marcarTodasLeidas() async {
    await _repo.marcarTodasLeidas();
    setState(() {
      _notificaciones = _notificaciones.map((n) => {...n, 'leida': true}).toList();
      _noLeidas = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notificaciones'),
            if (_noLeidas > 0)
              Text('$_noLeidas sin leer',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          if (_noLeidas > 0)
            TextButton(
              onPressed: _marcarTodasLeidas,
              child: const Text('Leer todas',
                  style: TextStyle(color: AppColors.primaryPurple)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _notificaciones.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notificaciones.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) => _buildItem(_notificaciones[i]),
                  ),
                ),
    );
  }

  Widget _buildItem(Map<String, dynamic> n) {
    final tipo     = n['tipo'] as String? ?? '';
    final titulo   = n['titulo'] as String? ?? '';
    final mensaje  = n['mensaje'] as String? ?? '';
    final leida    = n['leida'] as bool? ?? false;
    final fechaStr = n['fecha_creacion'] as String? ?? '';
    final id       = n['id'] as int?;

    final config = _tipoConfig(tipo);

    return InkWell(
      onTap: id != null && !leida ? () => _marcarLeida(id) : null,
      child: Container(
        color: leida ? null : config.color.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(config.icon, color: config.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(titulo,
                    style: AppTextStyles.subtitle1.copyWith(
                        fontWeight: leida ? FontWeight.normal : FontWeight.bold))),
                if (!leida)
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: config.color, shape: BoxShape.circle),
                  ),
              ]),
              if (mensaje.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(mensaje, style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary, height: 1.4)),
              ],
              if (fechaStr.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(_formatFecha(fechaStr),
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary, fontSize: 11)),
              ],
            ],
          )),
        ]),
      ),
    );
  }

  _TipoConfig _tipoConfig(String tipo) {
    switch (tipo) {
      case 'match':
        return _TipoConfig(Icons.favorite, AppColors.accentGreen);
      case 'like_recibido':
        return _TipoConfig(Icons.thumb_up_outlined, AppColors.primaryPurple);
      case 'postulacion_estado':
        return _TipoConfig(Icons.work_outline, AppColors.accentBlue);
      default:
        return _TipoConfig(Icons.notifications_outlined, AppColors.textSecondary);
    }
  }

  Widget _buildEmpty() => ListView(children: [
    SizedBox(height: 420, child: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.08),
              shape: BoxShape.circle),
          child: Icon(Icons.notifications_none,
              size: 56, color: AppColors.primaryPurple.withOpacity(0.5))),
        const SizedBox(height: 20),
        Text('Sin notificaciones',
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Las notificaciones de matches, likes y cambios de estado aparecerán aquí.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center),
      ]),
    ))),
  ]);

  String _formatFecha(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'Ahora';
      if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
      if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
      if (diff.inDays == 1) return 'Ayer';
      const m = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
      return '${d.day} ${m[d.month-1]}';
    } catch (_) { return ''; }
  }
}

class _TipoConfig {
  final IconData icon;
  final Color color;
  const _TipoConfig(this.icon, this.color);
}
