import 'package:flutter/material.dart';

void main() {
  runApp(const SamDriveApp());
}

class SamDriveApp extends StatefulWidget {
  const SamDriveApp({super.key});

  @override
  State<SamDriveApp> createState() => _SamDriveAppState();
}

class _SamDriveAppState extends State<SamDriveApp> {
  ThemeMode _themeMode = ThemeMode.light;
  String _appName = 'แซม';
  String _primaryEmail = 'somchai.dev@gmail.com';
  String _appPin = '1234';
  bool _isAppUnlocked = false;

  void _toggleTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appName,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _isAppUnlocked
          ? SamHomeScreen(
              appName: _appName,
              primaryEmail: _primaryEmail,
              onLockApp: () => setState(() => _isAppUnlocked = false),
              onThemeChanged: _toggleTheme,
            )
          : SamAppLockScreen(
              appName: _appName,
              primaryEmail: _primaryEmail,
              correctPin: _appPin,
              onUnlocked: () => setState(() => _isAppUnlocked = true),
              onPinReset: (newPin) {
                setState(() {
                  _appPin = newPin;
                  _isAppUnlocked = true;
                });
              },
            ),
    );
  }
}

class SamAppLockScreen extends StatefulWidget {
  final String appName;
  final String primaryEmail;
  final String correctPin;
  final VoidCallback onUnlocked;
  final ValueChanged<String> onPinReset;

  const SamAppLockScreen({
    super.key,
    required this.appName,
    required this.primaryEmail,
    required this.correctPin,
    required this.onUnlocked,
    required this.onPinReset,
  });

  @override
  State<SamAppLockScreen> createState() => _SamAppLockScreenState();
}

class _SamAppLockScreenState extends State<SamAppLockScreen> {
  String _entered = '';
  String _error = '';

  void _pressDigit(String d) {
    if (_entered.length >= 4) return;
    setState(() {
      _error = '';
      _entered += d;
    });
    if (_entered.length == 4) {
      if (_entered == widget.correctPin) {
        widget.onUnlocked();
      } else {
        setState(() {
          _error = 'รหัส PIN ไม่ถูกต้อง';
          _entered = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF10B981)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'ซ',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.appName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'เมลหลัก: ${widget.primaryEmail}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _entered.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? Colors.blueAccent : Colors.white24,
                      ),
                    );
                  }),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'])
                      ElevatedButton(
                        onPressed: () => _pressDigit(d),
                        child: Text(d, style: const TextStyle(fontSize: 18)),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onUnlocked,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('สแกนนิ้วมือ'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: widget.onUnlocked,
                      icon: const Icon(Icons.face),
                      label: const Text('สแกนใบหน้า'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SamHomeScreen extends StatefulWidget {
  final String appName;
  final String primaryEmail;
  final VoidCallback onLockApp;
  final ValueChanged<ThemeMode> onThemeChanged;

  const SamHomeScreen({
    super.key,
    required this.appName,
    required this.primaryEmail,
    required this.onLockApp,
    required this.onThemeChanged,
  });

  @override
  State<SamHomeScreen> createState() => _SamHomeScreenState();
}

class _SamHomeScreenState extends State<SamHomeScreen> {
  String _selectedCategory = 'all';

  static String classifyCategory(String mime, String name) {
    final m = mime.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (m.startsWith('image/') || ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) return 'image';
    if (m.startsWith('video/') || ['mp4', 'mov', 'webm', 'mkv'].contains(ext)) return 'video';
    if (m.contains('zip') || m.contains('rar') || ['zip', 'rar', '7z'].contains(ext)) return 'zip';
    if (m.contains('pdf') || m.contains('document') || m.contains('sheet') || ['pdf', 'docx', 'xlsx', 'txt'].contains(ext)) {
      return 'document';
    }
    return 'other';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appName),
        actions: [
          IconButton(
            onPressed: () => widget.onThemeChanged(ThemeMode.light),
            icon: const Icon(Icons.light_mode),
            tooltip: 'ธีมสว่าง',
          ),
          IconButton(
            onPressed: () => widget.onThemeChanged(ThemeMode.dark),
            icon: const Icon(Icons.dark_mode),
            tooltip: 'ธีมมืด',
          ),
          IconButton(
            onPressed: widget.onLockApp,
            icon: const Icon(Icons.lock),
            tooltip: 'ล็อกแอป',
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                for (final cat in [
                  {'id': 'all', 'label': '📁 ทั้งหมด'},
                  {'id': 'image', 'label': '🖼️ รูปภาพ'},
                  {'id': 'video', 'label': '🎬 วิดีโอ'},
                  {'id': 'document', 'label': '📄 เอกสาร'},
                  {'id': 'zip', 'label': '🗜️ ไฟล์ ZIP'},
                  {'id': 'other', 'label': '📦 อื่นๆ'},
                  {'id': 'vault', 'label': '🔐 ตู้เซฟส่วนตัว'},
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat['label']!),
                      selected: _selectedCategory == cat['id'],
                      onSelected: (_) => setState(() => _selectedCategory = cat['id']!),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Text('หมวดหมู่ที่เลือก: $_selectedCategory (เชื่อมต่อ Google Drive API v3)'),
            ),
          ),
        ],
      ),
    );
  }
}
