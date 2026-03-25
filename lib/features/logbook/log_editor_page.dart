// log_editor_page.dart
// Halaman Editor Penuh — Markdown Integration

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:logbook_app_001/features/logbook/log_controller.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';

class LogEditorPage extends StatefulWidget {
  /// Data log yang akan diedit. Null berarti mode "Tambah Baru".
  final LogModel? log;

  /// Indeks log dalam notifier. Null jika mode tambah baru.
  final int? index;

  /// Controller tempat addLog / updateLog dipanggil.
  final LogController controller;

  /// Username pengguna yang sedang login (dipakai saat addLog).
  final String username;

  /// Kategori awal yang sudah dipilih (bawaan saat edit / default saat tambah).
  final String initialCategory;

  const LogEditorPage({
    super.key,
    this.log,
    this.index,
    required this.controller,
    required this.username,
    this.initialCategory = 'Pekerjaan',
  });

  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}

class _LogEditorPageState extends State<LogEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late String _selectedCategory;
  late bool _isPublic; // Task 5: visibilitas catatan

  bool _isSaving = false;

  static const List<String> _categories = [
    'Pekerjaan',
    'Pribadi',
    'Urgent',
    'Mechanical',
    'Electronic',
    'Software',
  ];

  // Warna indikator per kategori (dipakai di Dropdown)
  static const Map<String, Color> _categoryColors = {
    'Pekerjaan': Colors.blue,
    'Pribadi': Colors.green,
    'Urgent': Colors.red,
    'Mechanical': Color(0xFF2E7D32), // hijau tua
    'Electronic': Color(0xFF1565C0), // biru tua
    'Software': Color(0xFF6A1B9A), // ungu
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.log?.title ?? '');
    _descController = TextEditingController(
      text: widget.log?.description ?? '',
    );
    _selectedCategory = widget.log?.category ?? widget.initialCategory;
    _isPublic = widget.log?.isPublic ?? false; // Default: Private

    // Listener agar tab Pratinjau terupdate otomatis saat teks berubah
    _descController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul tidak boleh kosong!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.log == null) {
        //  Mode Tambah Baru
        await widget.controller.addLog(
          title,
          _descController.text,
          _selectedCategory,
          widget.username,
          isPublic: _isPublic,
        );
      } else {
        //  Mode Edit
        final logId = widget.log?.id;
        if (logId != null && logId.isNotEmpty) {
          await widget.controller.updateLogById(
            logId,
            title,
            _descController.text,
            _selectedCategory,
            isPublic: _isPublic,
          );
        } else if (widget.index != null && widget.index! >= 0) {
          await widget.controller.updateLog(
            widget.index!,
            title,
            _descController.text,
            _selectedCategory,
            isPublic: _isPublic,
          );
        } else {
          throw StateError(
            'Catatan tidak ditemukan. Silakan kembali dan coba lagi.',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.log == null
                  ? 'Catatan berhasil ditambahkan!'
                  : 'Catatan berhasil diperbarui!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // Kembalikan true : sinyal refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(widget.log == null ? 'Catatan Baru' : 'Edit Catatan'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.edit_note), text: 'Editor'),
              Tab(icon: Icon(Icons.preview), text: 'Pratinjau'),
            ],
          ),
          actions: [
            // Tombol Simpan dengan loading indicator
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: 'Simpan',
                    onPressed: _save,
                  ),
          ],
        ),
        body: TabBarView(
          children: [
            //  Tab 1: Editor
            SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field Judul
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Judul Catatan',
                        hintText: 'Masukkan judul...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dropdown Kategori (dengan indikator warna per item)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      items: _categories.map((cat) {
                        final color = _categoryColors[cat] ?? Colors.indigo;
                        return DropdownMenuItem(
                          value: cat,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(cat),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Toggle Visibilitas — Task 5: Data Privacy
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        secondary: Icon(
                          _isPublic ? Icons.public : Icons.lock,
                          color: _isPublic
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                        title: Text(
                          _isPublic ? 'Publik' : 'Privat',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          _isPublic
                              ? 'Semua anggota tim dapat melihat catatan ini'
                              : 'Hanya Anda yang dapat melihat catatan ini',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        value: _isPublic,
                        onChanged: (val) => setState(() => _isPublic = val),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Label + panduan sintaks Markdown
                    const Text(
                      'Deskripsi (mendukung Markdown)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    // Baris panduan sintaks dengan label kecil
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: const [
                          _MarkdownChip('# Heading'),
                          _MarkdownChip('**Bold**'),
                          _MarkdownChip('*Italic*'),
                          _MarkdownChip('`code`'),
                          _MarkdownChip('- List'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Area Teks Markdown
                    TextField(
                      controller: _descController,
                      maxLines: null,
                      minLines: 12,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tulis deskripsi dengan format Markdown...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    // Ruang ekstra di bawah agar konten tidak pas di tepi layar
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ), // SafeArea
            //  Tab 2: Pratinjau Markdown
            _descController.text.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.preview, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'Belum ada konten untuk ditampilkan.\nTulis di tab Editor terlebih dahulu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: MarkdownBody(
                      data: _descController.text,
                      selectable: true,
                      softLineBreak: true,
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            h1: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            h3: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            p: const TextStyle(fontSize: 14, height: 1.6),
                            code: const TextStyle(
                              fontFamily: 'monospace',
                              backgroundColor: Color(0xFFEEEEEE),
                              fontSize: 13,
                            ),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: Colors.grey.shade400,
                                  width: 4,
                                ),
                              ),
                              color: Colors.grey.shade100,
                            ),
                          ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// label kecil untuk menampilkan panduan sintaks Markdown di atas text area.
class _MarkdownChip extends StatelessWidget {
  final String label;
  const _MarkdownChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: Colors.black87,
        ),
      ),
    );
  }
}
