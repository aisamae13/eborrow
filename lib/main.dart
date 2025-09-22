import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart'; // Add this import
import 'landingpage.dart';
import 'loginpage.dart';
import 'bottom_nav.dart';
import 'createnewpasswordpage.dart';
import 'notifications/notification_service.dart'; // Add this import

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ujnzsycdtlwcwlrafjgk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbnpzeWNkdGx3Y3dscmFmamdrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0NzE2MjcsImV4cCI6MjA3MTA0NzYyN30.URXG5ytfPRdG-ZDCq26hCyd0uY18dBUrPa7j0SREUV4',
    debug: kDebugMode,
  );

  // Wrap the app with MultiProvider for notification management
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        // Add other providers here as needed
      ],
      child: const MyApp(),
    ),
  );
}

final supabase = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final Stream<AuthState> _authStateStream;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Create the stream once to avoid multiple listeners
    _authStateStream = supabase.auth.onAuthStateChange;

    // Add auth state logging for debugging
    _authSubscription = _authStateStream.listen((data) {
      debugPrint('Auth state changed: ${data.event}');
      debugPrint('User: ${data.session?.user.email}');
      debugPrint('Session exists: ${data.session != null}');

      // Additional debugging for OAuth flow
      if (data.event == AuthChangeEvent.signedIn) {
        debugPrint('User successfully signed in via ${data.session?.user.appMetadata['provider'] ?? 'email'}');

        // Initialize notifications when user signs in
        final userId = data.session?.user.id;
        if (userId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = navigatorKey.currentContext;
            if (context != null && context.mounted) {
              context.read<NotificationProvider>().initializeRealtime(userId);
            }
          });
        }
      }

      // Clean up notifications when user signs out
      if (data.event == AuthChangeEvent.signedOut) {
        debugPrint('User signed out, cleaning up notifications');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            final provider = context.read<NotificationProvider>();
            provider.dispose(); // This will unsubscribe from real-time updates
          }
        });
      }

      // Handle password recovery event
      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint('Password recovery event detected');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushNamed('/create-password');
          }
        });
      }
    });

    // Handle OAuth redirect for web only
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInitialOAuthRedirect();
      });
    }
  }

  @override
  void dispose() {
    // Properly dispose of the subscription
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes properly
    debugPrint('App lifecycle state changed to: $state');

    if (state == AppLifecycleState.resumed) {
      if (kIsWeb) {
        // Check for OAuth redirect when app resumes on web
        _handleInitialOAuthRedirect();
      } else {
        // For mobile, check if we have a session after resuming
        // This helps catch OAuth callbacks that completed while app was in background
        final currentSession = supabase.auth.currentSession;
        if (currentSession != null) {
          debugPrint('Found existing session after app resume: ${currentSession.user.email}');

          // Re-initialize notifications if needed (helpful for mobile apps that were backgrounded)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = navigatorKey.currentContext;
            if (context != null && context.mounted) {
              context.read<NotificationProvider>().initializeRealtime(currentSession.user.id);
            }
          });
        }
      }
    }
  }

  Future<void> _handleInitialOAuthRedirect() async {
    try {
      final uri = Uri.base;
      debugPrint('Checking URI for OAuth tokens: ${uri.toString()}');

      if (uri.fragment.contains('access_token') || uri.queryParameters.containsKey('access_token')) {
        debugPrint('Found OAuth tokens in URL, processing...');
        await supabase.auth.getSessionFromUrl(uri);
      }

      // Check for password recovery tokens in URL
      if (uri.fragment.contains('type=recovery') || uri.queryParameters.containsKey('type')) {
        final type = uri.queryParameters['type'] ?? uri.fragment.split('type=')[1].split('&')[0];
        if (type == 'recovery') {
          debugPrint('Found password recovery token in URL, processing...');
          await supabase.auth.getSessionFromUrl(uri);
          // Navigation will be handled by the auth state listener
        }
      }
    } catch (e) {
      // Log errors for debugging
      debugPrint('OAuth/Password recovery redirect error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Borrow App',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E4F7A)),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: StreamBuilder<AuthState>(
        stream: _authStateStream,
        builder: (context, snapshot) {
          // Add more detailed logging
          debugPrint('StreamBuilder state: ${snapshot.connectionState}');
          debugPrint('Has session: ${snapshot.data?.session != null}');
          debugPrint('Auth event: ${snapshot.data?.event}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final session = snapshot.data?.session;

          // Handle password recovery separately
          if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
            debugPrint('Showing CreateNewPasswordPage for password recovery');
            return const CreateNewPasswordPage();
          }

          if (session != null) {
            debugPrint('Navigating to BottomNav for user: ${session.user.email}');
            debugPrint('Auth provider: ${session.user.appMetadata['provider']}');
            return const BottomNav();
          } else {
            debugPrint('Navigating to LandingPage - no session');
            return const LandingPage();
          }
        },
      ),
      routes: {
        '/landing': (context) => const LandingPage(),
        '/login': (context) => const LoginPage(),
        '/bottom-nav': (context) => const BottomNav(),
        '/create-password': (context) => const CreateNewPasswordPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}