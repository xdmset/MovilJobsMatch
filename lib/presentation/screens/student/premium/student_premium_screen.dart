// lib/presentation/screens/student/premium/student_premium_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../../data/repositories/paypal_repository.dart';

class StudentPremiumScreen extends StatefulWidget {
  const StudentPremiumScreen({super.key});
  @override
  State<StudentPremiumScreen> createState() => _StudentPremiumScreenState();
}

class _StudentPremiumScreenState extends State<StudentPremiumScreen>
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
      'https://jobmatch.com.mx/payments/paypal/mobile-success';
  static const _cancelUrl =
      'https://jobmatch.com.mx/payments/paypal/mobile-cancel';

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
      debugPrint('[PayPal] App resumed con pendingId: $_pendingId');
      _sync();
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pending_paypal_sub_id_estudiante');
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
      debugPrint('[PayPal] Total planes recibidos: ${todos.length}');

      // FIX: Filtrar planes para estudiante — el campo es 'rol_objetivo'
      // Cuando /plans/me ya filtra, todos los planes son del rol correcto.
      // Cuando viene de /plans (fallback), filtramos por rol_objetivo.
      List<Map<String, dynamic>> planesEstudiante;

      final tieneRolObjetivo = todos.any((p) => p['rol_objetivo'] != null);

      if (tieneRolObjetivo) {
        planesEstudiante = todos.where((p) {
          final rol = (p['rol_objetivo'] ?? '').toString().toLowerCase();
          return rol.contains('estudiante');
        }).toList();
      } else {
        // /plans/me ya filtró por rol, usar todos directamente
        planesEstudiante = todos;
      }

      debugPrint('[PayPal] Planes estudiante filtrados: ${planesEstudiante.length}');

      setState(() {
        if (planesEstudiante.isNotEmpty) {
          _planes = planesEstudiante;
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
          // Fallback absoluto: mostrar todos aunque no se pudo filtrar por rol
          debugPrint('[PayPal] ⚠️ No se encontraron planes con rol_objetivo=estudiante, usando todos');
          _planes = todos;
          _planSel = todos.first;
        } else {
          _error = 'No hay planes disponibles.\nContacta soporte si el problema persiste.';
        }
        _cargando = false;
      });
    } catch (e) {
      debugPrint('[PayPal] Error al cargar planes: $e');
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
    await prefs.remove('pending_paypal_sub_id_estudiante');
    if (mounted) setState(() => _pendingId = null);
  }

  // ── Helpers de datos ──────────────────────────────────────────────────────

  // FIX: _billingCycle usa 'periodicidad' y 'codigo' correctamente
  // ya NO usa p['id'] como fallback (causaba que todos dieran 'mensual')
  String _billingCycle(Map<String, dynamic> p) {
    // Intentar con los campos correctos del backend
    final candidates = [
      p['periodicidad'],   // campo principal del backend
      p['codigo'],         // ej: "PLAN_STUDENT_PREMIUM_MENSUAL"
      p['plan_code'],
      p['code'],
      p['nombre'],         // ej: "Premium Estudiante Mensual"
    ].whereType<String>().map((s) => s.toLowerCase());

    for (final val in candidates) {
      if (val.contains('semestral')) return 'semestral';
      if (val.contains('anual'))     return 'anual';
      if (val.contains('mensual'))   return 'mensual';
    }

    // Último recurso: inspeccionar precio para inferir ciclo
    // (no ideal pero mejor que default ciego)
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
    final auth      = context.watch<AuthProvider>();
    final esPremium = auth.esPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JobMatch Premium'),
        actions: [
          if (_pendingId != null && !esPremium)
            TextButton.icon(
              onPressed: _procesando ? null : _sync,
              icon: const Icon(Icons.sync, color: AppColors.accentGreen, size: 18),
              label: const Text('Verificar',
                  style: TextStyle(color: AppColors.accentGreen)),
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
                  const Padding(padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator())
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
    decoration: const BoxDecoration(gradient: AppColors.purpleGradient),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
        child: Icon(
            esPremium ? Icons.workspace_premium : Icons.star_outline,
            color: Colors.white, size: 44),
      ),
      const SizedBox(height: 16),
      Text(esPremium ? '¡Ya eres Premium! ⭐' : 'Hazte Premium',
          style: AppTextStyles.h2.copyWith(color: Colors.white)),
      const SizedBox(height: 8),
      Text(
        esPremium
            ? 'Disfruta de todos los beneficios exclusivos'
            : 'Desbloquea swipes ilimitados, análisis IA y más',
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
              color: sel ? AppColors.primaryPurple : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? AppColors.primaryPurple : AppColors.borderLight)),
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
          style: AppTextStyles.h2.copyWith(color: AppColors.primaryPurple)),
    ]),
  );

  Widget _buildBeneficios(bool esPremium) {
    final items = [
      (Icons.all_inclusive, 'Swipes ilimitados',
          'Sin restricciones diarias'),
      (Icons.psychology, 'Análisis IA de tu perfil',
          'Feedback personalizado para mejorar'),
      (Icons.flash_on, 'Aparece primero',
          'Mayor visibilidad ante empresas'),
      (Icons.bar_chart, 'Estadísticas detalladas',
          'Ve cómo te ven las empresas'),
    ];
    return Column(children: [
      Text('Beneficios Premium',
          style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      ...items.map((it) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(it.$1, color: AppColors.primaryPurple, size: 20),
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        child: _procesando
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(_planSel != null
                ? 'Suscribirse — ${_precioFormateado(_planSel!)}'
                : 'Suscribirse con PayPal'),
      ),
    ),
    const SizedBox(height: 10),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.lock_outline, size: 13, color: AppColors.textTertiary),
      const SizedBox(width: 4),
      Text('Pago seguro vía PayPal',
          style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary)),
    ]),
  ]);

  Widget _buildActivoBanner() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
        color: AppColors.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentGreen.withOpacity(0.3))),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.check_circle, color: AppColors.accentGreen),
      const SizedBox(width: 10),
      const Text('Suscripción Premium Activa',
          style: TextStyle(
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
    TextButton.icon(
        onPressed: _cargarPlanes,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar')),
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

      if (approveUrl == null || subId == null) {
        _snack('Respuesta inválida del servidor', isError: true);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_paypal_sub_id_estudiante', subId);
      setState(() => _pendingId = subId);

      final uri = Uri.parse(approveUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _snack('No se pudo abrir PayPal', isError: true);
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
        _snack('Pago pendiente de confirmación por PayPal', isError: false);
      }
    } catch (e) {
      _snack('No se pudo verificar aún. ¿Ya aprobaste en PayPal?', isError: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _confirmarCancelacion() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('¿Cancelar suscripción?'),
      content: const Text(
          'Perderás acceso a los beneficios Premium al término del período actual. '
          'Esta acción no genera reembolso.'),
      actions: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mantener Premium')),
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
      await _repo.cancelar(subId, razon: 'Cancelada por el usuario desde la app');
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
      builder: (ctx) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: AppColors.purpleGradient, shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium,
                color: Colors.white, size: 48)),
          const SizedBox(height: 16),
          Text('¡Ya eres Premium! ⭐',
              style: AppTextStyles.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Ahora tienes acceso a swipes ilimitados, análisis IA y más.',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); context.pop(); },
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