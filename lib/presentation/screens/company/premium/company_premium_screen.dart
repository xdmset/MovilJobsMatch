// lib/presentation/screens/company/premium/company_premium_screen.dart
// Pantalla Premium exclusiva para empresas

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../../data/repositories/paypal_repository.dart';

class CompanyPremiumScreen extends StatefulWidget {
  const CompanyPremiumScreen({super.key});
  @override
  State<CompanyPremiumScreen> createState() => _CompanyPremiumScreenState();
}

class _CompanyPremiumScreenState extends State<CompanyPremiumScreen> {
  final _repo = PaypalRepository.instance;

  List<Map<String, dynamic>> _planes = [];
  Map<String, dynamic>? _planSel;
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
    _cargarPlanes();
  }

  Future<void> _cargarPlanes() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final planes = await _repo.getPlanes();
      setState(() {
        _planes = planes;
        _planSel = planes.isEmpty
            ? null
            : planes.firstWhere(
                (p) => _codigo(p).toLowerCase().contains('mensual'),
                orElse: () => planes.first);
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudieron cargar los planes';
        _cargando = false;
      });
    }
  }

  String _codigo(Map p) =>
      (p['plan_code'] ?? p['code'] ?? p['id'] ?? '').toString();
  String _nombre(Map p) {
    final c = _codigo(p).toLowerCase();
    final n = (p['name'] ?? p['nombre'] ?? '').toString();
    if (n.isNotEmpty && !n.startsWith('{')) return n;
    if (c.contains('mensual')) return 'Mensual';
    if (c.contains('semestral')) return 'Semestral';
    if (c.contains('anual')) return 'Anual';
    return c;
  }

  String _precio(Map p) {
    final pr = p['price'] ?? p['precio'] ?? p['amount'];
    final mo = p['currency'] ?? p['moneda'] ?? 'MXN';
    final c = _codigo(p).toLowerCase();
    final sf = c.contains('mensual')
        ? '/mes'
        : c.contains('semestral')
            ? '/6 meses'
            : c.contains('anual')
                ? '/año'
                : '';
    return pr != null ? '\$$pr $mo$sf' : _nombre(p);
  }

  String _billingCycle(Map<String, dynamic> p) {
    final code = _codigo(p).toLowerCase();
    if (code.contains('mensual')) return 'monthly';
    if (code.contains('semestral')) return 'semestral';
    if (code.contains('anual')) return 'annual';
    return 'monthly'; // default
  }

  @override
  Widget build(BuildContext context) {
    final esPremium = context.watch<AuthProvider>().esPremium;
    final card = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium para empresas'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          if (_pendingId != null && !esPremium)
            TextButton(
              onPressed: _procesando ? null : _sync,
              child: const Text('Verificar pago',
                  style: TextStyle(
                      color: AppColors.accentGreen,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
          child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.accentBlue,
              AppColors.accentBlue.withBlue(255),
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(children: [
            Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.business_center,
                    color: Colors.white, size: 44)),
            const SizedBox(height: 14),
            Text('JobMatch Business',
                style: AppTextStyles.h2.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
                esPremium
                    ? '¡Cuenta Business activa! 🚀'
                    : 'Potencia tu reclutamiento',
                style: AppTextStyles.bodyLarge
                    .copyWith(color: Colors.white.withOpacity(0.9)),
                textAlign: TextAlign.center),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              if (_pendingId != null && !esPremium)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.accentGreen.withOpacity(0.4))),
                  child: Text(
                      '¿Ya aprobaste en PayPal? Presiona "Verificar pago" arriba.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ),

              if (!esPremium) ...[
                if (_cargando)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          color: AppColors.accentBlue))
                else if (_error != null)
                  Column(children: [
                    Text(_error!,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.error)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                        onPressed: _cargarPlanes,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar')),
                    const SizedBox(height: 16),
                  ])
                else if (_planes.isNotEmpty) ...[
                  // Tabs planes
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8)
                        ]),
                    child: Row(
                        children: _planes.map((plan) {
                      final sel = _planSel == plan;
                      return Expanded(
                          child: GestureDetector(
                        onTap: () => setState(() => _planSel = plan),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.accentBlue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(
                              child: Text(_nombre(plan),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      color: sel
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600))),
                        ),
                      ));
                    }).toList()),
                  ),
                  const SizedBox(height: 16),
                  if (_planSel != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: AppColors.accentBlue.withOpacity(0.3),
                              width: 2)),
                      child: Column(children: [
                        Text(_precio(_planSel!),
                            style: AppTextStyles.h2.copyWith(
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('${_nombre(_planSel!)} · Acceso Business completo',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary)),
                      ]),
                    ),
                  const SizedBox(height: 16),
                ],
              ],

              // Beneficios empresa
              Container(
                decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04), blurRadius: 8)
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                          child: Text('¿Qué incluye Business?',
                              style: AppTextStyles.h4)),
                      ...[
                        (
                          Icons.people_outline,
                          'Candidatos ilimitados',
                          'Sin límite de perfiles para revisar'
                        ),
                        (
                          Icons.analytics_outlined,
                          'Estadísticas avanzadas',
                          'Métricas detalladas de tus vacantes'
                        ),
                        (
                          Icons.bolt,
                          'Vacantes destacadas',
                          'Aparece primero en las búsquedas'
                        ),
                        (
                          Icons.chat_bubble_outline,
                          'Mensajería directa',
                          'Contacta candidatos directamente'
                        ),
                        (
                          Icons.verified,
                          'Badge verificado',
                          'Sello de empresa de confianza'
                        ),
                        (
                          Icons.workspace_premium,
                          'Soporte prioritario',
                          'Atención preferencial'
                        ),
                      ].map((item) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(children: [
                              Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                      color: (esPremium
                                              ? AppColors.accentGreen
                                              : AppColors.accentBlue)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Icon(item.$1,
                                      color: esPremium
                                          ? AppColors.accentGreen
                                          : AppColors.accentBlue,
                                      size: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(item.$2,
                                        style: AppTextStyles.subtitle1.copyWith(
                                            fontWeight: FontWeight.bold)),
                                    Text(item.$3,
                                        style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.textSecondary)),
                                  ])),
                              if (esPremium)
                                const Icon(Icons.check_circle,
                                    color: AppColors.accentGreen, size: 16),
                            ]),
                          )),
                      const SizedBox(height: 8),
                    ]),
              ),
              const SizedBox(height: 24),

              if (!esPremium && !_cargando && _error == null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_procesando || _planSel == null) ? null : _pagar,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: _procesando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            _planSel != null
                                ? 'Suscribirse — ${_precio(_planSel!)}'
                                : 'Suscribirse con PayPal',
                            style: AppTextStyles.button
                                .copyWith(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.lock_outline,
                      size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text('Pago procesado de forma segura por PayPal',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary)),
                ]),
              ],

              if (esPremium)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.accentGreen.withOpacity(0.3))),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.accentGreen),
                        const SizedBox(width: 10),
                        Text('Cuenta Business activa',
                            style: AppTextStyles.subtitle1.copyWith(
                                color: AppColors.accentGreen,
                                fontWeight: FontWeight.bold)),
                      ]),
                ),
              const SizedBox(height: 24),
            ])),
      ])),
    );
  }

  Future<void> _pagar() async {
    final codigo = _codigo(_planSel ?? {});
    if (codigo.isEmpty) {
      _snack('Plan no válido', isError: true);
      return;
    }
    setState(() => _procesando = true);
    try {
      final res = await _repo.crearSuscripcion(
          planCode: codigo,
          billingCycle: _billingCycle(_planSel!),
          returnUrl: _returnUrl,
          cancelUrl: _cancelUrl);
      final approveUrl = res['approve_url'] as String?;
      final subId = res['paypal_subscription_id'] as String?;
      if (approveUrl == null || approveUrl.isEmpty) {
        _snack('PayPal no devolvió URL. Intenta de nuevo.', isError: true);
        return;
      }
      setState(() => _pendingId = subId);
      final uri = Uri.parse(approveUrl);
      if (await canLaunchUrl(uri))
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      else
        _snack('No se puede abrir el navegador', isError: true);
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
      setState(() => _pendingId = null);
      if (mounted)
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: AppColors.accentBlue,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.business_center,
                            color: Colors.white, size: 44)),
                    const SizedBox(height: 14),
                    Text('¡Business activado! 🚀',
                        style: AppTextStyles.h3, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Tu empresa ahora tiene acceso completo.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
                  ]),
                  actions: [
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            context.pop();
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentBlue),
                          child: const Text('¡Comenzar!'),
                        ))
                  ],
                ));
    } catch (e) {
      _snack('No se pudo verificar. ¿Ya aprobaste?', isError: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _snack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 5 : 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}
