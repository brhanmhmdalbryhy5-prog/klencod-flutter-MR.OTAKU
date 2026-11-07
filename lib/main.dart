import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/colors.dart';
import 'core/helpers.dart';
import 'core/theme_manager.dart';
import 'data/app_data.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة Supabase
  await Supabase.initialize(
    url: 'https://sekchgllbimoedsjoumi.supabase.co',
    anonKey: 'sb_publishable_EZLVSUviR39RXi6OP3OqfQ_3j7vMZcU',
  );

  // 2. تهيئة Firebase (مع حماية من الأخطاء)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // 3. تهيئة التخزين المحلي والثيم
  await LocalCache.init();
  await ThemeManager.instance.load();

  // 4. تشغيل التطبيق فوراً
  runApp(const MrOtakuApp());
}

class MrOtakuApp extends StatefulWidget {
  const MrOtakuApp({super.key});

  @override
  State<MrOtakuApp> createState() => _MrOtakuAppState();
}

class _MrOtakuAppState extends State<MrOtakuApp> {
  final AppData data = AppData();
  bool checking = true;

  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    // 5. تحميل الحساب المحلي
    try {
      await data.loadLocalAccount();
    } catch (e) {
      debugPrint('loadLocalAccount error: $e');
    }

    if (mounted) {
      setState(() => checking = false);
    }

    // 6. طلب إذن الإشعارات وحفظ التوكن في الخلفية
    Future.microtask(() async {
      try {
        // طلب الإذن
        NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          // الاشتراك في قناة الإشعارات العامة
          await FirebaseMessaging.instance.subscribeToTopic('all_users');
          debugPrint('✅ Subscribed to FCM all_users topic');
        }

        // ✅ حفظ توكن الهاتف في قاعدة البيانات (بعد التأكد من تسجيل الدخول)
        if (data.hasAccount && data.currentAccountId != null) {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await Supabase.instance.client.from('device_tokens').upsert({
              'account_id': data.currentAccountId,
              'fcm_token': token,
            }, onConflict: 'account_id,fcm_token');
            debugPrint('✅ FCM Token saved for account: ${data.currentAccountId}');
          }
        }
      } catch (e) {
        debugPrint('❌ FCM setup error: $e');
      }
    });

    // 7. تحميل البيانات في الخلفية
    Future.microtask(() async {
      try {
        if (data.hasAccount) {
          final admin = await checkAdminSession(data);
          await data.setAdminSession(admin);
          await data.loadData();
        }
      } catch (e) {
        debugPrint('Background load error: $e');
      }
    });
  }

  ThemeData get theme {
    final primary = ThemeManager.instance.primaryColor;
    final isDark = ThemeManager.instance.isDarkMode;

    final bgColor = isDark ? AppColors.black : Colors.white;
    final cardColor = isDark ? AppColors.cardBlack : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black;

    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: bgColor,
      cardColor: cardColor,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primary,
              onPrimary: Colors.black,
              secondary: primary,
              onSecondary: Colors.black,
              surface: cardColor,
              onSurface: textColor,
            )
          : ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              secondary: primary,
              onSecondary: Colors.white,
              surface: cardColor,
              onSurface: textColor,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: primary,
        centerTitle: true,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgColor,
        indicatorColor: primary.withOpacity(0.25),
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(color: primary, fontWeight: FontWeight.bold),
        ),
        iconTheme: MaterialStateProperty.all(
          IconThemeData(color: primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.inputBlack : Colors.grey.shade200,
        labelStyle: TextStyle(color: primary),
        hintStyle: TextStyle(color: primary.withOpacity(0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: primary.withOpacity(0.4)),
        ),
      ),
      iconTheme: IconThemeData(color: primary),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([data, ThemeManager.instance]),
      builder: (_, __) {
        Widget home = !data.hasAccount
            ? AccountSetupPage(data: data)
            : HomePage(data: data);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'مستر أوتاكو',
          theme: theme,
          home: home,
        );
      },
    );
  }
}