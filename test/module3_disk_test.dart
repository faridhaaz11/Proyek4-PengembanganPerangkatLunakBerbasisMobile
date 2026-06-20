import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logbook_app_001/features/logbook/log_controller.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/services/i_mongo_service.dart';
import 'package:mocktail/mocktail.dart';

class MockMongoService extends Mock implements IMongoService {}

void main() {
  late MockMongoService mockMongo;
  late Box<LogModel> testBox;
  late Directory tempDir;
  late LogController controller;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

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

    dotenv.loadFromString(
      envString: '',
      mergeWith: {'LOG_LEVEL': '0', 'LOG_MUTE': ''},
      isOptional: true,
    );

    registerFallbackValue(
      LogModel(
        username: 'fallback',
        title: 'fallback',
        date: DateTime.now(),
        description: 'fallback',
        category: 'fallback',
      ),
    );
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_module3_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LogModelAdapter());
    }
    testBox = await Hive.openBox<LogModel>('module3_disk_logs');

    mockMongo = MockMongoService();
    when(() => mockMongo.connect()).thenAnswer((_) async {});
    when(() => mockMongo.close()).thenAnswer((_) async {});
    when(() => mockMongo.insertLog(any())).thenAnswer((_) async {});
    when(() => mockMongo.updateLog(any())).thenAnswer((_) async {});
    when(() => mockMongo.deleteLog(any())).thenAnswer((_) async {});
    when(() => mockMongo.upsertLog(any())).thenAnswer((_) async {});
    when(() => mockMongo.getLogsByTeam(any())).thenAnswer((_) async => []);
    when(
      () => mockMongo.getLogs(username: any(named: 'username')),
    ).thenAnswer((_) async => []);

    controller = LogController(
      userRole: 'user',
      userId: 'faridha',
      teamId: 'team_A',
      mongoService: mockMongo,
      connectivityStream: const Stream.empty(),
      hiveBox: testBox,
    );
  });

  tearDown(() async {
    controller.dispose();
    await testBox.clear();
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Module 3 - Save Data to Disk (addLog)', () {
    test('TC01 - addLog menyimpan data ke Hive lokal', () async {
      await controller.addLog('Judul A', 'Deskripsi A', 'Pekerjaan', 'faridha');

      expect(testBox.values.length, 1);
      expect(testBox.values.first.title, 'Judul A');
    });

    test(
      'TC02 - addLog tetap simpan ke disk saat cloud insert gagal',
      () async {
        when(
          () => mockMongo.insertLog(any()),
        ).thenThrow(Exception('Cloud down'));

        await controller.addLog(
          'Judul B',
          'Deskripsi B',
          'Pekerjaan',
          'faridha',
        );

        expect(testBox.values.length, 1);
        expect(testBox.values.first.title, 'Judul B');
      },
    );

    test(
      'TC03 - addLog menandai pending sync saat cloud insert gagal',
      () async {
        when(
          () => mockMongo.insertLog(any()),
        ).thenThrow(Exception('Cloud down'));

        await controller.addLog(
          'Judul C',
          'Deskripsi C',
          'Pekerjaan',
          'faridha',
        );

        expect(controller.pendingIdsNotifier.value.isNotEmpty, true);
      },
    );
  });
}
