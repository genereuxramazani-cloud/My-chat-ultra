import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart' show globalProfileService;
import '../theme.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String userPhone;

  const GroupChatScreen(
      {super.key, required this.groupId, required this.userPhone});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final currentUserName = globalProfileService.name ?? widget.userPhone;
    final currentUserPhoto = globalProfileService.avatar ?? '';

    try {
      final messageRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'senderPhone': widget.userPhone,
        'senderName': currentUserName,
        'senderPhoto': currentUserPhoto,
        'text': text,
        'mediaUrl': '',
        'mediaType': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [widget.userPhone],
      });

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'lastMessage': text,
        'lastMessageType': 'text',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'envoyer le message')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Widget _buildMessageTile(Map<String, dynamic> data, bool isMine) {
    final text = data['text'] as String? ?? '';
    final senderName = data['senderName'] as String? ??
        data['senderPhone'] as String? ??
        'Utilisateur';
    final senderPhoto = data['senderPhoto'] as String? ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final time = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
        : null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMine ? kCyan.withOpacity(0.9) : kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isMine ? kCyan : kSurface),
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(senderName,
                      style: const TextStyle(
                          color: kText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              Text(text, style: const TextStyle(color: kText, fontSize: 15)),
              if (time != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: kTextDim, fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .snapshots(),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Impossible de charger le groupe',
                  style: TextStyle(color: kPink)),
            ),
          );
        }

        if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: kViolet),
            ),
          );
        }

        final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
        final groupName = groupData['name'] as String? ?? 'Groupe';
        final groupPhoto = groupData['photoUrl'] as String? ?? '';
        final members = List<String>.from(groupData['members'] ?? const []);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                if (groupPhoto.isNotEmpty)
                  CircleAvatar(
                    backgroundImage: NetworkImage(groupPhoto),
                    radius: 18,
                  )
                else
                  CircleAvatar(
                    backgroundColor: kViolet.withOpacity(0.35),
                    child: Text(
                      groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G',
                      style: const TextStyle(color: kText),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(groupName,
                          style: const TextStyle(
                              color: kText, fontWeight: FontWeight.bold)),
                      Text('${members.length} membres',
                          style:
                              const TextStyle(color: kTextDim, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, messagesSnapshot) {
                    if (messagesSnapshot.hasError) {
                      return const Center(
                          child: Text('Erreur de messages',
                              style: TextStyle(color: kPink)));
                    }
                    if (!messagesSnapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(color: kViolet));
                    }
                    final docs = messagesSnapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Aucun message pour le moment.',
                            style: TextStyle(color: kTextDim)),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final isMine = data['senderPhone'] == widget.userPhone;
                        return _buildMessageTile(data, isMine);
                      },
                    );
                  },
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: kSurface,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: kText),
                        decoration: const InputDecoration(
                          hintText: 'Écrire un message...',
                          hintStyle: TextStyle(color: kTextDim),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: kCyan,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send, color: kCyan),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
