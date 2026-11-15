import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../shared/models/app_models.dart';

class AppStateService extends ChangeNotifier {
  static final AppStateService instance = AppStateService._internal();

  AppStateService._internal() {
    Future.microtask(() => startRealtimePolling());
  }

  String supabaseUrl = 'https://dccgwosimmcwfwcffghd.supabase.co';
  String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRjY2d3b3NpbW1jd2Z3Y2ZmZ2hkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ0OTY3MTMsImV4cCI6MjExMDA3MjcxM30.7w6V6RGpil3vZnDqyIE7G4X2IdaP6A4qu-akg0RRk-c';
  String geminiApiKey = '';
  bool isCloudConnected = false;
  String lastSyncStatus = 'جاري الاتصال...';
  Timer? _syncTimer;

  int currentRole = 0;
  bool isAuthenticated = false;
  bool technicianOnlineToggle = true;
  String currentUserName = 'أحمد محمود';
  String currentUserPhone = '01012345678';
  String selectedCity = 'الدوحة - قطر';
  String lastOtp = '1234';

  double customerWallet = 350.0;
  double totalCashbackEarned = 45.0;
  double technicianEarnings = 1850.0;
  String? activeOrderId = 'KH-9041';

  final List<String> egyptCities = const [
    'الدوحة - قطر',
    'لوسيل - قطر',
    'الريان - قطر',
    'الوكرة - قطر',
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'المنصورة',
  ];

  final List<String> notifications = [
    'مرحباً بك في خدمات | KHADAMAT — صيانة منزلك بفخامة وأمان.',
    'كاش باك 10% فوري وضمان 30 يوماً عند السداد الإلكتروني.',
    'طلب توثيق هوية فني جديد بانتظار موافقة الإدارة.',
  ];

  final String heroBannerImageUrl =
      'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&q=85&w=1000';

  final List<ServiceItemModel> services = [
    ServiceItemModel(
      id: 'ac',
      name: 'تكييف وتبريد',
      subtitle: 'غسيل • فريون • صيانة',
      minPrice: 150,
      maxPrice: 550,
      icon: Icons.ac_unit_rounded,
      color: const Color(0xFF0284C7),
      bgImageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?auto=format&fit=crop&q=80&w=600',
    ),
    ServiceItemModel(
      id: 'plumbing',
      name: 'سباكة وتسريبات',
      subtitle: 'خلاطات • مضخات • فلاتر',
      minPrice: 120,
      maxPrice: 400,
      icon: Icons.plumbing_rounded,
      color: const Color(0xFF0F4C81),
      bgImageUrl: 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?auto=format&fit=crop&q=80&w=600',
    ),
    ServiceItemModel(
      id: 'electric',
      name: 'كهرباء وإنارة',
      subtitle: 'لوحات • ثريات • أعطال',
      minPrice: 120,
      maxPrice: 450,
      icon: Icons.bolt_rounded,
      color: const Color(0xFFFF6B00),
      bgImageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&q=80&w=600',
    ),
    ServiceItemModel(
      id: 'appliances',
      name: 'أجهزة منزلية',
      subtitle: 'غسالات • ثلاجات • أفران',
      minPrice: 180,
      maxPrice: 600,
      icon: Icons.kitchen_rounded,
      color: const Color(0xFF4F46E5),
      bgImageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?auto=format&fit=crop&q=80&w=600',
    ),
    ServiceItemModel(
      id: 'carpentry',
      name: 'نجارة وأقفال',
      subtitle: 'أبواب • أقفال ذكية • مطابخ',
      minPrice: 150,
      maxPrice: 500,
      icon: Icons.handyman_rounded,
      color: const Color(0xFFB45309),
      bgImageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&q=80&w=600',
    ),
    ServiceItemModel(
      id: 'cleaning',
      name: 'نظافة وتعقيم',
      subtitle: 'قصور • خزانات • واجهات',
      minPrice: 250,
      maxPrice: 950,
      icon: Icons.cleaning_services_rounded,
      color: const Color(0xFF10B981),
      bgImageUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&q=80&w=600',
    ),
    ServiceItemModel(
      id: 'smarthome',
      name: 'منزل ذكي وكاميرات',
      subtitle: 'كاميرات • إنتركم • شبكات',
      minPrice: 200,
      maxPrice: 800,
      icon: Icons.videocam_rounded,
      color: const Color(0xFF0D9488),
      bgImageUrl: 'https://images.unsplash.com/photo-1558002038-1055907df827?auto=format&fit=crop&q=80&w=600',
    ),
    ServiceItemModel(
      id: 'pest',
      name: 'مكافحة وعزل',
      subtitle: 'مكافحة آفات • عزل أسطح',
      minPrice: 220,
      maxPrice: 750,
      icon: Icons.shield_rounded,
      color: const Color(0xFF7C3AED),
      bgImageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&q=80&w=600',
    ),
  ];

  final List<SparePartItemModel> sparePartsCatalog = [
    SparePartItemModel(id: 'SP-1', name: 'أسطوانة شحن فريون أمريكي R410A', category: 'تكييف وتبريد', brand: 'Honeywell USA', officialPrice: 350, warrantyMonths: 6),
    SparePartItemModel(id: 'SP-2', name: 'كابستور تكييف 50 ميكروفاراد كوري', category: 'تكييف وتبريد', brand: 'Samwha Korea', officialPrice: 160, warrantyMonths: 12),
    SparePartItemModel(id: 'SP-3', name: 'مروحة وحدة خارجية أصلية', category: 'تكييف وتبريد', brand: 'Carrier OEM', officialPrice: 480, warrantyMonths: 12),
    SparePartItemModel(id: 'SP-4', name: 'قلب خلاط مياه سيراميك ألماني', category: 'سباكة وتسريبات', brand: 'Grohe', officialPrice: 150, warrantyMonths: 12),
    SparePartItemModel(id: 'SP-5', name: 'جهاز أوتوماتيك مضخة مياه (فلوماك)', category: 'سباكة وتسريبات', brand: 'Calpeda Italy', officialPrice: 340, warrantyMonths: 12),
    SparePartItemModel(id: 'SP-6', name: 'قاطع كهرباء أوتوماتيك 32 أمبير', category: 'كهرباء وإنارة', brand: 'Schneider', officialPrice: 170, warrantyMonths: 24),
    SparePartItemModel(id: 'SP-7', name: 'مفتاح حماية تسريب أرضي (RCCB)', category: 'كهرباء وإنارة', brand: 'ABB Original', officialPrice: 540, warrantyMonths: 24),
    SparePartItemModel(id: 'SP-8', name: 'طلمبة طرد غسالة أوتوماتيك', category: 'أجهزة منزلية', brand: 'LG OEM', officialPrice: 310, warrantyMonths: 12),
    SparePartItemModel(id: 'SP-9', name: 'قفل باب ذكي بالبصمة والبطاقة', category: 'نجارة وأقفال', brand: 'Yale Smart', officialPrice: 680, warrantyMonths: 24),
  ];

  final List<HomeApplianceModel> homeAppliances = [
    HomeApplianceModel(
      id: 'APP-1',
      name: 'تكييف مركزي / سبليت إنفرتر',
      brand: 'Carrier',
      locationRoom: 'الجناح الرئيسي',
      lastMaintenanceDate: '2026-10-15',
      nextReminderDate: '2027-04-15',
      healthScore: 97,
    ),
    HomeApplianceModel(
      id: 'APP-2',
      name: 'مضخة ضغط مياه أوتوماتيك',
      brand: 'Calpeda',
      locationRoom: 'غرفة الخدمات',
      lastMaintenanceDate: '2026-09-01',
      nextReminderDate: '2027-03-01',
      healthScore: 92,
    ),
  ];

  final List<CompanyItemModel> companies = [
    CompanyItemModel(
      id: 'COMP-1',
      name: 'مؤسسة الدوحة الملكية للصيانة والتكييف',
      specialty: 'تكييف مركزي • كهرباء • عقود سنوية AMC',
      city: 'الدوحة - قطر',
      commercialReg: 'CR-441902',
      taxCard: 'TX-901-334',
      techniciansCount: 28,
      activeAmcContracts: 64,
      rating: 4.9,
      isVerified: true,
    ),
    CompanyItemModel(
      id: 'COMP-2',
      name: 'شركة الرواد الهندسية للخدمات المتكاملة',
      specialty: 'صيانة فيلات • منزل ذكي • سباكة',
      city: 'القاهرة',
      commercialReg: 'CR-884120',
      taxCard: 'TX-552-910',
      techniciansCount: 20,
      activeAmcContracts: 41,
      rating: 4.9,
      isVerified: true,
    ),
  ];

  final List<TechnicianItemModel> technicians = [
    TechnicianItemModel(
      id: 'TECH-1',
      name: 'م. مصطفى السيد',
      specialty: 'تكييف وتبريد',
      city: 'الدوحة - قطر',
      phone: '01066554433',
      distanceKm: 1.1,
      nationalId: '29104150104421',
      idFrontPhoto: 'بطاقة_هوية_مصطفى_أمامي.jpg',
      idBackPhoto: 'بطاقة_هوية_مصطفى_خلفي.jpg',
      certificatePhoto: 'شهادة_اعتماد_تكييف_مركزي.jpg',
      experienceYears: 9,
      walletNumber: '01066554433',
      companyAffiliation: 'مؤسسة الدوحة الملكية',
      rating: 4.9,
      completedJobs: 145,
      isVerified: true,
      approvalStatus: 'approved',
    ),
    TechnicianItemModel(
      id: 'TECH-2',
      name: 'م. حسن عبد السلام',
      specialty: 'سباكة وتسريبات',
      city: 'لوسيل - قطر',
      phone: '01022334455',
      distanceKm: 1.9,
      nationalId: '29308220105519',
      idFrontPhoto: 'بطاقة_هوية_حسن_أمامي.jpg',
      idBackPhoto: 'بطاقة_هوية_حسن_خلفي.jpg',
      certificatePhoto: 'فيش_جنائي_معتمد.jpg',
      experienceYears: 7,
      walletNumber: '01022334455',
      companyAffiliation: 'أسطول خدمات المعتمد',
      rating: 4.8,
      completedJobs: 98,
      isVerified: true,
      approvalStatus: 'approved',
    ),
    TechnicianItemModel(
      id: 'TECH-3',
      name: 'م. كريم طارق (طلب توثيق جديد)',
      specialty: 'كهرباء وإنارة',
      city: 'الدوحة - قطر',
      phone: '01099881122',
      distanceKm: 1.4,
      nationalId: '29611050108834',
      idFrontPhoto: 'هوية_كريم_طارق_أمامي.jpg',
      idBackPhoto: 'هوية_كريم_طارق_خلفي.jpg',
      certificatePhoto: 'شهادة_خبرة_كهرباء_ذكية.jpg',
      experienceYears: 5,
      walletNumber: '01099881122',
      companyAffiliation: 'فني مستقل',
      rating: 4.9,
      completedJobs: 0,
      isVerified: false,
      approvalStatus: 'pending',
    ),
  ];

  final List<OrderItemModel> orders = [
    OrderItemModel(
      id: 'KH-9041',
      serviceName: 'تكييف وتبريد',
      description: 'صيانة دورية وفحص تبريد الجناح الرئيسي',
      attachedPhotos: [
        'قبل_فحص_الوحدة.jpg',
        'بعد_غسيل_وضبط_الفريون.jpg',
        'قطعة_كابستور تكييف 50 ميكروفاراد كوري (160)',
        'وسم_الأمان_العائلي',
      ],
      city: 'الدوحة - قطر',
      address: 'منطقة اللؤلؤة - فيلا 18',
      mapCoordinates: 'GPS متصل',
      appointmentSlot: 'اليوم (04:00 م - 06:00 م)',
      assignmentMode: 'عروض أسعار',
      customerName: 'أحمد محمود',
      customerPhone: '01012345678',
      pinCode: '4829',
      paymentMethod: 'فودافون كاش / إنستا باي',
      statusIndex: 1,
      price: 360,
      technicianId: 'TECH-1',
      technicianName: 'م. مصطفى السيد',
      technicianPhone: '01066554433',
      isPaid: false,
      chatMessages: [
        'تم تعيين م. مصطفى السيد (موثق الهوية ✅) وتفعيل رابط الأمان العائلي.',
        'المقايسة المعتمدة: مصنعية + كابستور رسمي - خصم المعاينة = 360.',
      ],
    ),
  ];

  Map<String, String> get _headers => {
        'apikey': supabaseAnonKey.trim(),
        'Authorization': 'Bearer ${supabaseAnonKey.trim()}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  String get _cleanBaseUrl => supabaseUrl.trim().replaceAll(RegExp(r'/$'), '');

  Future<bool> connectSupabase(String url, String key) {
    return configureSupabaseConnection(url, key);
  }

  Future<bool> configureSupabaseConnection(String url, String key) async {
    supabaseUrl = url.trim();
    supabaseAnonKey = key.trim();
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      isCloudConnected = false;
      lastSyncStatus = 'غير متصل';
      notifyListeners();
      return false;
    }
    final ok = await syncFromSupabase();
    if (ok) {
      startRealtimePolling();
    }
    return ok;
  }

  void startRealtimePolling() {
    _syncTimer?.cancel();
    if (supabaseUrl.trim().isEmpty || supabaseAnonKey.trim().isEmpty) return;
    syncFromSupabase();
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      syncFromSupabase();
    });
  }

  Future<bool> syncFromSupabase() async {
    if (supabaseUrl.trim().isEmpty || supabaseAnonKey.trim().isEmpty) return false;
    try {
      final ordersUri = Uri.parse('$_cleanBaseUrl/rest/v1/orders?select=*&order=created_at.desc');
      final res = await http.get(ordersUri, headers: _headers).timeout(const Duration(seconds: 6));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        if (data.isNotEmpty) {
          orders
            ..clear()
            ..addAll(data.map((item) => OrderItemModel.fromSupabaseJson(item as Map<String, dynamic>)));
          activeOrderId ??= orders.first.id;
        }
        isCloudConnected = true;
        lastSyncStatus = 'متصل حياً (${orders.length})';
      } else {
        isCloudConnected = false;
        lastSyncStatus = 'كود السحابة: ${res.statusCode}';
      }

      final notifUri = Uri.parse('$_cleanBaseUrl/rest/v1/notifications?select=*&order=id.desc&limit=10');
      final notifRes = await http.get(notifUri, headers: _headers).timeout(const Duration(seconds: 5));
      if (notifRes.statusCode >= 200 && notifRes.statusCode < 300) {
        final List<dynamic> nData = jsonDecode(utf8.decode(notifRes.bodyBytes)) as List<dynamic>;
        if (nData.isNotEmpty) {
          notifications
            ..clear()
            ..addAll(nData.map((n) => (n['message'] ?? '').toString()).where((s) => s.isNotEmpty));
        }
      }
      notifyListeners();
      return isCloudConnected;
    } catch (e) {
      isCloudConnected = false;
      lastSyncStatus = 'وضع محلي';
      notifyListeners();
      return false;
    }
  }

  Future<void> _pushOrderToSupabase(OrderItemModel order, {bool isUpdate = false}) async {
    if (supabaseUrl.trim().isEmpty || supabaseAnonKey.trim().isEmpty) return;
    try {
      if (isUpdate) {
        final uri = Uri.parse('$_cleanBaseUrl/rest/v1/orders?id=eq.${order.id}');
        await http.patch(uri, headers: _headers, body: jsonEncode(order.toSupabaseJson()));
      } else {
        final uri = Uri.parse('$_cleanBaseUrl/rest/v1/orders');
        await http.post(uri, headers: _headers, body: jsonEncode(order.toSupabaseJson()));
      }
      await syncFromSupabase();
    } catch (_) {}
  }

  Future<void> _pushNotificationToSupabase(String message) async {
    notifications.insert(0, message);
    notifyListeners();
    if (supabaseUrl.trim().isEmpty || supabaseAnonKey.trim().isEmpty) return;
    try {
      final uri = Uri.parse('$_cleanBaseUrl/rest/v1/notifications');
      await http.post(uri, headers: _headers, body: jsonEncode({'message': message}));
    } catch (_) {}
  }

  Future<AiDiagnosisResultModel> runSmartAiDiagnosis({
    required String descriptionText,
    required String soundPattern,
    required bool hasPhoto,
  }) async {
    final text = '$descriptionText $soundPattern'.toLowerCase();
    if (text.contains('تكييف') || text.contains('فريون') || text.contains('تبريد') || text.contains('طنين')) {
      final parts = sparePartsCatalog.where((p) => p.id == 'SP-1' || p.id == 'SP-2').toList();
      return AiDiagnosisResultModel(
        title: 'ضعف كفاءة التبريد أو كابستور الإقلاع',
        technicalCause: 'يرجح تلف كابستور الوحدة الخارجية أو نقص الفريون R410A.',
        recommendedService: 'تكييف وتبريد',
        suggestedParts: parts,
        estimatedLabor: 180,
      );
    } else if (text.contains('مياه') || text.contains('موتور') || text.contains('تسريب') || text.contains('سباكة')) {
      final parts = sparePartsCatalog.where((p) => p.id == 'SP-4' || p.id == 'SP-5').toList();
      return AiDiagnosisResultModel(
        title: 'خلل أوتوماتيك المضخة (الفلوماك) أو الخلاط',
        technicalCause: 'تقطيع المضخة يدل على تلف الفلوماك أو قلب الخلاط السيراميك.',
        recommendedService: 'سباكة وتسريبات',
        suggestedParts: parts,
        estimatedLabor: 150,
        isUrgentSos: true,
      );
    } else if (text.contains('كهرباء') || text.contains('قفلة') || text.contains('شرز') || text.contains('قاطع')) {
      final parts = sparePartsCatalog.where((p) => p.id == 'SP-6' || p.id == 'SP-7').toList();
      return AiDiagnosisResultModel(
        title: 'حمل زائد في القاطع الكهربائي',
        technicalCause: 'يلزم استبدال القاطع الفرعي 32 أمبير بقطعة أصلية.',
        recommendedService: 'كهرباء وإنارة',
        suggestedParts: parts,
        estimatedLabor: 150,
        isUrgentSos: true,
      );
    } else {
      final parts = sparePartsCatalog.where((p) => p.id == 'SP-8' || p.id == 'SP-9').toList();
      return AiDiagnosisResultModel(
        title: 'فحص وصيانة الأجهزة والأقفال الذكية',
        technicalCause: 'يوصى باستبدال القطعة الأصلية من الكتالوج مع ضمان سنة.',
        recommendedService: 'أجهزة منزلية',
        suggestedParts: parts,
        estimatedLabor: 200,
      );
    }
  }

  OrderItemModel triggerSosEmergencyOrder({
    required String serviceName,
    required String urgentDescription,
    required String address,
  }) {
    final order = createOrder(
      serviceName: serviceName,
      description: '[SOS طوارئ 45 د] $urgentDescription',
      photos: ['قبل_طوارئ_SOS.jpg', 'وسم_SOS', 'وسم_الأمان_العائلي'],
      address: address,
      mapCoords: 'رادار GPS للطوارئ نشط',
      appointmentSlot: 'طوارئ SOS (خلال 45 دقيقة)',
      assignmentMode: 'رادار الطوارئ SOS',
      paymentMethod: 'فودافون كاش / إنستا باي',
      price: 300,
    );
    _pushNotificationToSupabase('🚨 نداء طوارئ SOS #${order.id} ($serviceName)');
    return order;
  }

  void addOfficialSparePartToOrder(String orderId, SparePartItemModel part) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = orders[idx];
    final tag = 'قطعة_${part.name} (${part.officialPrice})';
    if (!order.attachedPhotos.contains(tag)) {
      order.attachedPhotos.add(tag);
      order.price += part.officialPrice;
      order.chatMessages.add('إضافة قطعة رسمية للمقايسة: [${part.name}] (${part.officialPrice}).');
      notifyListeners();
      _pushOrderToSupabase(order, isUpdate: true);
    }
  }

  void approveElectronicQuoteWithInspectionDeduction(String orderId) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = orders[idx];
    if (!order.attachedPhotos.contains('وسم_مقايسة_معتمدة')) {
      order.attachedPhotos.add('وسم_مقايسة_معتمدة');
      order.price = (order.price - 50).clamp(100, 99999);
      order.chatMessages.add('اعتماد المقايسة ✅ وخصم المعاينة (-50). الصافي: ${order.price}.');
      notifyListeners();
      _pushOrderToSupabase(order, isUpdate: true);
    }
  }

  void toggleFamilySafeMode(String orderId) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = orders[idx];
    if (order.attachedPhotos.contains('وسم_الأمان_العائلي')) {
      order.attachedPhotos.remove('وسم_الأمان_العائلي');
    } else {
      order.attachedPhotos.add('وسم_الأمان_العائلي');
      order.chatMessages.add('تم تفعيل رابط الأمان العائلي 🛡️: ${order.familyTrackingLink}');
    }
    notifyListeners();
    _pushOrderToSupabase(order, isUpdate: true);
  }

  void updateSparePartPrice(String partId, int newPrice) {
    final idx = sparePartsCatalog.indexWhere((p) => p.id == partId);
    if (idx != -1) {
      sparePartsCatalog[idx].officialPrice = newPrice.clamp(20, 99999);
      notifyListeners();
    }
  }

  void updateServiceBasePrice(String serviceId, int delta) {
    final idx = services.indexWhere((s) => s.id == serviceId);
    if (idx != -1) {
      services[idx].minPrice = (services[idx].minPrice + delta).clamp(50, 9999);
      services[idx].maxPrice = (services[idx].maxPrice + delta).clamp(100, 99999);
      notifyListeners();
    }
  }

  void toggleTechnicianOnlineStatus() {
    technicianOnlineToggle = !technicianOnlineToggle;
    notifyListeners();
  }

  void addHomeApplianceToPassport({required String name, required String brand, required String room}) {
    homeAppliances.insert(
      0,
      HomeApplianceModel(
        id: 'APP-${homeAppliances.length + 10}',
        name: name,
        brand: brand,
        locationRoom: room,
        lastMaintenanceDate: '2026-11-13',
        nextReminderDate: '2027-05-13',
        healthScore: 100,
      ),
    );
    notifyListeners();
  }

  void registerNewCompany({
    required String name,
    required String specialty,
    required String city,
    required String commercialReg,
    required String taxCard,
    required int fleetCount,
  }) {
    companies.insert(
      0,
      CompanyItemModel(
        id: 'COMP-${companies.length + 10}',
        name: name,
        specialty: specialty,
        city: city,
        commercialReg: commercialReg,
        taxCard: taxCard,
        techniciansCount: fleetCount,
        activeAmcContracts: 1,
      ),
    );
    notifyListeners();
    _pushNotificationToSupabase('اعتماد شركة جديدة في بوابة الأعمال: $name ($commercialReg)');
  }

  void incrementCompanyAmcContract(String compId) {
    final idx = companies.indexWhere((c) => c.id == compId);
    if (idx != -1) {
      companies[idx].activeAmcContracts += 1;
      notifyListeners();
      _pushNotificationToSupabase('إصدار عقد صيانة سنوي AMC جديد عبر ${companies[idx].name}');
    }
  }

  TechnicianItemModel registerNewTechnicianApplication({
    required String name,
    required String phone,
    required String specialty,
    required String city,
    required String nationalId,
    required String idFrontPhoto,
    required String idBackPhoto,
    required String certificatePhoto,
    required int experienceYears,
    required String walletNumber,
    String companyAffiliation = 'فني مستقل',
  }) {
    final id = 'TECH-${technicians.length + 10}';
    final tech = TechnicianItemModel(
      id: id,
      name: name,
      specialty: specialty,
      city: city,
      phone: phone,
      distanceKm: 1.3,
      nationalId: nationalId,
      idFrontPhoto: idFrontPhoto,
      idBackPhoto: idBackPhoto,
      certificatePhoto: certificatePhoto,
      experienceYears: experienceYears,
      walletNumber: walletNumber,
      companyAffiliation: companyAffiliation,
      rating: 5.0,
      completedJobs: 0,
      isVerified: false,
      approvalStatus: 'pending',
    );
    technicians.insert(0, tech);
    notifyListeners();
    _pushNotificationToSupabase('طلب توثيق فني جديد: ($name - $specialty) بانتظار موافقة الإدارة.');
    return tech;
  }

  void reviewTechnicianApplication(String techId, {required bool approve}) {
    final idx = technicians.indexWhere((t) => t.id == techId);
    if (idx == -1) return;
    final tech = technicians[idx];
    tech.isVerified = approve;
    tech.approvalStatus = approve ? 'approved' : 'rejected';
    notifyListeners();
    _pushNotificationToSupabase(
      approve ? 'تم اعتماد هوية الفني (${tech.name}) ✅' : 'تم رفض طلب الفني (${tech.name}) ❌',
    );
  }

  void addOrderMaintenancePhoto(String orderId, {required bool isAfterPhoto}) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = orders[idx];
    final prefix = isAfterPhoto ? 'بعد_الإصلاح' : 'قبل_الصيانة';
    final fileName = '${prefix}_${DateTime.now().second}.jpg';
    order.attachedPhotos.add(fileName);
    order.chatMessages.add('تم توثيق الصورة ($fileName).');
    notifyListeners();
    _pushOrderToSupabase(order, isUpdate: true);
  }

  void markOrderPaid(String orderId, String methodLabel, String referenceCode) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = orders[idx];
    order.isPaid = true;
    final int cashback = order.cashbackAmount;
    customerWallet += cashback;
    totalCashbackEarned += cashback;

    order.chatMessages.add(
      'تم السداد (${order.price}) عبر $methodLabel ($referenceCode) + كاش باك $cashback 🎁',
    );
    notifyListeners();
    _pushOrderToSupabase(order, isUpdate: true);
    _pushNotificationToSupabase('سداد الطلب #${order.id} وإضافة $cashback كاش باك.');
  }

  void rechargeWalletViaSandbox(int amount, String methodLabel, String referenceCode) {
    final int bonus = (amount * 0.10).round();
    customerWallet += (amount + bonus);
    totalCashbackEarned += bonus;
    notifyListeners();
    _pushNotificationToSupabase('شحن المحفظة بـ $amount + هدية $bonus عبر $methodLabel.');
  }

  void setRole(int role) {
    currentRole = role;
    notifyListeners();
  }

  void setCity(String city) {
    selectedCity = city;
    notifyListeners();
  }

  String sendOtp(String phone, String name, int role) {
    currentUserPhone = phone;
    currentUserName = name.trim().isEmpty ? 'عميل خدمات' : name.trim();
    currentRole = role;
    lastOtp = '1234';
    return lastOtp;
  }

  bool verifyOtp(String code) {
    if (code.trim() == '1234' || code.trim() == lastOtp) {
      isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  OrderItemModel createOrder({
    required String serviceName,
    required String description,
    required List<String> photos,
    required String address,
    required String mapCoords,
    required String appointmentSlot,
    required String assignmentMode,
    required String paymentMethod,
    required int price,
    String? manualTechId,
    bool isPaidInitially = false,
    String? paymentRef,
  }) {
    final String pin = (1000 + (DateTime.now().millisecond % 8999)).toString();
    final String id = 'KH-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final approvedTechs = technicians.where((t) => t.isVerified).toList();
    TechnicianItemModel chosenTech = approvedTechs.isNotEmpty ? approvedTechs.first : technicians.first;

    if (manualTechId != null) {
      for (final t in technicians) {
        if (t.id == manualTechId) chosenTech = t;
      }
    } else {
      for (final t in approvedTechs) {
        if (t.specialty == serviceName) {
          chosenTech = t;
          break;
        }
      }
    }

    final initialChats = <String>[
      'تم تعيين الفني المعتمد (${chosenTech.name}) - المعاينة 50 تُخصم عند الإصلاح.',
    ];
    if (isPaidInitially && paymentRef != null) {
      final int cashback = (price * 0.10).round();
      customerWallet += cashback;
      totalCashbackEarned += cashback;
      initialChats.add('سداد مسبق ($price) + كاش باك $cashback.');
    }

    final normalizedPhotos = photos.isEmpty
        ? ['قبل_صورة_العطل.jpg', 'وسم_الأمان_العائلي']
        : photos
            .map((p) => (p.startsWith('قبل_') || p.startsWith('بعد_') || p.startsWith('قطعة_') || p.startsWith('وسم_'))
                ? p
                : 'قبل_$p')
            .toList();

    final order = OrderItemModel(
      id: id,
      serviceName: serviceName,
      description: description.trim().isEmpty ? 'صيانة وفحص ($serviceName)' : description.trim(),
      attachedPhotos: normalizedPhotos,
      city: selectedCity,
      address: address.trim().isEmpty ? selectedCity : address.trim(),
      mapCoordinates: mapCoords,
      appointmentSlot: appointmentSlot,
      assignmentMode: assignmentMode,
      customerName: currentUserName,
      customerPhone: currentUserPhone,
      pinCode: pin,
      paymentMethod: paymentMethod,
      statusIndex: 0,
      price: price,
      technicianId: chosenTech.id,
      technicianName: chosenTech.name,
      technicianPhone: chosenTech.phone,
      isPaid: isPaidInitially,
      chatMessages: initialChats,
    );

    orders.insert(0, order);
    activeOrderId = order.id;
    notifyListeners();

    _pushOrderToSupabase(order, isUpdate: false);
    _pushNotificationToSupabase('طلب جديد #$id ($serviceName) في $selectedCity');
    return order;
  }

  void advanceOrderStatus(String orderId, {int? targetStatus}) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    final order = orders[idx];
    final next = targetStatus ?? (order.statusIndex + 1).clamp(0, 4);
    order.statusIndex = next;

    if (next == 4) {
      order.isPaid = true;
      if (order.afterPhotos.isEmpty) {
        order.attachedPhotos.add('بعد_إتمام_الإصلاح.jpg');
      }
      technicianEarnings += (order.price * 0.85);
      order.chatMessages.add('اكتمل الطلب وصدر الضمان الذهبي (${order.warrantyNumber}).');
    } else {
      order.chatMessages.add('تحديث المرحلة: ${order.statusText}');
    }
    notifyListeners();
    _pushOrderToSupabase(order, isUpdate: true);
  }

  void sendChatMessage(String orderId, String sender, String text) {
    if (text.trim().isEmpty) return;
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;
    orders[idx].chatMessages.add('$sender: ${text.trim()}');
    notifyListeners();
    _pushOrderToSupabase(orders[idx], isUpdate: true);
  }

  OrderItemModel get activeOrder {
    if (activeOrderId != null) {
      for (final o in orders) {
        if (o.id == activeOrderId) return o;
      }
    }
    return orders.first;
  }
}