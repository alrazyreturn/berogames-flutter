import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:easy_localization/easy_localization.dart';
import 'providers/user_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/friends_screen.dart';
import 'services/notification_service.dart';
import 'services/ad_service.dart';
import 'models/friend_model.dart';

// ─── Global Navigator Key للـ Navigation من الإشعارات ────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة easy_localization
  await EasyLocalization.ensureInitialized();

  // تهيئة Firebase
  await Firebase.initializeApp();

  // تهيئة AdMob
  await MobileAds.instance.initialize();

  // ─── منع الإعلانات المخلة وغير الملائمة ──────────────────────────────────
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      maxAdContentRating:          MaxAdContentRating.pg,
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent:     TagForUnderAgeOfConsent.unspecified,
    ),
  );

  // تحميل الإعلانات مسبقاً
  AdService().loadInterstitial();
  AdService().loadRewarded();

  // تهيئة خدمة الإشعارات
  final notifService = NotificationService();
  await notifService.init();

  // عند الضغط على إشعار → افتح الشاشة المناسبة
  notifService.onNotificationTap = (data) {
    final type = data['type'] as String? ?? '';
    final ctx  = navigatorKey.currentContext;
    if (ctx == null) return;

    switch (type) {
      case 'chat':
        final fromId   = int.tryParse(data['from_user_id'] ?? '') ?? 0;
        final fromName = data['from_name'] ?? 'صديق';
        if (fromId > 0) {
          final friend = FriendModel(
            friendshipId: 0,
            userId:       fromId,
            name:         fromName,
          );
          Navigator.of(navigatorKey.currentContext!).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(friend: friend),
            ),
          );
        }
        break;
      case 'friend_request':
        Navigator.of(navigatorKey.currentContext!).push(
          MaterialPageRoute(builder: (_) => const FriendsScreen()),
        );
        break;
      case 'game_invite':
        Navigator.of(navigatorKey.currentContext!).popUntil((r) => r.isFirst);
        break;
    }
  };

  // تحميل بيانات الجلسة
  final userProvider = UserProvider();
  await userProvider.loadFromStorage();

  runApp(
    EasyLocalization(
      // اللغات المدعومة
      supportedLocales: const [
        Locale('ar'), // العربية (افتراضي)
        Locale('en'), // English
        Locale('tr'), // Türkçe
      ],
      path:            'assets/translations',
      fallbackLocale:  const Locale('ar'),
      startLocale:     const Locale('ar'),
      child: ChangeNotifierProvider.value(
        value: userProvider,
        child: const BeroGamesApp(),
      ),
    ),
  );
}

class BeroGamesApp extends StatelessWidget {
  const BeroGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    'BeroGames',
      debugShowCheckedModeBanner: false,
      navigatorKey:             navigatorKey,

      // ─── إعدادات اللغة والاتجاه ─────────────────────────────────────────
      localizationsDelegates: context.localizationDelegates,
      supportedLocales:       context.supportedLocales,
      locale:                 context.locale,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
