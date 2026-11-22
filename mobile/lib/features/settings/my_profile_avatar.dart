import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The private avatar is readable only through the signed-in user's Storage
/// policy. Uses initials when the avatar extension is not deployed yet.
class MyProfileAvatar extends StatefulWidget {
  const MyProfileAvatar({super.key, required this.userId, required this.name,
      this.radius = 36});
  final String userId;
  final String name;
  final double radius;

  @override
  State<MyProfileAvatar> createState() => _MyProfileAvatarState();
}

class _MyProfileAvatarState extends State<MyProfileAvatar> {
  late Future<Uint8List?> _image;

  @override
  void initState() {
    super.initState();
    _image = _fetch();
  }

  @override
  void didUpdateWidget(covariant MyProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.key != widget.key) {
      _image = _fetch();
    }
  }

  Future<Uint8List?> _fetch() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser?.id != widget.userId) return null;
    try {
      final profile = await client.from('profiles')
          .select('avatar_path').eq('id', widget.userId).maybeSingle();
      final path = profile?['avatar_path'] as String?;
      if (path == null || path.isEmpty) return null;
      return await client.storage.from('profile-avatars').download(path);
    } catch (_) {
      // Existing installations without avatar_path remain usable.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _image,
    builder: (context, snapshot) {
      final initial = widget.name.trim().isEmpty ? '?'
          : widget.name.trim().substring(0, 1).toUpperCase();
      final bytes = snapshot.data;
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: const Color(0xFFE7F6F3),
        foregroundColor: const Color(0xFF087E83),
        backgroundImage: bytes == null ? null : MemoryImage(bytes),
        child: bytes == null
            ? Text(initial, style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: widget.radius * .9))
            : null,
      );
    },
  );
}
