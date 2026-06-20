// main.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/features/onboarding/onboarding_view.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:logbook_app_001/services/mongo_service.dart';

List<CameraDescription> cameras = [];

void main() async {
  // Wajib untuk operasi asinkron sebelum runApp
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: ${e.code}\nError Message: ${e.description}');
  }

  // Inisialisasi locale Indonesia untuk intl (TimeFormatter)
  await initializeDateFormatting('id_ID');

  // Load konfigurasi dari file .env
  await dotenv.load(fileName: ".env");

  // INISIALISASI HIVE — Wajib sebelum Box digunakan
  await Hive.initFlutter();
  Hive.registerAdapter(LogModelAdapter()); // Adaptor dari log_model.g.dart
  await Hive.openBox<LogModel>('offline_logs'); // Buka box penyimpanan lokal

  await LogHelper.writeLog(
    "App starting — .env loaded",
    source: "main.dart",
    level: 2,
  );

  // Jabat tangan (handshake) dengan MongoDB Atlas sebelum UI tampil
  try {
    await MongoService().connect();
    await LogHelper.writeLog(
      "MongoDB handshake successful — app ready",
      source: "main.dart",
      level: 2,
    );
  } catch (e) {
    await LogHelper.writeLog(
      "MongoDB handshake failed: $e",
      source: "main.dart",
      level: 1,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LogBook App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const OnboardingView(),
    );
  }
}
