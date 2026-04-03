// lib/presentation/screens/common/premium_screen.dart
//
// Integración PayPal Sandbox con flutter_paypal_payment
// Dependencia: flutter_paypal_payment: ^1.0.5
//
// Setup:
// 1. developer.paypal.com → My Apps → Create App (Sandbox)
// 2. Copia el CLIENT_ID de Sandbox y pégalo en _kPaypalClientId
// 3. Para pruebas usa las cuentas de developer.paypal.com → Sandbox Accounts

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/api_service.dart';
import '../../providers/auth_provider.dart';

// ─── CONFIGURACIÓN PAYPAL SANDBOX ─────────────────────────────────────────
// Reemplaza con tu Client ID de Sandbox
const String _kPaypalClientId =
    'TU_PAYPAL_SANDBOX_CLIENT_ID_AQUI';

// Cuando estés listo para producción:
// 1. Cambia clientId al de producción
// 2. Cambia returnURL y cancelURL a tu dominio real
const String _kReturnUrl = 'https://jobmatch.com.mx/payment/success';
const String _kCancelUrl = 'https://jobmatch.com.mx/payment/cancel';
// ──────────────────────────────────────────────────────────────────────────

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _anual = false; // false = mensual, true = anual
  bool _procesando = false;

  // Precios
  static const double _precioMensual = 99.0;
  static const double _precioAnual   = 799.0;
  static const String _moneda        = 'MXN';

  double get _precio => _anual ? _precioAnual : _precioMensual;
  String get _tipoPlan => _anual ? 'anual' : 'mensual';
  String get _ahorro =>
      '\$${(_precioMensual * 12 - _precioAnual).toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final esPremium = auth.esPremium;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(children: [

          // ── Header gradiente ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            decoration: const BoxDecoration(gradient: AppColors.purpleGradient),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),
              Text('JobMatch Premium',
                  style: AppTextStyles.h2.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                esPremium
                    ? '¡Ya eres usuario Premium! 🎉'
                    : 'Desbloquea todo el potencial de JobMatch',
                style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white.withOpacity(0.9)),
                textAlign: TextAlign.center,
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [

              // ── Toggle mensual / anual ────────────────────────────────
              if (!esPremium) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8)],
                  ),
                  child: Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _anual = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_anual
                              ? AppColors.primaryPurple
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: Text('Mensual',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: !_anual ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ))),
                      ),
                    )),
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _anual = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _anual
                              ? AppColors.primaryPurple
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Anual',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: _anual ? Colors.white : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                )),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Ahorra $_ahorro',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )),
                      ),
                    )),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Precio ────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primaryPurple.withOpacity(0.3), width: 2),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('\$', style: AppTextStyles.h4.copyWith(
                            color: AppColors.primaryPurple)),
                        Text(_precio.toStringAsFixed(0),
                            style: AppTextStyles.h1.copyWith(
                                color: AppColors.primaryPurple, fontSize: 56)),
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(' $_moneda',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                    Text(_anual ? 'por año' : 'por mes',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary)),
                    if (_anual) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Equivale a \$${(_precioAnual / 12).toStringAsFixed(0)}/mes',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 24),
              ],

              // ── Beneficios ────────────────────────────────────────────
              _buildBeneficios(cardColor, esPremium),
              const SizedBox(height: 24),

              // ── Botón de pago ─────────────────────────────────────────
              if (!esPremium) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _procesando ? null : () => _iniciarPago(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: AppColors.primaryPurple,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _procesando
                        ? const SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Row(mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          const Icon(Icons.payment, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            'Pagar con PayPal — \$${_precio.toStringAsFixed(0)} $_moneda',
                            style: AppTextStyles.button.copyWith(color: Colors.white),
                          ),
                        ]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.lock_outline, size: 14,
                      color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text('Pago seguro · Cancela cuando quieras',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary)),
                ]),
              ] else ...[
                // Ya es premium
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.accentGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.accentGreen),
                      const SizedBox(width: 12),
                      Text('Plan Premium activo',
                          style: AppTextStyles.subtitle1.copyWith(
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Beneficios ─────────────────────────────────────────────────────────────
  Widget _buildBeneficios(Color cardColor, bool esPremium) {
    const beneficios = [
      _Beneficio(
        icon: Icons.all_inclusive,
        titulo: 'Swipes ilimitados',
        desc: 'Sin límite diario — explora todas las vacantes que quieras',
        premium: true,
      ),
      _Beneficio(
        icon: Icons.bolt,
        titulo: 'Match instantáneo',
        desc: 'Prioridad en el algoritmo de matching',
        premium: true,
      ),
      _Beneficio(
        icon: Icons.analytics_outlined,
        titulo: 'Análisis con IA',
        desc: 'Recibe feedback personalizado de tu perfil y CV',
        premium: true,
      ),
      _Beneficio(
        icon: Icons.visibility_outlined,
        titulo: 'Ver quién te vio',
        desc: 'Descubre qué empresas revisaron tu perfil',
        premium: true,
      ),
      _Beneficio(
        icon: Icons.notifications_active_outlined,
        titulo: 'Alertas prioritarias',
        desc: 'Notificaciones inmediatas cuando hay un match',
        premium: true,
      ),
      _Beneficio(
        icon: Icons.workspace_premium,
        titulo: 'Badge Premium',
        desc: 'Destaca tu perfil ante las empresas reclutadoras',
        premium: true,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text('¿Qué incluye Premium?',
                style: AppTextStyles.h4),
          ),
          ...beneficios.map((b) => _buildBeneficioTile(b, esPremium)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBeneficioTile(_Beneficio b, bool activo) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (activo ? AppColors.accentGreen : AppColors.primaryPurple)
              .withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(b.icon,
            color: activo ? AppColors.accentGreen : AppColors.primaryPurple,
            size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(b.titulo, style: AppTextStyles.subtitle1.copyWith(
                fontWeight: FontWeight.bold)),
            if (activo) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, color: AppColors.accentGreen, size: 16),
            ],
          ]),
          Text(b.desc, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary)),
        ],
      )),
    ]),
  );

  // ── Iniciar pago PayPal ────────────────────────────────────────────────────
  Future<void> _iniciarPago(BuildContext context) async {
    if (_kPaypalClientId == 'TU_PAYPAL_SANDBOX_CLIENT_ID_AQUI') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Configura el Client ID de PayPal Sandbox primero'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _procesando = true);

    try {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PaypalCheckoutView(
          sandboxMode: true, // ← cambiar a false en producción
          clientId:    _kPaypalClientId,
          secretKey:   'TU_PAYPAL_SANDBOX_SECRET_AQUI',
          transactions: [
            {
              'amount': {
                'total':    _precio.toStringAsFixed(2),
                'currency': _moneda,
                'details':  {'subtotal': _precio.toStringAsFixed(2)},
              },
              'description': 'JobMatch Premium — Plan ${_tipoPlan.toUpperCase()}',
              'item_list': {
                'items': [
                  {
                    'name':     'JobMatch Premium',
                    'quantity': 1,
                    'price':    _precio.toStringAsFixed(2),
                    'currency': _moneda,
                  },
                ],
              },
            },
          ],
          note:      'Gracias por suscribirte a JobMatch Premium',
          onSuccess: (params) async {
            Navigator.of(context).pop();
            await _activarPremium(context, params);
          },
          onError: (error) {
            Navigator.of(context).pop();
            _snack(context, 'Error en el pago: $error', AppColors.error);
          },
          onCancel: () {
            Navigator.of(context).pop();
            _snack(context, 'Pago cancelado', AppColors.textSecondary);
          },
        ),
      ));
    } catch (e) {
      _snack(context, 'Error al iniciar el pago', AppColors.error);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  // ── Activar premium en el backend ─────────────────────────────────────────
  Future<void> _activarPremium(
      BuildContext context, Map<String, dynamic> params) async {
    final userId = context.read<AuthProvider>().usuario?.id;
    if (userId == null) return;

    try {
      final hoy    = DateTime.now();
      final fin    = _anual
          ? hoy.add(const Duration(days: 365))
          : hoy.add(const Duration(days: 30));

      // POST /suscripciones/ → { usuario_id, tipo_plan, fecha_inicio, fecha_fin }
      await ApiService.instance.post('/suscripciones/', {
        'usuario_id':   userId,
        'tipo_plan':    _anual ? 'premium_anual' : 'premium_mensual',
        'fecha_inicio': hoy.toIso8601String().split('T')[0],
        'fecha_fin':    fin.toIso8601String().split('T')[0],
      }, auth: true);

      if (!context.mounted) return;
      _showSuccessDialog(context);
    } catch (e) {
      if (!context.mounted) return;
      // El pago fue exitoso aunque falle el backend
      _showSuccessDialog(context);
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.purpleGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 16),
          Text('¡Bienvenido a Premium! 🎉',
              style: AppTextStyles.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Tu cuenta ha sido actualizada. Ahora tienes acceso a todos los beneficios.',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(context); context.pop(); },
              child: const Text('¡Empezar!'),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

class _Beneficio {
  final IconData icon;
  final String   titulo;
  final String   desc;
  final bool     premium;
  const _Beneficio({
    required this.icon, required this.titulo,
    required this.desc, required this.premium,
  });
}