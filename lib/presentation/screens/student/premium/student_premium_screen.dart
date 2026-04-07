// lib/presentation/screens/student/premium/student_premium_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/errors/api_exceptions.dart';
import '../../../providers/auth_provider.dart';
import '../../../../data/repositories/paypal_repository.dart';

class StudentPremiumScreen extends StatefulWidget {
  const StudentPremiumScreen({super.key});

  @override
  State<StudentPremiumScreen> createState() => _StudentPremiumScreenState();
}

class _StudentPremiumScreenState extends State<StudentPremiumScreen> with WidgetsBindingObserver {
  final _repo = PaypalRepository.instance;

  List<Map<String, dynamic>> _planes = [];
  Map<String, dynamic>? _planSel;
  bool _cargando = true;
  bool _procesando = false;
  String? _error;
  String? _pendingId;

  static const _returnUrl = 'https://jobmatch.com.mx/payments/paypal/mobile-success';
  static const _cancelUrl = 'https://jobmatch.com.mx/payments/paypal/mobile-cancel';

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
      debugPrint('[PayPal] Usuario de vuelta. ID: $_pendingId');
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pendingId = prefs.getString('pending_paypal_sub_id');
    });

    await _cargarPlanes();

    if (mounted && context.read<AuthProvider>().esPremium) {
      _limpiarEstadoPendiente();
    }
  }

  Future<void> _limpiarEstadoPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_paypal_sub_id');
    if (mounted) setState(() => _pendingId = null);
  }

  Future<void> _cargarPlanes() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final planes = await _repo.getPlanes();
      if (!mounted) return;

      setState(() {
        _planes = planes;
        if (planes.isNotEmpty) {
          _planSel = planes.firstWhere(
            (p) => _obtenerPlanCode(p) == 'mensual',
            orElse: () => planes.first,
          );
        } else {
          _error = 'No hay planes disponibles';
        }
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar planes.';
        _cargando = false;
      });
    }
  }

  // --- HELPERS DE DATOS ---

  String _obtenerPlanCode(Map<String, dynamic> p) {
    final code = (p['plan_code'] ?? p['code'] ?? p['id'] ?? '').toString().toLowerCase();
    if (code.contains('mensual')) return 'mensual';
    if (code.contains('semestral')) return 'semestral';
    if (code.contains('anual')) return 'anual';
    return code;
  }

  // NUEVO: Para resolver el error de 'billingCycle'
  String _obtenerBillingCycle(Map<String, dynamic> p) {
    final code = _obtenerPlanCode(p);
  // El backend espera 'mensual', 'semestral' o 'anual'
  if (code.contains('mensual')) return 'mensual';
  if (code.contains('semestral')) return 'semestral';
  if (code.contains('anual')) return 'anual';
  return 'mensual'; // Valor por defecto
}

  String _nombrePlan(Map<String, dynamic> p) {
    final code = _obtenerPlanCode(p);
    return code[0].toUpperCase() + code.substring(1);
  }

  String _precioFormateado(Map<String, dynamic> p) {
    final precio = p['price'] ?? p['precio'] ?? p['amount'] ?? '0';
    final moneda = p['currency'] ?? 'MXN';
    final code = _obtenerPlanCode(p);
    final periodicidad = code == 'mensual' ? '/mes' : code == 'semestral' ? '/6 meses' : '/año';
    return '\$$precio $moneda$periodicidad';
  }

  // --- WIDGETS ---

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final esPremium = auth.esPremium;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JobMatch Premium'),
        actions: [
          if (_pendingId != null && !esPremium)
            TextButton.icon(
              onPressed: _procesando ? null : _sync,
              icon: const Icon(Icons.sync, color: AppColors.accentGreen, size: 18),
              label: const Text('Verificar', style: TextStyle(color: AppColors.accentGreen)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(esPremium),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_pendingId != null && !esPremium) _buildSyncBanner(),
                  if (!esPremium) ...[
                    if (_cargando)
                      const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())
                    else if (_error != null)
                      _buildError()
                    else ...[
                      _buildPlanTabs(cardColor),
                      const SizedBox(height: 16),
                      if (_planSel != null) _buildPrecioCard(cardColor),
                    ],
                  ],
                  const SizedBox(height: 16),
                  _buildBeneficios(cardColor, esPremium),
                  const SizedBox(height: 24),
                  if (!esPremium && !_cargando && _error == null) _buildBotonPago(),
                  if (esPremium) _buildActivoBanner(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool esPremium) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        decoration: const BoxDecoration(gradient: AppColors.purpleGradient),
        child: Column(
          children: [
            Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.workspace_premium, color: Colors.white, size: 44)),
            const SizedBox(height: 14),
            Text('Hazte Premium', style: AppTextStyles.h2.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              esPremium ? '¡Ya eres Premium! 🎉' : 'Desbloquea todas las herramientas.',
              style: AppTextStyles.bodyLarge.copyWith(color: Colors.white.withOpacity(0.9)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildSyncBanner() => Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: AppColors.accentGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accentGreen.withOpacity(0.4))),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.accentGreen, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('¿Ya pagaste? Dale a "Verificar" para activar tu cuenta.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );

  Widget _buildPlanTabs(Color card) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: _planes.map((plan) {
            final sel = _planSel == plan;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _planSel = plan),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: sel ? AppColors.primaryPurple : Colors.transparent,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(_nombrePlan(plan),
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: sel ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );

  Widget _buildPrecioCard(Color card) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3), width: 2)),
        child: Column(
          children: [
            Text(_precioFormateado(_planSel!),
                style: AppTextStyles.h2.copyWith(color: AppColors.primaryPurple, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Suscripción ${_nombrePlan(_planSel!)}', style: AppTextStyles.bodySmall),
          ],
        ),
      );

  Widget _buildBotonPago() => Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_procesando || _planSel == null) ? null : _pagar,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _procesando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Suscribirse con PayPal'),
            ),
          ),
          const SizedBox(height: 10),
          const Text('🔒 Pago seguro vía PayPal', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );

  Widget _buildBeneficios(Color card, bool esPremium) {
    final items = [
      (Icons.all_inclusive, 'Swipes ilimitados', 'Sin límites diarios'),
      (Icons.bolt, 'Match prioritario', 'Aparece primero'),
      (Icons.analytics, 'Análisis de CV', 'Feedback con IA'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Qué incluye?', style: AppTextStyles.h4),
          const SizedBox(height: 16),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(it.$1, color: esPremium ? AppColors.accentGreen : AppColors.primaryPurple, size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.$2, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(it.$3, style: AppTextStyles.bodySmall),
                      ],
                    ),
                    if (esPremium) ...[const Spacer(), const Icon(Icons.check_circle, color: AppColors.accentGreen, size: 16)]
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActivoBanner() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.accentGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppColors.accentGreen),
            SizedBox(width: 10),
            Text('Suscripción Activa', style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _buildError() => Column(
        children: [
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          TextButton(onPressed: _cargarPlanes, child: const Text('Reintentar')),
        ],
      );

  // --- LÓGICA DE NEGOCIO ---

  Future<void> _pagar() async {
    if (_planSel == null) return;
    
    final planCode = _obtenerPlanCode(_planSel!);
    final cycle = _obtenerBillingCycle(_planSel!); // Obtenemos el ciclo requerido

    setState(() => _procesando = true);
    try {
      // AQUÍ SE CORRIGIÓ: Se añadió billingCycle
      final res = await _repo.crearSuscripcion(
        planCode: planCode,
        billingCycle: cycle, 
        returnUrl: _returnUrl,
        cancelUrl: _cancelUrl,
      );

      final approveUrl = res['approve_url'] as String?;
      final subId = res['paypal_subscription_id'] as String?;

      if (approveUrl == null || subId == null) throw Exception('Respuesta inválida del servidor');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_paypal_sub_id', subId);
      setState(() => _pendingId = subId);

      final uri = Uri.parse(approveUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      await context.read<AuthProvider>().verificarSesion();

      if (mounted) {
        await _limpiarEstadoPendiente();
        _showSuccess();
      }
    } catch (e) {
      _snack('No se pudo verificar el pago aún.', isError: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('¡Ya eres Premium!'),
        content: const Text('Tu suscripción se ha activado correctamente.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            }, 
            child: const Text('¡Genial!')
          )
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.accentGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }
}