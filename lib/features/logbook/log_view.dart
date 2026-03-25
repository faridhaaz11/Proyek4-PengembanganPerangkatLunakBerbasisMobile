import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'log_controller.dart';
import 'log_editor_page.dart';
import 'models/log_model.dart';
import 'package:logbook_app_001/features/onboarding/onboarding_view.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:logbook_app_001/helpers/connection_guard.dart';
import 'package:logbook_app_001/helpers/time_formatter.dart';
import 'package:logbook_app_001/services/access_control_service.dart';

class LogView extends StatefulWidget {
  final String username;

  /// Peran pengguna yang sedang login (contoh: 'Ketua', 'Anggota').
  final String role;
  const LogView({super.key, required this.username, this.role = 'Anggota'});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final LogController _controller; // RBAC: diinisialisasi di initState
  late Future<List<LogModel>> _logsFuture;
  final List<String> _categories = [
    'Pekerjaan',
    'Pribadi',
    'Urgent',
    'Mechanical',
    'Electronic',
    'Software',
  ];

  // Offline banner
  bool _isOffline = false;
  bool _isReconnecting = false;
  StreamSubscription<bool>? _connectivitySub;

  /// ID tim bersama — semua user dalam satu tim berbagi teamId yang sama.
  /// Nilai diambil dari APP_TEAM_ID di .env agar mudah dikonfigurasi.
  late final String _teamId;

  @override
  void initState() {
    super.initState();
    // Shared teamId: semua user dalam satu tim menggunakan ID yang sama
    // sehingga data Public bisa terlihat oleh semua anggota tim.
    _teamId = dotenv.env['APP_TEAM_ID'] ?? 'kelompok_01';
    // Inisialisasi controller dengan konteks RBAC pengguna yang sedang login
    _controller = LogController(
      userRole: widget.role,
      userId: widget.username, // untuk kepemilikan & RBAC
      teamId: _teamId, // untuk isolasi tim
    );
    _logsFuture = _loadLogs();

    // Cek status koneksi saat ini (snapshot awal) — tidak menunggu perubahan
    ConnectionGuard.isOnline().then((online) {
      if (!mounted) return;
      setState(() => _isOffline = !online);
    });

    // Pantau perubahan koneksi secara realtime
    _connectivitySub = ConnectionGuard.onConnectivityChanged.listen((online) {
      if (!mounted) return;
      final wasOffline = _isOffline;
      setState(() {
        _isOffline = !online;
        if (online && wasOffline) {
          _isReconnecting = true;
        }
      });
      if (online && wasOffline) {
        // Koneksi pulih: refresh otomatis
        _refreshLogs();
      }
    });

    // Dengarkan perubahan status pending agar ikon cloud per kartu terupdate
    _controller.pendingIdsNotifier.addListener(_onPendingStatusChanged);
  }

  void _onPendingStatusChanged() {
    if (!mounted) return;
    // Paksakan rebuild agar ikon cloud pada kartu mencerminkan status terkini
    setState(() {
      _logsFuture = Future.value(_controller.logs);
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _controller.pendingIdsNotifier.removeListener(_onPendingStatusChanged);
    _searchController.dispose();
    _searchNotifier.dispose();
    super.dispose();
  }

  Future<List<LogModel>> _loadLogs() async {
    await LogHelper.writeLog(
      "UI: Memulai load data (Offline-First)...",
      source: "log_view.dart",
    );
    // loadLogs menangani dua jalur: Hive (instan) lalu Atlas (background).
    // Gunakan _teamId (shared) agar semua member tim bisa melihat data Public.
    await _controller.loadLogs(_teamId);
    await LogHelper.writeLog(
      "UI: Data siap (cache lokal + sync Cloud berjalan di background)",
      source: "log_view.dart",
    );
    return _controller.logs;
  }

  void _refreshLogs() {
    setState(() {
      _logsFuture = _controller
          .loadLogs(_teamId)
          .then((_) => _controller.logs)
          .whenComplete(() {
            if (mounted && _isReconnecting) {
              setState(() => _isReconnecting = false);
            }
          });
    });
  }

  Future<void> _onRefresh() async {
    await LogHelper.writeLog(
      "UI: Pull-to-Refresh dipicu pengguna",
      source: "log_view.dart",
      level: 3,
    );
    await _controller.loadLogs(_teamId);
    if (mounted) {
      setState(() {
        _logsFuture = Future.value(_controller.logs);
      });
    }
  }

  final TextEditingController _searchController = TextEditingController();
  // ValueNotifier untuk filter real-time tanpa fetch ulang ke database
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');

  /// Navigasi ke halaman editor penuh (Langkah 3 — Markdown Integration).
  /// [log] = null → mode tambah baru; non-null → mode edit.
  Future<void> _goToEditor({LogModel? log, int? index}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => LogEditorPage(
          log: log,
          index: index,
          controller: _controller,
          username: widget.username,
          initialCategory: log?.category ?? _categories[0],
        ),
      ),
    );
    // Editor mengembalikan true jika simpan berhasil → refresh daftar
    if (result == true) _refreshLogs();
  }

  void _showDeleteSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Catatan berhasil dihapus!'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Konfirmasi Logout"),
                    content: const Text(
                      "Apakah Anda yakin? Data sudah tersimpan otomatis.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Batal"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingView(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "Ya, Keluar",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Offline — muncul saat koneksi terputus
          if (_isOffline)
            Material(
              elevation: 4,
              child: Container(
                width: double.infinity,
                color: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Offline Mode — Tidak ada koneksi internet. '
                        'Data baru tidak dapat disinkronkan.',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            // ValueListenableBuilder agar suffix icon bereaksi tanpa setState
            child: ValueListenableBuilder<String>(
              valueListenable: _searchNotifier,
              builder: (_, query, child) => TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari catatan...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchNotifier.value = '';
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (value) => _searchNotifier.value = value,
              ),
            ),
          ),
          Expanded(
            // ValueListenableBuilder mendengarkan perubahan query pencarian.
            // Ketika query berubah, hanya bagian list yang dibangun ulang —
            // FutureBuilder tidak me-refetch database karena _logsFuture sama.
            child: ValueListenableBuilder<String>(
              valueListenable: _searchNotifier,
              builder: (context, query, _) {
                return FutureBuilder<List<LogModel>>(
                  future: _logsFuture,
                  builder: (context, snapshot) {
                    // 1. Tampilan saat sedang menunggu respons dari Cloud
                    if ((snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData) ||
                        _isReconnecting) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Menghubungkan ke MongoDB Atlas..."),
                          ],
                        ),
                      );
                    }
                    // 2. Tampilan jika terjadi error koneksi
                    if (snapshot.hasError) {
                      final isOfflineError = snapshot.error is OfflineException;
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOfflineError
                                    ? Icons.wifi_off
                                    : Icons.error_outline,
                                size: 72,
                                color: isOfflineError
                                    ? Colors.orange.shade700
                                    : Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isOfflineError
                                    ? '⚠️ Offline Mode Warning'
                                    : 'Gagal Terhubung',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isOfflineError
                                      ? Colors.orange.shade700
                                      : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text("Coba Lagi"),
                                onPressed: () =>
                                    setState(() => _logsFuture = _loadLogs()),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    // 3. Tampilan jika loading selesai tapi data kosong
                    final logs = snapshot.data ?? [];
                    // Conditional rendering: empty state vs. list view
                    if (logs.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.75,
                            child: _EmptyStateWidget(
                              onAddPressed: () => _goToEditor(),
                            ),
                          ),
                        ),
                      );
                    }
                    // 4. Jika data sudah masuk, tampilkan List
                    // Task 5 — Data Privacy: gunakan controller.getVisibleLogs()
                    // agar logika filter terpusat di controller (testable).
                    final displayLogs = _controller.getVisibleLogs(
                      widget.username,
                    );
                    // Filter real-time menggunakan query dari ValueNotifier
                    final filteredLogs = query.isEmpty
                        ? displayLogs
                        : displayLogs
                              .where(
                                (l) =>
                                    l.title.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ) ||
                                    l.description.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ) ||
                                    l.category.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ),
                              )
                              .toList();
                    if (filteredLogs.isEmpty && query.isNotEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tidak ada hasil untuk "$query"',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Coba kata kunci lain atau periksa ejaan Anda.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          final realIndex = log.id != null
                              ? logs.indexWhere((l) => l.id == log.id)
                              : logs.indexOf(log);
                          // RBAC: swipe-delete hanya aktif jika pengguna punya izin hapus
                          final bool canDelete =
                              AccessControlService.canPerform(
                                widget.role,
                                AccessControlService.actionDelete,
                                isOwner: log.authorId == widget.username,
                              );
                          return Dismissible(
                            key: Key(log.id ?? realIndex.toString()),
                            direction: canDelete
                                ? DismissDirection.endToStart
                                : DismissDirection
                                      .none, // Nonaktifkan swipe jika tidak punya izin
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Konfirmasi Hapus"),
                                  content: Text(
                                    'Yakin ingin menghapus "${log.title}"?\nData yang dihapus tidak dapat dikembalikan.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text("Batal"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text("Hapus"),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) async {
                              if (log.id != null) {
                                await _controller.removeLogById(log.id!);
                              } else if (realIndex >= 0) {
                                await _controller.removeLog(realIndex);
                              }
                              _showDeleteSuccessMessage();
                              _refreshLogs();
                            },
                            background: Container(color: Colors.transparent),
                            secondaryBackground: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Indikator warna kiri berdasarkan kategori
                                    Container(
                                      width: 5,
                                      color: _categoryAccentColor(log.category),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          10,
                                          4,
                                          10,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // ── Ikon sync: hijau = tersinkron, oranye = pending offline ──
                                            Icon(
                                              _controller
                                                      .pendingIdsNotifier
                                                      .value
                                                      .contains(log.id)
                                                  ? Icons.cloud_upload_outlined
                                                  : Icons.cloud_done,
                                              color:
                                                  _controller
                                                      .pendingIdsNotifier
                                                      .value
                                                      .contains(log.id)
                                                  ? Colors.orange
                                                  : Colors.green,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 10),
                                            // ── Konten utama ───────────────
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Judul
                                                  Text(
                                                    log.title,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 3),
                                                  // Deskripsi — 1 baris tanpa simbol Markdown
                                                  Text(
                                                    _stripMarkdown(
                                                      log.description,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  // Baris bawah: waktu + badge kategori + badge visibilitas
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.access_time,
                                                        size: 11,
                                                        color: Colors
                                                            .grey
                                                            .shade500,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        TimeFormatter.relative(
                                                          log.date,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey
                                                              .shade500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // Badge kategori
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              _categoryBgColor(
                                                                log.category,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          log.category,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                _categoryTextColor(
                                                                  log.category,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      // Badge privasi
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 5,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: log.isPublic
                                                              ? Colors
                                                                    .green
                                                                    .shade50
                                                              : Colors
                                                                    .grey
                                                                    .shade200,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                          border: Border.all(
                                                            color: log.isPublic
                                                                ? Colors
                                                                      .green
                                                                      .shade300
                                                                : Colors
                                                                      .grey
                                                                      .shade400,
                                                            width: 0.5,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              log.isPublic
                                                                  ? Icons.public
                                                                  : Icons.lock,
                                                              size: 9,
                                                              color:
                                                                  log.isPublic
                                                                  ? Colors
                                                                        .green
                                                                        .shade700
                                                                  : Colors
                                                                        .grey
                                                                        .shade600,
                                                            ),
                                                            const SizedBox(
                                                              width: 2,
                                                            ),
                                                            Text(
                                                              log.isPublic
                                                                  ? 'Publik'
                                                                  : 'Privat',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color:
                                                                    log.isPublic
                                                                    ? Colors
                                                                          .green
                                                                          .shade700
                                                                    : Colors
                                                                          .grey
                                                                          .shade600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // ── Tombol aksi ────────────────
                                            // Hanya tampil untuk pemilik (owner)
                                            if (log.authorId == widget.username)
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.edit,
                                                      color:
                                                          log.authorId ==
                                                              widget.username
                                                          ? Colors.blue
                                                          : Colors
                                                                .grey
                                                                .shade400,
                                                      size: 20,
                                                    ),
                                                    tooltip:
                                                        log.authorId ==
                                                            widget.username
                                                        ? 'Edit'
                                                        : 'Tidak punya izin',
                                                    // null = tombol tidak aktif
                                                    onPressed:
                                                        log.authorId ==
                                                            widget.username
                                                        ? () => _goToEditor(
                                                            log: log,
                                                            index: realIndex,
                                                          )
                                                        : null,
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(
                                                          minWidth: 32,
                                                          minHeight: 32,
                                                        ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.delete,
                                                      color:
                                                          log.authorId ==
                                                              widget.username
                                                          ? Colors.red
                                                          : Colors
                                                                .grey
                                                                .shade400,
                                                      size: 20,
                                                    ),
                                                    tooltip:
                                                        log.authorId ==
                                                            widget.username
                                                        ? 'Hapus'
                                                        : 'Tidak punya izin',
                                                    // null = tombol tidak aktif
                                                    onPressed:
                                                        log.authorId ==
                                                            widget.username
                                                        ? () async {
                                                            final confirmed = await showDialog<bool>(
                                                              context: context,
                                                              builder: (context) => AlertDialog(
                                                                title: const Text(
                                                                  "Konfirmasi Hapus",
                                                                ),
                                                                content: Text(
                                                                  'Yakin ingin menghapus "${log.title}"?\nData yang dihapus tidak dapat dikembalikan.',
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                          context,
                                                                          false,
                                                                        ),
                                                                    child:
                                                                        const Text(
                                                                          "Batal",
                                                                        ),
                                                                  ),
                                                                  ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor:
                                                                          Colors
                                                                              .red,
                                                                      foregroundColor:
                                                                          Colors
                                                                              .white,
                                                                    ),
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                          context,
                                                                          true,
                                                                        ),
                                                                    child:
                                                                        const Text(
                                                                          "Hapus",
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                            if (confirmed ==
                                                                true) {
                                                              if (log.id !=
                                                                  null) {
                                                                await _controller
                                                                    .removeLogById(
                                                                      log.id!,
                                                                    );
                                                              } else if (realIndex >=
                                                                  0) {
                                                                await _controller
                                                                    .removeLog(
                                                                      realIndex,
                                                                    );
                                                              }
                                                              _showDeleteSuccessMessage();
                                                              _refreshLogs();
                                                            }
                                                          }
                                                        : null,
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(
                                                          minWidth: 32,
                                                          minHeight: 32,
                                                        ),
                                                  ),
                                                ],
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
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // Langkah 3: navigasi ke halaman editor penuh
        onPressed: () => _goToEditor(),
        tooltip: 'Tambah Catatan',
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _categoryBgColor(String cat) {
    switch (cat) {
      case 'Pribadi':
        return Colors.green.shade50;
      case 'Pekerjaan':
        return Colors.blue.shade50;
      case 'Urgent':
        return Colors.red.shade50;
      case 'Mechanical':
        return Colors.green.shade100;
      case 'Electronic':
        return Colors.blue.shade100;
      case 'Software':
        return Colors.purple.shade50;
      default:
        return Colors.indigo.shade50;
    }
  }

  Color _categoryTextColor(String cat) {
    switch (cat) {
      case 'Pribadi':
        return Colors.green.shade700;
      case 'Pekerjaan':
        return Colors.blue.shade700;
      case 'Urgent':
        return Colors.red.shade700;
      case 'Mechanical':
        return const Color(0xFF2E7D32); // hijau tua
      case 'Electronic':
        return const Color(0xFF1565C0); // biru tua
      case 'Software':
        return Colors.purple.shade700;
      default:
        return Colors.indigo.shade700;
    }
  }

  /// Warna solid untuk indikator garis kiri pada Card.
  Color _categoryAccentColor(String cat) {
    switch (cat) {
      case 'Pribadi':
        return Colors.green;
      case 'Pekerjaan':
        return Colors.blue;
      case 'Urgent':
        return Colors.red;
      case 'Mechanical':
        return const Color(0xFF2E7D32); // hijau tua
      case 'Electronic':
        return const Color(0xFF1565C0); // biru tua
      case 'Software':
        return Colors.purple;
      default:
        return Colors.indigo;
    }
  }

  /// Menghapus simbol-simbol Markdown dari teks agar tampilan di kartu
  /// daftar catatan tidak menampilkan karakter seperti #, **, *, `, dsb.
  String _stripMarkdown(String text) {
    return text
        // heading: ## Teks → Teks
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        // bold+italic: ***teks*** atau ___teks___
        .replaceAll(RegExp(r'\*{1,3}|_{1,3}'), '')
        // inline code: `teks`
        .replaceAll(RegExp(r'`+'), '')
        // blockquote: > teks
        .replaceAll(RegExp(r'^>\s*', multiLine: true), '')
        // horizontal rule
        .replaceAll(RegExp(r'^[-*_]{3,}\s*$', multiLine: true), '')
        // unordered list markers: - item atau * item
        .replaceAll(RegExp(r'^[\-\*\+]\s+', multiLine: true), '')
        // ordered list markers: 1. item
        .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
        // link/image syntax: [teks](url) → teks
        .replaceAll(RegExp(r'!?\[([^\]]*?)\]\([^)]*?\)'), r'$1')
        // newlines → spasi agar teks menjadi satu baris
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

//  INFORMATIVE EMPTY STATE
/// Widget empty-state yang animatif: ilustrasi mengambang (float) dengan
/// teks instruksional dan tombol CTA agar pengguna tidak melihat layar kosong.
class _EmptyStateWidget extends StatefulWidget {
  final VoidCallback onAddPressed;
  const _EmptyStateWidget({required this.onAddPressed});

  @override
  State<_EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<_EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    // Animasi mengambang (floating) naik-turun 10px secara terus-menerus
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //  Ilustrasi mengambang
            AnimatedBuilder(
              animation: _floatAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.12),
                        colorScheme.secondary.withValues(alpha: 0.22),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Buku catatan sebagai latar ilustrasi
                      Icon(
                        Icons.menu_book_rounded,
                        size: 90,
                        color: colorScheme.primary.withValues(alpha: 0.25),
                      ),
                      // Ikon pensil di sudut kanan atas
                      Positioned(
                        top: 30,
                        right: 26,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            //  Judul
            Text(
              'Belum ada aktivitas hari ini!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            //  Pesan instruksional
            Text(
              'Mulai mencatat!\nSetiap catatan kecil adalah langkah menuju tujuan besar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            //  Tombol CTA
            FilledButton.icon(
              onPressed: widget.onAddPressed,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Buat Catatan Pertama'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'atau tarik ke bawah untuk memperbarui',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
