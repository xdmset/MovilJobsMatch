// // lib/presentation/screens/common/premium_screen.dart

// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../../../core/constants/app_colors.dart';
// import '../../../core/constants/app_text_styles.dart';
// import '../../providers/auth_provider.dart';
// import '../../../data/repositories/paypal_repository.dart';

// class PremiumScreen extends StatefulWidget {
//   const PremiumScreen({super.key});
//   @override
//   State<PremiumScreen> createState() => _PremiumScreenState();
// }

// class _PremiumScreenState extends State<PremiumScreen> {
//   final _paypal = PaypalRepository.instance;

//   List<Map<String, dynamic>> _planes    = [];
//   Map<String, dynamic>?      _planSel;
//   bool   _cargandoPlanes = true;
//   bool   _procesando     = false;
//   String? _errorPlanes;
//   String? _pendingSubId;

//   @override
//   void initState() {
//     super.initState();
//     _cargarPlanes();
//   }

//   Future<void> _cargarPlanes() async {
//     setState(() { _cargandoPlanes = true; _errorPlanes = null; });
//     try {
//       final planes = await _paypal.getPlanes();
//       debugPrint('[PayPal] planes recibidos: $planes');
//       setState(() {
//         _planes = planes;
//         // Seleccionar mensual por defecto
//         if (planes.isNotEmpty) {
//           _planSel = planes.firstWhere(
//               (p) => _planCode(p).contains('mensual'),
//               orElse: () => planes.first);
//         }
//         _cargandoPlanes = false;
//       });
//     } catch (e) {
//       debugPrint('[PayPal] Error cargando planes: $e');
//       setState(() {
//         _errorPlanes = 'No se pudieron cargar los planes.\nVerifica tu conexión.';
//         _cargandoPlanes = false;
//       });
//     }
//   }

//   // Extrae el código del plan — soporta distintos campos que el backend pueda devolver
//   String _planCode(Map<String, dynamic> plan) {
//     return (plan['plan_code'] ?? plan['code'] ?? plan['id'] ?? '').toString();
//   }

//   String _nombrePlan(Map<String, dynamic> plan) {
//     final code = _planCode(plan).toLowerCase();
//     final name = (plan['name'] ?? plan['nombre'] ?? '').toString();
//     if (name.isNotEmpty && !name.startsWith('{')) return name;
//     if (code.contains('mensual'))   return 'Mensual';
//     if (code.contains('semestral')) return 'Semestral';
//     if (code.contains('anual'))     return 'Anual';
//     return code;
//   }

//   String _precioLabel(Map<String, dynamic> plan) {
//     final precio  = plan['price'] ?? plan['precio'] ?? plan['amount'] ?? plan['monto'];
//     final moneda  = plan['currency'] ?? plan['moneda'] ?? 'MXN';
//     final code    = _planCode(plan).toLowerCase();
//     String suffix = '';
//     if (code.contains('mensual'))   suffix = '/mes';
//     if (code.contains('semestral')) suffix = '/6 meses';
//     if (code.contains('anual'))     suffix = '/año';
//     if (precio == null) return _nombrePlan(plan);
//     return '\$$precio $moneda$suffix';
//   }

//   @override
//   Widget build(BuildContext context) {
//     final auth      = context.watch<AuthProvider>();
//     final esPremium = auth.esPremium;
//     final card      = Theme.of(context).cardColor;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Premium'),
//         leading: IconButton(
//             icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
//         actions: [
//           if (_pendingSubId != null && !esPremium)
//             TextButton(
//               onPressed: _procesando ? null : _syncPendiente,
//               child: Text('Verificar pago',
//                   style: TextStyle(color: AppColors.accentGreen,
//                       fontWeight: FontWeight.bold)),
//             ),
//         ],
//       ),
//       body: SingleChildScrollView(child: Column(children: [

//         // ── Header ────────────────────────────────────────────────────────
//         Container(
//           width: double.infinity,
//           padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
//           decoration: const BoxDecoration(gradient: AppColors.purpleGradient),
//           child: Column(children: [
//             Container(padding: const EdgeInsets.all(18),
//                 decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
//                 child: const Icon(Icons.workspace_premium,
//                     color: Colors.white, size: 44)),
//             const SizedBox(height: 14),
//             Text('JobMatch Premium',
//                 style: AppTextStyles.h2.copyWith(color: Colors.white)),
//             const SizedBox(height: 8),
//             Text(esPremium ? '¡Ya tienes Premium activo! 🎉'
//                            : 'Desbloquea todas las funciones',
//                 style: AppTextStyles.bodyLarge.copyWith(
//                     color: Colors.white.withOpacity(0.9)),
//                 textAlign: TextAlign.center),
//           ]),
//         ),

//         Padding(padding: const EdgeInsets.all(20), child: Column(children: [

//           // Aviso sync pendiente
//           if (_pendingSubId != null && !esPremium) ...[
//             Container(
//               padding: const EdgeInsets.all(14),
//               margin: const EdgeInsets.only(bottom: 16),
//               decoration: BoxDecoration(
//                   color: AppColors.accentGreen.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: AppColors.accentGreen.withOpacity(0.4))),
//               child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                 Row(children: [
//                   const Icon(Icons.check_circle_outline,
//                       color: AppColors.accentGreen, size: 18),
//                   const SizedBox(width: 8),
//                   Text('Pago enviado a PayPal',
//                       style: AppTextStyles.subtitle1.copyWith(
//                           color: AppColors.accentGreen, fontWeight: FontWeight.bold)),
//                 ]),
//                 const SizedBox(height: 6),
//                 Text('Si ya aprobaste el pago en PayPal, presiona "Verificar pago" '
//                     'arriba para activar tu suscripción.',
//                     style: AppTextStyles.bodySmall.copyWith(
//                         color: AppColors.textSecondary)),
//               ]),
//             ),
//           ],

//           if (!esPremium) ...[
//             // ── Selector de planes ─────────────────────────────────────
//             if (_cargandoPlanes)
//               const Padding(padding: EdgeInsets.all(24),
//                   child: CircularProgressIndicator())
//             else if (_errorPlanes != null)
//               Column(children: [
//                 Container(padding: const EdgeInsets.all(14),
//                     decoration: BoxDecoration(
//                         color: AppColors.error.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(12)),
//                     child: Text(_errorPlanes!,
//                         style: AppTextStyles.bodyMedium.copyWith(
//                             color: AppColors.error))),
//                 const SizedBox(height: 12),
//                 ElevatedButton.icon(onPressed: _cargarPlanes,
//                     icon: const Icon(Icons.refresh),
//                     label: const Text('Reintentar')),
//                 const SizedBox(height: 24),
//               ])
//             else if (_planes.isNotEmpty) ...[
//               // Tabs de planes
//               Container(
//                 padding: const EdgeInsets.all(4),
//                 decoration: BoxDecoration(color: card,
//                     borderRadius: BorderRadius.circular(14),
//                     boxShadow: [BoxShadow(
//                         color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
//                 child: Row(children: _planes.map((plan) {
//                   final sel = _planSel == plan;
//                   return Expanded(child: GestureDetector(
//                     onTap: () => setState(() => _planSel = plan),
//                     child: AnimatedContainer(
//                       duration: const Duration(milliseconds: 180),
//                       padding: const EdgeInsets.symmetric(vertical: 11),
//                       decoration: BoxDecoration(
//                         color: sel ? AppColors.primaryPurple : Colors.transparent,
//                         borderRadius: BorderRadius.circular(10)),
//                       child: Center(child: Text(_nombrePlan(plan),
//                           style: AppTextStyles.bodyMedium.copyWith(
//                             color: sel ? Colors.white : AppColors.textSecondary,
//                             fontWeight: FontWeight.w600,
//                           ))),
//                     ),
//                   ));
//                 }).toList()),
//               ),
//               const SizedBox(height: 16),

//               // Precio seleccionado
//               if (_planSel != null)
//                 Container(
//                   width: double.infinity, padding: const EdgeInsets.all(20),
//                   decoration: BoxDecoration(color: card,
//                       borderRadius: BorderRadius.circular(18),
//                       border: Border.all(
//                           color: AppColors.primaryPurple.withOpacity(0.3), width: 2)),
//                   child: Column(children: [
//                     Text(_precioLabel(_planSel!),
//                         style: AppTextStyles.h2.copyWith(
//                             color: AppColors.primaryPurple,
//                             fontWeight: FontWeight.w800)),
//                     const SizedBox(height: 4),
//                     Text(_nombrePlan(_planSel!) + ' · Incluye todos los beneficios',
//                         style: AppTextStyles.bodySmall.copyWith(
//                             color: AppColors.textSecondary)),
//                     const SizedBox(height: 4),
//                     Text('ID del plan: ${_planCode(_planSel!)}',
//                         style: AppTextStyles.bodySmall.copyWith(
//                             color: AppColors.textTertiary, fontSize: 10)),
//                   ]),
//                 ),
//               const SizedBox(height: 16),
//             ],
//           ],

//           // ── Beneficios ─────────────────────────────────────────────────
//           _buildBeneficios(card, esPremium),
//           const SizedBox(height: 24),

//           // ── Botón pago ─────────────────────────────────────────────────
//           if (!esPremium && !_cargandoPlanes && _errorPlanes == null) ...[
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: (_procesando || _planSel == null) ? null : _iniciarPago,
//                 style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(14))),
//                 child: _procesando
//                     ? const SizedBox(width: 22, height: 22,
//                         child: CircularProgressIndicator(
//                             color: Colors.white, strokeWidth: 2))
//                     : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//                         const Icon(Icons.payment, color: Colors.white),
//                         const SizedBox(width: 10),
//                         Text('Suscribirse con PayPal — ${_planSel != null ? _precioLabel(_planSel!) : ""}',
//                             style: AppTextStyles.button.copyWith(
//                                 color: Colors.white)),
//                       ]),
//               ),
//             ),
//             const SizedBox(height: 10),
//             Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//               const Icon(Icons.lock_outline, size: 13, color: AppColors.textTertiary),
//               const SizedBox(width: 4),
//               Text('Pago procesado de forma segura por PayPal',
//                   style: AppTextStyles.bodySmall.copyWith(
//                       color: AppColors.textTertiary)),
//             ]),
//           ],

//           if (esPremium)
//             Container(
//               width: double.infinity, padding: const EdgeInsets.all(18),
//               decoration: BoxDecoration(
//                   color: AppColors.accentGreen.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(14),
//                   border: Border.all(color: AppColors.accentGreen.withOpacity(0.3))),
//               child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//                 const Icon(Icons.check_circle, color: AppColors.accentGreen),
//                 const SizedBox(width: 10),
//                 Text('Suscripción Premium activa',
//                     style: AppTextStyles.subtitle1.copyWith(
//                         color: AppColors.accentGreen, fontWeight: FontWeight.bold)),
//               ]),
//             ),
//           const SizedBox(height: 24),
//         ])),
//       ])),
//     );
//   }

//   Widget _buildBeneficios(Color card, bool activo) {
//     const lista = [
//       (Icons.all_inclusive,       'Swipes ilimitados',    'Sin límite diario de vacantes'),
//       (Icons.bolt,                 'Match instantáneo',   'Prioridad en el algoritmo'),
//       (Icons.analytics_outlined,   'Análisis con IA',     'Feedback de tu perfil y CV'),
//       (Icons.visibility_outlined,  'Ver quién te vio',    'Empresas que revisaron tu perfil'),
//       (Icons.notifications_active, 'Alertas prioritarias','Notificación inmediata de matches'),
//       (Icons.workspace_premium,    'Badge Premium',        'Destácate ante reclutadores'),
//     ];
//     return Container(
//       decoration: BoxDecoration(color: card,
//           borderRadius: BorderRadius.circular(18),
//           boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
//             child: Text('¿Qué incluye Premium?', style: AppTextStyles.h4)),
//         ...lista.map((item) => Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           child: Row(children: [
//             Container(padding: const EdgeInsets.all(9),
//                 decoration: BoxDecoration(
//                     color: (activo ? AppColors.accentGreen : AppColors.primaryPurple)
//                         .withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(10)),
//                 child: Icon(item.$1,
//                     color: activo ? AppColors.accentGreen : AppColors.primaryPurple,
//                     size: 20)),
//             const SizedBox(width: 12),
//             Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//               Row(children: [
//                 Text(item.$2, style: AppTextStyles.subtitle1.copyWith(
//                     fontWeight: FontWeight.bold)),
//                 if (activo) ...[const SizedBox(width: 6),
//                   const Icon(Icons.check_circle, color: AppColors.accentGreen, size: 14)],
//               ]),
//               Text(item.$3, style: AppTextStyles.bodySmall.copyWith(
//                   color: AppColors.textSecondary)),
//             ])),
//           ]),
//         )),
//         const SizedBox(height: 8),
//       ]),
//     );
//   }

//   // ── Flujo de pago ─────────────────────────────────────────────────────────
//   Future<void> _iniciarPago() async {
//     if (_planSel == null) return;
//     final planCode = _planCode(_planSel!);
//     if (planCode.isEmpty) {
//       _snack('No se pudo identificar el plan seleccionado', isError: true);
//       return;
//     }

//     setState(() => _procesando = true);
//     try {
//       debugPrint('[PayPal] Creando suscripción con plan_code=$planCode');

//       // 1. Crear suscripción — los 3 campos son REQUERIDOS por el backend
//       final res = await _paypal.crearSuscripcion(
//         planCode: planCode,
//         returnUrl: 'https://jobmatch.com.mx/payments/paypal/mobile-success',
//         cancelUrl: 'https://jobmatch.com.mx/payments/paypal/mobile-cancel',
//       );

//       debugPrint('[PayPal] Respuesta: $res');

//       final approveUrl = res['approve_url'] as String?;
//       final subId      = res['paypal_subscription_id'] as String?;

//       if (approveUrl == null || approveUrl.isEmpty) {
//         _snack('PayPal no devolvió una URL de pago. Intenta de nuevo.', isError: true);
//         return;
//       }

//       setState(() => _pendingSubId = subId);

//       // 2. Abrir PayPal en navegador externo
//       final uri = Uri.parse(approveUrl);
//       if (await canLaunchUrl(uri)) {
//         await launchUrl(uri, mode: LaunchMode.externalApplication);
//       } else {
//         _snack('No se puede abrir el navegador. Intenta de nuevo.', isError: true);
//       }
//     } catch (e) {
//       debugPrint('[PayPal] Error: $e');
//       _snack('Error al iniciar el pago: ${e.toString()}', isError: true);
//     } finally {
//       if (mounted) setState(() => _procesando = false);
//     }
//   }

//   // 3. Sync después de que el usuario aprobó
//   Future<void> _syncPendiente() async {
//     if (_pendingSubId == null) return;
//     setState(() => _procesando = true);
//     try {
//       await _paypal.sincronizar(_pendingSubId!);
//       await context.read<AuthProvider>().verificarSesion();
//       setState(() => _pendingSubId = null);
//       if (mounted) _showSuccessDialog();
//     } catch (e) {
//       _snack('No se pudo verificar el pago. ¿Ya lo aprobaste en PayPal?',
//           isError: true);
//     } finally {
//       if (mounted) setState(() => _procesando = false);
//     }
//   }

//   void _showSuccessDialog() => showDialog(
//     context: context, barrierDismissible: false,
//     builder: (_) => AlertDialog(
//       content: Column(mainAxisSize: MainAxisSize.min, children: [
//         Container(padding: const EdgeInsets.all(18),
//             decoration: BoxDecoration(gradient: AppColors.purpleGradient,
//                 shape: BoxShape.circle),
//             child: const Icon(Icons.workspace_premium, color: Colors.white, size: 44)),
//         const SizedBox(height: 14),
//         Text('¡Bienvenido a Premium! 🎉',
//             style: AppTextStyles.h3, textAlign: TextAlign.center),
//         const SizedBox(height: 8),
//         Text('Tu suscripción fue activada exitosamente.',
//             style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
//             textAlign: TextAlign.center),
//       ]),
//       actions: [SizedBox(width: double.infinity, child: ElevatedButton(
//         onPressed: () { Navigator.pop(context); context.pop(); },
//         child: const Text('¡Empezar!'),
//       ))],
//     ),
//   );

//   void _snack(String msg, {bool isError = false}) =>
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       content: Text(msg),
//       backgroundColor: isError ? AppColors.error : AppColors.accentGreen,
//       behavior: SnackBarBehavior.floating,
//       duration: Duration(seconds: isError ? 5 : 2),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//     ));
// }