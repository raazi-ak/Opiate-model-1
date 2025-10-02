import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

const String kApi = 'http://localhost:8000';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
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
  List<PlatformFile> files = [];
  bool busy = false;
  String msg = '';
  String obj = '';
  final List<_Msg> items = [];
  final ScrollController sc = ScrollController();
  final TextEditingController tc = TextEditingController();
  final TextEditingController objController = TextEditingController();

  Future<void> pickFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    setState(() { files = res.files; });
  }

  Future<void> upload() async {
    if (files.isEmpty) return;
    setState(() { busy = true; });
    try {
      final uri = Uri.parse('$kApi/upload');
      final req = http.MultipartRequest('POST', uri);
      for (final f in files) {
        if (f.bytes != null) {
          req.files.add(http.MultipartFile.fromBytes('files', f.bytes!, filename: f.name));
        } else if (f.path != null) {
          req.files.add(await http.MultipartFile.fromPath('files', f.path!));
        }
      }
      final resp = await req.send();
      await http.Response.fromStream(resp);
    } finally {
      if (mounted) setState(() { busy = false; });
    }
  }

  Future<void> ingest() async {
    setState(() { busy = true; });
    try {
      final resp = await http.post(Uri.parse('$kApi/ingest'));
      if (resp.statusCode != 200) {
        // ignore
      }
    } finally {
      if (mounted) setState(() { busy = false; });
    }
  }

  Future<void> chat() async {
    if (msg.trim().isEmpty) return;
    setState(() {
      busy = true;
      items.add(_Msg(role: 'user', text: msg));
    });
    tc.clear();
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$kApi/chat'));
      req.fields['message'] = msg;
      if (obj.isNotEmpty) req.fields['objective'] = obj;
      req.fields['k'] = '5';
      final res = await req.send();
      final body = await http.Response.fromStream(res);
      if (body.statusCode == 200) {
        final m = jsonDecode(body.body) as Map<String, dynamic>;
        final a = (m['answer'] ?? '').toString();
        final r = (m['references'] as List).map((e) => e.toString()).toList();
        setState(() { items.add(_Msg(role: 'assistant', text: a, refs: r)); });
      } else {
        setState(() { items.add(_Msg(role: 'assistant', text: 'Error: ${body.statusCode}')); });
      }
    } catch (e) {
      setState(() { items.add(_Msg(role: 'assistant', text: 'Error: $e')); });
    } finally {
      if (mounted) {
        setState(() { busy = false; });
        await Future.delayed(const Duration(milliseconds: 100));
        if (sc.hasClients) sc.animateTo(sc.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Study Assistant',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (files.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${files.length} file${files.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'upload':
                  pickFiles();
                  break;
                case 'ingest':
                  if (files.isNotEmpty) {
                    upload().then((_) => ingest());
                  }
                  break;
                case 'clear':
                  setState(() {
                    files.clear();
                    items.clear();
                    obj = '';
                    objController.clear();
                  });
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'upload',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, size: 20),
                    SizedBox(width: 8),
                    Text('Upload Files'),
                  ],
                ),
              ),
              if (files.isNotEmpty)
                const PopupMenuItem(
                  value: 'ingest',
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 20),
                      SizedBox(width: 8),
                      Text('Process Files'),
                    ],
                  ),
                ),
              if (files.isNotEmpty || items.isNotEmpty)
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 20),
                      SizedBox(width: 8),
                      Text('Clear All'),
                    ],
                  ),
                ),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (obj.isNotEmpty || files.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (obj.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flag, size: 16, color: Color(0xFF6366F1)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Objective: $obj',
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (files.isNotEmpty) ...[
                    if (obj.isNotEmpty) const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder, size: 16, color: Color(0xFF6366F1)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Files: ${files.map((f) => f.name).join(', ')}',
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? _EmptyState(
                    onUpload: pickFiles,
                    onSetObjective: () => _showObjectiveDialog(),
                  )
                : ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length + (busy ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (busy && i == items.length) {
                        return const _Typing();
                      }
                      final it = items[i];
                      return _Bubble(msg: it);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (items.isEmpty)
                    IconButton(
                      onPressed: () => _showObjectiveDialog(),
                      icon: const Icon(Icons.flag_outlined),
                      tooltip: 'Set Learning Objective',
                    ),
                  if (items.isEmpty)
                    IconButton(
                      onPressed: pickFiles,
                      icon: const Icon(Icons.attach_file),
                      tooltip: 'Upload Files',
                    ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: tc,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Ask me anything about your study materials...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (v) => msg = v,
                        onSubmitted: (_) {
                          if (!busy && msg.trim().isNotEmpty) chat();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      onPressed: busy ? null : () {
                        if (msg.trim().isNotEmpty) chat();
                      },
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showObjectiveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Learning Objective'),
        content: TextField(
          controller: objController,
          decoration: const InputDecoration(
            hintText: 'What do you want to learn or focus on?',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                obj = objController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final String role; // 'user' or 'assistant'
  final String text;
  final List<String> refs;
  _Msg({required this.role, required this.text, List<String>? refs}) : refs = refs ?? const [];
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onUpload;
  final VoidCallback onSetObjective;
  
  const _EmptyState({
    required this.onUpload,
    required this.onSetObjective,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.school,
                size: 40,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to Study Assistant',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload your study materials and set a learning objective to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  icon: Icons.flag_outlined,
                  label: 'Set Objective',
                  onPressed: onSetObjective,
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.upload_file,
                  label: 'Upload Files',
                  onPressed: onUpload,
                  primary: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? const Color(0xFF6366F1) : Colors.white,
        foregroundColor: primary ? Colors.white : const Color(0xFF6366F1),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: primary ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  const _Bubble({required this.msg});
  
  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF6366F1) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  if (msg.refs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isUser 
                            ? Colors.white.withOpacity(0.1)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'References:',
                            style: TextStyle(
                              color: isUser ? Colors.white70 : const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: msg.refs.map((ref) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isUser 
                                    ? Colors.white.withOpacity(0.2)
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                ref,
                                style: TextStyle(
                                  color: isUser ? Colors.white : const Color(0xFF475569),
                                  fontSize: 11,
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(), 
                SizedBox(width: 4),
                _Dot(delay: 200), 
                SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({this.delay = 0});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() { ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ac,
      builder: (context, _) {
        final t = (ac.value + (widget.delay/900)) % 1.0;
        final h = 4.0 + (t < 0.5 ? t : 1-t) * 8;
        return Container(
          width: 8, 
          height: h, 
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.6),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}
