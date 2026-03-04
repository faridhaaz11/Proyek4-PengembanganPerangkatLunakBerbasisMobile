import 'dart:async';
import 'package:flutter/material.dart';
import 'log_controller.dart';
import 'models/log_model.dart';
import 'package:logbook_app_001/features/onboarding/onboarding_view.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:logbook_app_001/helpers/connection_guard.dart';
import 'package:logbook_app_001/helpers/time_formatter.dart';
import 'package:logbook_app_001/services/mongo_service.dart';

class LogView extends StatefulWidget {
  final String username;
  const LogView({Key? key, required this.username}) : super(key: key);

  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final LogController _controller = LogController();
  late Future<List<LogModel>> _logsFuture;
  final List<String> _categories = ['Pekerjaan', 'Pribadi', 'Urgent'];
  String _selectedCategory = 'Pekerjaan';

  // Offline banner
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _logsFuture = _loadLogs();

    // Pantau perubahan koneksi secara realtime
    _connectivitySub = ConnectionGuard.onConnectivityChanged.listen((online) {
      if (!mounted) return;
      setState(() => _isOffline = !online);
      if (online && _isOffline) {
        // Koneksi pulih: refresh otomatis
        _refreshLogs();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<LogModel>> _loadLogs() async {
    await LogHelper.writeLog(
      "UI: Memulai koneksi ke MongoDB Atlas...",
      source: "log_view.dart",
    );
    await MongoService().connect().timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception(
        "Koneksi Cloud Timeout. Periksa sinyal/IP Whitelist.",
      ),
    );
    await LogHelper.writeLog(
      "UI: Koneksi berhasil, mengambil data...",
      source: "log_view.dart",
    );
    await _controller.loadFromDisk(username: widget.username);
    return _controller.logs;
  }

  void _refreshLogs() {
    setState(() {
      _logsFuture = _controller
          .loadFromDisk(username: widget.username)
          .then((_) => _controller.logs);
    });
  }

  Future<void> _onRefresh() async {
    await LogHelper.writeLog(
      "UI: Pull-to-Refresh dipicu pengguna",
      source: "log_view.dart",
      level: 3,
    );
    await _controller.loadFromDisk(username: widget.username);
    if (mounted) {
      setState(() {
        _logsFuture = Future.value(_controller.logs);
      });
    }
  }

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Logbook - ${widget.username}'),
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
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari catatan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
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
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LogModel>>(
              future: _logsFuture,
              builder: (context, snapshot) {
                // 1. Tampilan saat sedang menunggu respons dari Cloud
                if (snapshot.connectionState == ConnectionState.waiting) {
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
                if (logs.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text("Data Kosong"),
                              SizedBox(height: 8),
                              Text(
                                "Tarik ke bawah untuk memperbarui",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                // 4. Jika data sudah masuk, tampilkan List
                final filteredLogs = _searchQuery.isEmpty
                    ? logs
                    : logs
                          .where(
                            (l) =>
                                l.title.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ||
                                l.description.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ||
                                l.category.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ),
                          )
                          .toList();
                if (filteredLogs.isEmpty && _searchQuery.isNotEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Tidak ada hasil ditemukan'),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      final realIndex = logs.indexOf(log);
                      return Dismissible(
                        key: Key(log.id?.oid ?? realIndex.toString()),
                        direction: DismissDirection.endToStart,
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
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Hapus"),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) async {
                          await _controller.removeLog(realIndex);
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
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            isThreeLine: true,
                            leading: const Icon(
                              Icons.cloud_done,
                              color: Colors.green,
                            ),
                            title: Text(log.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(log.description),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        TimeFormatter.relative(log.date),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        log.category,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.indigo.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () =>
                                      _showEditLogDialog(realIndex, log),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
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
                                    if (confirmed == true) {
                                      await _controller.removeLog(realIndex);
                                      _refreshLogs();
                                    }
                                  },
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
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLogDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddLogDialog() {
    _selectedCategory = _categories[0];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tambah Catatan Baru"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: "Judul Catatan"),
            ),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(hintText: "Isi Deskripsi"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategory = val ?? _categories[0];
                });
              },
              decoration: const InputDecoration(
                labelText: "Kategori",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _controller.addLog(
                _titleController.text,
                _contentController.text,
                _selectedCategory,
                widget.username,
              );
              _titleController.clear();
              _contentController.clear();
              if (mounted) Navigator.pop(context);
              _refreshLogs();
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  void _showEditLogDialog(int index, LogModel log) {
    _titleController.text = log.title;
    _contentController.text = log.description;
    _selectedCategory = log.category;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Catatan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleController),
            TextField(controller: _contentController),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategory = val ?? _categories[0];
                });
              },
              decoration: const InputDecoration(
                labelText: "Kategori",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _controller.updateLog(
                index,
                _titleController.text,
                _contentController.text,
                _selectedCategory,
              );
              _titleController.clear();
              _contentController.clear();
              if (mounted) Navigator.pop(context);
              _refreshLogs();
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }
}
