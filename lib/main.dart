
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/colors.dart';
import 'core/helpers.dart';
import 'core/theme_manager.dart';
import 'data/app_data.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screens.dart';

// الإشعارات المحلية
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// قناة الإشعارات المهمة
const AndroidNotificationChannel highImportanceChannel =
    AndroidNotificationChannel(
  'high_importance_channel',
  'إشعارات مهمة',
  description: 'إشعارات فورية للمستخدم',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Supabase
  await Supabase.initialize(
    url: 'https://sekchgllbimoedsjoumi.supabase.co',
    anonKey: 'sb_publishable_EZLVSUviR39RXi6OP3OqfQ_3j7vMZcU',
  );

  // تهيئة Firebase
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // التخزين والثيم
  await LocalCache.init();
  await ThemeManager.instance.load();

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
    _setupNotifications();
  }

  // إعداد الإشعارات
  Future<void> _setupNotifications() async {
    try {
      // تهيئة الإشعارات المحلية
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
      );

      final androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // إنشاء قناة بأهمية قصوى
      await androidPlugin?.createNotificationChannel(
        highImportanceChannel,
      );

      // طلب صلاحية الإشعارات
      await androidPlugin?.requestNotificationsPermission();

      // طلب صلاحية Firebase
      final settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        'Notification permission: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await FirebaseMessaging.instance.subscribeToTopic('all_users');
      }

      // إظهار الإشعارات أثناء فتح التطبيق
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final notification = message.notification;

        if (notification == null) return;

        await flutterLocalNotificationsPlugin.show(
          message.hashCode,
          notification.title ?? 'MR.OTAKU',
          notification.body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              highImportanceChannel.id,
              highImportanceChannel.name,
              channelDescription: highImportanceChannel.description,
              importance: Importance.max,
              priority: Priority.max,
              playSound: true,
              enableVibration: true,
              category: AndroidNotificationCategory.message,
              visibility: NotificationVisibility.public,
              icon: '@mipmap/ic_launcher',
              ticker: 'إشعار جديد من MR.OTAKU',
            ),
          ),
        );
      });

    } catch (e) {
      debugPrint('Notification setup error: $e');
    }
  }

  Future<void> start() async {
    try {
      await data.loadLocalAccount();
    } catch (e) {
      debugPrint('loadLocalAccount error: $e');
    }

    if (mounted) {
      setState(() => checking = false);
    }

    Future.microtask(() async {
      try {
        if (data.hasAccount) {
          final admin = await checkAdminSession(data);
          await data.setAdminSession(admin);
          await data.loadData();

          // حفظ توكن الهاتف
          if (data.currentAccountId != null) {
            final token = await FirebaseMessaging.instance.getToken();

            if (token != null) {
              await Supabase.instance.client
                  .from('device_tokens')
                  .upsert({
                'account_id': data.currentAccountId,
                'fcm_token': token,
              }, onConflict: 'account_id,fcm_token');
            }
          }
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
    final cardColor =
        isDark ? AppColors.cardBlack : Colors.grey.shade100;
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
          TextStyle(
            color: primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: MaterialStateProperty.all(
          IconThemeData(color: primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? AppColors.inputBlack : Colors.grey.shade200,
        labelStyle: TextStyle(color: primary),
        hintStyle: TextStyle(color: primary.withOpacity(0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: primary.withOpacity(0.4),
          ),
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
          borderRadius: const BorderRadius.all(
            Radius.circular(18),
          ),
          side: BorderSide(
            color: primary.withOpacity(0.4),
          ),
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
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
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
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        data,
        ThemeManager.instance,
      ]),
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
