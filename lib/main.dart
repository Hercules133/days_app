import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisiere Benachrichtigungen
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

  const LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(defaultActionName: 'Open notification');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
    linux: initializationSettingsLinux,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nur noch...',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
      locale: const Locale('de', 'DE'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? targetDate;
  int? initialDaysCount; // Speichert die ursprüngliche Anzahl der Tage
  Set<String> checkedDates = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    // Permission handler funktioniert nur auf Android und iOS
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString('target_date');
    final checkedList = prefs.getStringList('checked_dates') ?? [];
    final savedInitialDays = prefs.getInt('initial_days_count');
    final lastOpenDateString = prefs.getString('last_open_date');

    setState(() {
      if (dateString != null) {
        targetDate = DateTime.parse(dateString);
      }
      checkedDates = checkedList.toSet();
      initialDaysCount = savedInitialDays;
      isLoading = false;
    });

    // Automatisches Abhaken für verpasste Tage
    if (lastOpenDateString != null && targetDate != null) {
      await _checkMissedDays(lastOpenDateString);
    }

    // Speichere heutiges Datum als letztes Öffnungsdatum
    final today = DateTime.now();
    await prefs.setString(
      'last_open_date',
      DateFormat('yyyy-MM-dd').format(today),
    );

    if (targetDate != null) {
      await _scheduleDailyNotification();
    }
  }

  Future<void> _checkMissedDays(String lastOpenDateString) async {
    final lastOpenDate = DateTime.parse(lastOpenDateString);
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final lastOpenNormalized = DateTime(
      lastOpenDate.year,
      lastOpenDate.month,
      lastOpenDate.day,
    );

    final daysSinceLastOpen = todayNormalized
        .difference(lastOpenNormalized)
        .inDays;

    // Wenn mindestens 2 Tage vergangen sind (es gibt verpasste Tage zwischen letztem Öffnen und heute)
    if (daysSinceLastOpen > 1) {
      final daysToAdd = <String>[];

      // Füge nur die verpassten Tage hinzu (NICHT heute)
      // i startet bei 1 (Tag nach letztem Öffnen) und endet bei daysSinceLastOpen - 1 (Tag vor heute)
      for (int i = 1; i < daysSinceLastOpen; i++) {
        final missedDate = lastOpenNormalized.add(Duration(days: i));
        final missedDateString = DateFormat('yyyy-MM-dd').format(missedDate);

        // Nur hinzufügen, wenn noch nicht abgehakt
        if (!checkedDates.contains(missedDateString)) {
          daysToAdd.add(missedDateString);
        }
      }

      if (daysToAdd.isNotEmpty) {
        setState(() {
          checkedDates.addAll(daysToAdd);
        });
        await _saveData();

        // Zeige Info-Snackbar
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${daysToAdd.length} verpasste ${daysToAdd.length == 1 ? "Tag wurde" : "Tage wurden"} automatisch abgehakt',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        }
      }
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    if (targetDate != null) {
      await prefs.setString('target_date', targetDate!.toIso8601String());
    }
    if (initialDaysCount != null) {
      await prefs.setInt('initial_days_count', initialDaysCount!);
    }
    await prefs.setStringList('checked_dates', checkedDates.toList());
  }

  Future<void> _scheduleDailyNotification() async {
    await flutterLocalNotificationsPlugin.cancelAll();

    if (targetDate == null) return;

    final daysRemaining = _calculateDaysRemaining();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'daily_countdown',
          'Täglicher Countdown',
          channelDescription: 'Tägliche Erinnerung an verbleibende Tage',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    // Plane tägliche Benachrichtigung um 9:00 Uhr
    await flutterLocalNotificationsPlugin.periodicallyShow(
      0,
      'Nur noch...',
      'Noch $daysRemaining Tage bis zum Ziel!',
      RepeatInterval.daily,
      notificationDetails,
    );
  }

  int _calculateDaysRemaining() {
    if (targetDate == null || initialDaysCount == null) return 0;
    // Countdown = Ursprüngliche Tage - Abgehakte Tage
    return initialDaysCount! - checkedDates.length;
  }

  int _calculateCheckedDays() {
    return checkedDates.length;
  }

  String _getTodayString() {
    final today = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(today);
  }

  bool _isTodayChecked() {
    return checkedDates.contains(_getTodayString());
  }

  Future<void> _checkToday() async {
    setState(() {
      checkedDates.add(_getTodayString());
    });
    await _saveData();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('de', 'DE'),
      helpText: 'Zieldatum auswählen',
      cancelText: 'Abbrechen',
      confirmText: 'OK',
    );

    if (picked != null) {
      // Berechne die ursprüngliche Anzahl der Tage
      final today = DateTime.now();
      final difference = picked.difference(
        DateTime(today.year, today.month, today.day),
      );

      setState(() {
        targetDate = picked;
        initialDaysCount =
            difference.inDays; // Speichere die ursprüngliche Anzahl
        checkedDates.clear(); // Reset beim Ändern des Datums
      });
      await _saveData();
      await _scheduleDailyNotification();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (targetDate == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nur noch...')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),
                Text(
                  'Willkommen!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Wähle ein Zieldatum aus, um deinen Countdown zu starten.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.event),
                  label: const Text('Datum auswählen'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final daysRemaining = _calculateDaysRemaining();
    final checkedDays = _calculateCheckedDays();
    final todayChecked = _isTodayChecked();
    final formattedDate = DateFormat('dd.MM.yyyy').format(targetDate!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nur noch...'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.settings,
                    size: 48,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Einstellungen',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Zieldatum ändern'),
              subtitle: Text(formattedDate),
              onTap: () {
                Navigator.pop(context);
                _selectDate(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Countdown zurücksetzen'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Zurücksetzen?'),
                    content: const Text(
                      'Möchtest du den Countdown wirklich zurücksetzen? Alle abgehakten Tage werden gelöscht.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Abbrechen'),
                      ),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            checkedDates.clear();
                          });
                          _saveData();
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: const Text('Zurücksetzen'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hauptanzeige: Verbleibende Tage
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Text(
                        'Noch',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$daysRemaining',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 80,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        daysRemaining == 1 ? 'Tag' : 'Tage',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Zieldatum
              Text(
                'bis zum $formattedDate',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 48),

              // Fortschrittsanzeige
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Abgehakte Tage',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                                ),
                          ),
                          Text(
                            '$checkedDays',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: initialDaysCount != null && initialDaysCount! > 0
                            ? checkedDays / initialDaysCount!
                            : 0.0,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      if (initialDaysCount != null &&
                          initialDaysCount! > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${((checkedDays / initialDaysCount!) * 100).toStringAsFixed(0)}% geschafft',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Heute abhaken Button
              if (!todayChecked)
                FilledButton.icon(
                  onPressed: _checkToday,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Heute abhaken'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                )
              else
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(
                            context,
                          ).colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Heute bereits abgehakt!',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
