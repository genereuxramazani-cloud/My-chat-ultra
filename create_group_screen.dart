import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';
import '../main.dart' show globalProfileService;
import '../widgets/user_avatar_widget.dart';
import 'group_chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  final String userPhone;

  const CreateGroupScreen({super.key, required this.userPhone});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _selectedMembers = <String>{};
  Uint8List? _photoBytes;
  bool _isSaving = false;

  Future<void> _pickGroupPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _photoBytes = bytes;
    });
  }

  Future<String?> _uploadGroupPhoto(String groupId) async {
    if (_photoBytes == null) return null;
    final ref = FirebaseStorage.instance
        .ref()
        .child('group_photos/${widget.userPhone}/$groupId.jpg');
    await ref.putData(
      _photoBytes!,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Nom de groupe requis', Colors.orange);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final groupDoc = FirebaseFirestore.instance.collection('groups').doc();
      final members = [widget.userPhone, ..._selectedMembers.toList()];
      await groupDoc.set({
        'name': name,
        'description': _descriptionController.text.trim(),
        'photoUrl': '',
        'createdBy': widget.userPhone,
        'owner': widget.userPhone,
        'members': members,
        'admins': [widget.userPhone],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageType': 'text',
      });

      final photoUrl = await _uploadGroupPhoto(groupDoc.id);
      if (photoUrl != null) {
        await groupDoc.update({'photoUrl': photoUrl});
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: groupDoc.id,
            userPhone: widget.userPhone,
          ),
        ),
      );
    } catch (e) {
      _showSnack('Impossible de créer le groupe', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: ListenableBuilder(
          listenable: globalProfileService,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: UserAvatarWidget(
              avatarUrl: globalProfileService.avatar,
              identifier: widget.userPhone,
              size: 36,
              borderColor: Colors.cyan,
              borderWidth: 1.5,
            ),
          ),
        ),
        title: const Text('Créer un groupe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _createGroup,
            tooltip: 'Créer',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GestureDetector(
                onTap: _isSaving ? null : _pickGroupPhoto,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kCard,
                    border: Border.all(color: kViolet.withOpacity(0.35)),
                  ),
                  child: _photoBytes != null
                      ? ClipOval(
                          child: Image.memory(
                            _photoBytes!,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.camera_alt, size: 28, color: kTextDim),
                              SizedBox(height: 8),
                              Text('Photo du groupe',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: kTextDim)),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: kText),
                decoration: const InputDecoration(
                  labelText: 'Nom du groupe',
                  hintText: 'Ex : Amis, Famille',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: kText),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optionnel',
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('contacts')
                      .where('owner', isEqualTo: widget.userPhone)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Erreur de chargement',
                            style: TextStyle(color: kPink)),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: kViolet),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Aucun contact disponible. Ajoute des contacts pour créer un groupe.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kTextDim),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sélectionner des membres',
                            style: TextStyle(
                                color: kText,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView(
                            children: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final contactPhone =
                                  data['contact'] as String? ?? '';
                              final contactName =
                                  data['name'] as String? ?? contactPhone;
                              final isSelected =
                                  _selectedMembers.contains(contactPhone);
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (checked) {
                                  if (checked == null) return;
                                  setState(() {
                                    if (checked) {
                                      _selectedMembers.add(contactPhone);
                                    } else {
                                      _selectedMembers.remove(contactPhone);
                                    }
                                  });
                                },
                                title: Text(contactName,
                                    style: const TextStyle(color: kText)),
                                subtitle: Text(contactPhone,
                                    style: const TextStyle(
                                        color: kTextDim, fontSize: 12)),
                                secondary: CircleAvatar(
                                  backgroundColor: kViolet.withOpacity(0.25),
                                  child: Text(
                                    contactName.isNotEmpty
                                        ? contactName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: kText),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _createGroup,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Créer le groupe'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
