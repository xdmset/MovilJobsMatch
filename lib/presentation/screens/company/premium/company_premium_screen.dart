// lib/presentation/screens/company/premium/company_premium_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../../data/repositories/paypal_repository.dart';

class CompanyPremiumScreen extends StatefulWidget {
  const CompanyPremiumScreen({super.key});
  @override
  State<CompanyPremiumScreen> createState() => _CompanyPremiumScreenState();
}

class _CompanyPremiumScreenState extends State<CompanyPremiumScreen>
    with WidgetsBindingObserver {
  final _repo = PaypalRepository.instance;

  List<Map<String, dynamic>> _planes = [];
  Map<String, dynamic>? _planSel;
  Map<String, dynamic>? _suscripcionActual;
  bool _cargando = true;
  bool _procesando = false;
  String? _error;
  String? _pendingId;

  static const _returnUrl =
      'jobmatch://paypal-success';
  static const _cancelUrl =
      'jobmatch://paypal-cancel';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingId != null) {
      debugPrint('[PayPal] App resumed con pendingId empresa: $_pendingId');
      _sync();
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pending_paypal_sub_id_empresa');
    if (saved != null) setState(() => _pendingId = saved);

    await Future.wait([_cargarPlanes(), _cargarSuscripcion()]);

    if (mounted && context.read<AuthProvider>().esPremium) {
      _limpiarPendiente();
    }
  }

  Future<void> _cargarPlanes() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final todos = await _repo.getPlanes();
      debugPrint('[PayPal] Total planes recibidos empresa: ${todos.length}');

      // FIX: Filtrar planes para empresa — campo 'rol_objetivo'
      List<Map<String, dynamic>> planesEmpresa;

      final tieneRolObjetivo = todos.any((p) => p['rol_objetivo'] != null);

      if (tieneRolObjetivo) {
        planesEmpresa = todos.where((p) {
          final rol = (p['rol_objetivo'] ?? '').toString().toLowerCase();
          return rol.contains('empresa');
        }).toList();
      } else {
        // /plans/me ya filtró por rol, usar todos
        planesEmpresa = todos;
      }

      debugPrint('[PayPal] Planes empresa filtrados: ${planesEmpresa.length}');

      setState(() {
        if (planesEmpresa.isNotEmpty) {
          _planes = planesEmpresa;
          // Ordenar: mensual → semestral → anual
          _planes.sort((a, b) {
            const orden = ['mensual', 'semestral', 'anual'];
            return orden.indexOf(_billingCycle(a))
                .compareTo(orden.indexOf(_billingCycle(b)));
          });
          _planSel = _planes.firstWhere(
            (p) => _billingCycle(p) == 'mensual',
            orElse: () => _planes.first,
          );
        } else if (todos.isNotEmpty) {
          debugPrint('[PayPal] ⚠️ No se encontraron planes con rol_objetivo=empresa, usando todos');
          _planes = todos;
          _planSel = todos.first;
        } else {
          _error = 'No hay planes disponibles.\nContacta soporte si el problema persiste.';
        }
        _cargando = false;
      });
    } catch (e) {
      debugPrint('[PayPal] Error al cargar planes empresa: $e');
      setState(() {
        _error = 'Error al cargar planes. Verifica tu conexión.';
        _cargando = false;
      });
    }
  }

  Future<void> _cargarSuscripcion() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    try {
      final sub = await _repo.getSuscripcionActual(userId);
      if (mounted) setState(() => _suscripcionActual = sub);
    } catch (_) {}
  }

  Future<void> _limpiarPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_paypal_sub_id_empresa');
    if (mounted) setState(() => _pendingId = null);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // FIX: ya NO usa p['id'] como fallback (causaba que todos dieran 'mensual')
  String _billingCycle(Map<String, dynamic> p) {
    final candidates = [
      p['periodicidad'],
      p['codigo'],
      p['plan_code'],
      p['code'],
      p['nombre'],
    ].whereType<String>().map((s) => s.toLowerCase());

    for (final val in candidates) {
      if (val.contains('semestral')) return 'semestral';
      if (val.contains('anual'))     return 'anual';
      if (val.contains('mensual'))   return 'mensual';
    }
    return 'mensual';
  }

  String _nombrePlan(Map<String, dynamic> p) {
    switch (_billingCycle(p)) {
      case 'mensual':   return 'Mensual';
      case 'semestral': return 'Semestral';
      case 'anual':     return 'Anual';
      default:          return p['nombre']?.toString() ?? 'Plan';
    }
  }

  String _precioFormateado(Map<String, dynamic> p) {
    final precio = p['precio'] ?? p['price'] ?? p['amount'] ?? '0';
    final moneda = p['moneda'] ?? p['currency'] ?? 'MXN';
    final sufijos = {'mensual': '/mes', 'semestral': '/6 meses', 'anual': '/año'};
    final sufijo = sufijos[_billingCycle(p)] ?? '/mes';
    return '\$$precio $moneda$sufijo';
  }

  String? get _paypalSubId {
    final sub = _suscripcionActual;
    if (sub == null) return null;
    return sub['paypal_subscription_id'] as String?
        ?? sub['suscripcion']?['paypal_subscription_id'] as String?;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final esPremium = context.watch<AuthProvider>().esPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JobMatch Business'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop()),
        actions: [
          if (_pendingId != null && !esPremium)
            TextButton.icon(
              onPressed: _procesando ? null : _sync,
              icon: const Icon(Icons.sync,
                  color: AppColors.accentGreen, size: 18),
              label: const Text('Verificar',
                  style: TextStyle(color: AppColors.accentGreen,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          _buildHeader(esPremium),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [

              if (_pendingId != null && !esPremium) _buildSyncBanner(),

              if (!esPremium) ...[
                if (_cargando)
                  const Padding(padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          color: AppColors.accentBlue))
                else if (_error != null)
                  _buildError()
                else if (_planes.isNotEmpty) ...[
                  _buildPlanTabs(),
                  const SizedBox(height: 16),
                  if (_planSel != null) _buildPrecioCard(),
                ],
              ],

              const SizedBox(height: 16),
              _buildBeneficios(esPremium),
              const SizedBox(height: 24),

              if (!esPremium && !_cargando && _error == null)
                _buildBotonPago(),

              if (esPremium) ...[
                _buildActivoBanner(),
                const SizedBox(height: 16),
                _buildBotonCancelar(),
              ],

              const SizedBox(height: 32),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader(bool esPremium) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 36, 24, 44),
    decoration: BoxDecoration(
      gradient: LinearGradient(
          colors: [AppColors.accentBlue, AppColors.accentBlue.withBlue(220)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
        child: Icon(
            esPremium ? Icons.business_center : Icons.business_center_outlined,
            color: Colors.white, size: 44),
      ),
      const SizedBox(height: 16),
      Text(esPremium ? '¡Business Activo! 🚀' : 'JobMatch Business',
          style: AppTextStyles.h2.copyWith(color: Colors.white)),
      const SizedBox(height: 8),
      Text(
        esPremium
            ? 'Tu empresa tiene acceso completo a JobMatch'
            : 'Accede a candidatos ilimitados y herramientas avanzadas',
        style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withOpacity(0.85)),
        textAlign: TextAlign.center,
      ),
    ]),
  );

  Widget _buildSyncBanner() => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.4))),
    child: Row(children: [
      const Icon(Icons.pending_outlined, color: Colors.amber),
      const SizedBox(width: 10),
      const Expanded(
        child: Text(
          'Pago pendiente de verificación. Toca "Verificar" después de completar el pago en PayPal.',
          style: TextStyle(color: Colors.amber, fontSize: 13),
        ),
      ),
    ]),
  );

  Widget _buildPlanTabs() => Row(children: _planes.map((p) {
    final sel = _planSel == p;
    return Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => setState(() => _planSel = p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: sel ? AppColors.accentBlue : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? AppColors.accentBlue : AppColors.borderLight)),
          child: Text(_nombrePlan(p),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: sel ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
      ),
    ));
  }).toList());

  Widget _buildPrecioCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_precioFormateado(_planSel!),
          style: AppTextStyles.h2.copyWith(color: AppColors.accentBlue)),
    ]),
  );

  Widget _buildBeneficios(bool esPremium) {
    final items = [
      (Icons.people_alt, 'Candidatos ilimitados',
          'Sin límite de perfiles por vacante'),
      (Icons.work_outline, 'Vacantes ilimitadas',
          'Publica todas las plazas que necesites'),
      (Icons.analytics, 'Analítica avanzada',
          'Estadísticas detalladas de tus publicaciones'),
      (Icons.verified, 'Perfil verificado',
          'Mayor confianza ante los candidatos'),
    ];
    return Column(children: [
      Text('Beneficios Business',
          style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      ...items.map((it) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(it.$1, color: AppColors.accentBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.$2, style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold)),
            Text(it.$3, style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary)),
          ])),
          if (esPremium)
            const Icon(Icons.check_circle,
                color: AppColors.accentGreen, size: 18),
        ]),
      )),
    ]);
  }

  Widget _buildBotonPago() => Column(children: [
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_procesando || _planSel == null) ? null : _pagar,
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        child: _procesando
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(_planSel != null
                ? 'Suscribirse — ${_precioFormateado(_planSel!)}'
                : 'Suscribirse con PayPal',
                style: AppTextStyles.button.copyWith(color: Colors.white)),
      ),
    ),
    const SizedBox(height: 10),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.lock_outline, size: 13, color: AppColors.textTertiary),
      const SizedBox(width: 4),
      Text('Pago procesado de forma segura por PayPal',
          style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary)),
    ]),
  ]);

  Widget _buildActivoBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
        color: AppColors.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentGreen.withOpacity(0.3))),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.check_circle, color: AppColors.accentGreen),
      const SizedBox(width: 10),
      Text('Cuenta Business Activa',
          style: AppTextStyles.subtitle1.copyWith(
              color: AppColors.accentGreen, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _buildBotonCancelar() => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: _procesando ? null : _confirmarCancelacion,
      icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
      label: const Text('Cancelar suscripción',
          style: TextStyle(color: AppColors.error)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: AppColors.error),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  Widget _buildError() => Column(children: [
    const SizedBox(height: 16),
    const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textTertiary),
    const SizedBox(height: 8),
    Text(_error!,
        style: const TextStyle(color: AppColors.error),
        textAlign: TextAlign.center),
    const SizedBox(height: 12),
    ElevatedButton.icon(
        onPressed: _cargarPlanes,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue),
        icon: const Icon(Icons.refresh, color: Colors.white),
        label: const Text('Reintentar',
            style: TextStyle(color: Colors.white))),
    const SizedBox(height: 16),
  ]);

  // ── Lógica de negocio ─────────────────────────────────────────────────────
  Future<void> _pagar() async {
    if (_planSel == null) return;
    setState(() => _procesando = true);
    try {
      final cycle = _billingCycle(_planSel!);
      // FIX: el repo ya no recibe planCode, solo billingCycle
      final res = await _repo.crearSuscripcion(
        billingCycle: cycle,
        returnUrl:    _returnUrl,
        cancelUrl:    _cancelUrl,
      );
      final approveUrl = res['approve_url'] as String?;
      final subId      = res['paypal_subscription_id'] as String?;

      if (approveUrl == null || approveUrl.isEmpty) {
        _snack('PayPal no devolvió URL. Intenta de nuevo.', isError: true);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_paypal_sub_id_empresa', subId ?? '');
      setState(() => _pendingId = subId);

      final uri = Uri.parse(approveUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _snack('No se pudo abrir el navegador', isError: true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _sync() async {
    if (_pendingId == null) return;
    setState(() => _procesando = true);
    try {
      await _repo.sincronizar(_pendingId!);
      await context.read<AuthProvider>().refrescarUsuario();
      await _limpiarPendiente();
      await _cargarSuscripcion();

      if (mounted && context.read<AuthProvider>().esPremium) {
        _showSuccessDialog();
      } else {
        _snack('Pago pendiente de confirmación por PayPal');
      }
    } catch (e) {
      _snack('No se pudo verificar. ¿Ya aprobaste en PayPal?', isError: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _confirmarCancelacion() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('¿Cancelar suscripción Business?'),
      content: const Text(
          'Perderás acceso a las funciones Business al término del período actual. '
          'Esta acción no genera reembolso.'),
      actions: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mantener Business')),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () { Navigator.pop(context); _cancelar(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sí, cancelar'),
          ),
        ),
      ],
    ));
  }

  Future<void> _cancelar() async {
    final subId = _paypalSubId ?? _pendingId;
    if (subId == null) {
      _snack('No se encontró la suscripción activa', isError: true);
      return;
    }
    setState(() => _procesando = true);
    try {
      await _repo.cancelar(subId, razon: 'Cancelada por empresa desde la app');
      await context.read<AuthProvider>().refrescarUsuario();
      await _cargarSuscripcion();
      if (mounted) _snack('Suscripción cancelada correctamente');
    } catch (e) {
      _snack('Error al cancelar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: AppColors.accentBlue, shape: BoxShape.circle),
            child: const Icon(Icons.business_center,
                color: Colors.white, size: 44)),
          const SizedBox(height: 14),
          Text('¡Business Activado! 🚀',
              style: AppTextStyles.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Tu empresa ahora tiene acceso completo a JobMatch.',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(context); context.pop(); },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue),
              child: const Text('¡Comenzar!'),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 5 : 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}