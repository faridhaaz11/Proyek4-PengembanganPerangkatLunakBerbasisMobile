import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';

const bool _runMongoIntegration = bool.fromEnvironment(
  'RUN_MONGO_INTEGRATION',
  defaultValue: false,
);

void main() {
  const String sourceFile = "connection_test.dart";

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock plugin connectivity_plus agar tidak terjadi MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (MethodCall call) async {
            if (call.method == 'check') {
              return ['wifi'];
            }
            return null;
          },
        );

    // Memuat env sekali di awal untuk semua test
    await dotenv.load(fileName: ".env");
  });

  test(
    'Memastikan koneksi ke MongoDB Atlas berhasil via MongoService',
    () async {
      final mongoService = MongoService();

      if ((dotenv.env['MONGODB_URI'] ?? '').trim().isEmpty) {
        await LogHelper.writeLog(
          "SKIP: MONGODB_URI tidak tersedia, melewati integration test koneksi",
          source: sourceFile,
          level: 2,
        );
        return;
      }

      // Memanfaatkan LogHelper baru yang sudah pakai dev.log dan print berwarna
      await LogHelper.writeLog(
        "--- START CONNECTION TEST ---",
        source: sourceFile,
      );

      try {
        // Mengetes koneksi
        await mongoService.connect();

        // Ekspektasi: URI tidak null dan koneksi berhasil
        expect(dotenv.env['MONGODB_URI'], isNotNull);

        await LogHelper.writeLog(
          "SUCCESS: Terhubung ke MongoDB Atlas",
          source: sourceFile,
          level: 2, // INFO (Hijau)
        );
      } catch (e) {
        await LogHelper.writeLog(
          "ERROR: Kegagalan koneksi - $e",
          source: sourceFile,
          level: 1, // ERROR (Merah)
        );
        fail("Koneksi gagal: $e");
      } finally {
        // Selalu tutup koneksi agar tidak menggantung di dashboard Atlas
        await mongoService.close();
        await LogHelper.writeLog("--- END TEST ---", source: sourceFile);
      }
    },
    skip: !_runMongoIntegration
        ? 'Integration test MongoDB dinonaktifkan default. Jalankan dengan --dart-define=RUN_MONGO_INTEGRATION=true'
        : false,
  );
}
