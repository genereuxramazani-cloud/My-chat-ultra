import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../cloudinary_service.dart';
import '../services/ai_guide_service.dart';
import '../theme.dart';

class NeuralScreen extends StatefulWidget {
  final String userPhone;
  final VoidCallback? onNavigateToFeed;
  const NeuralScreen(
      {super.key, required this.userPhone, this.onNavigateToFeed});
  @override
  State<NeuralScreen> createState() => _NeuralScreenState();
}

class _NeuralScreenState extends State<NeuralScreen> {
  final _msgC = TextEditingController();
  final _scrollController = ScrollController();

  // Historique complet pour que l'IA ait une mémoire de la conversation
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  bool _historyLoaded = false;

  final AiGuideService _guideService = AiGuideService();
  String _appGuideContext = '';

  // ⚠️ Remplace par ta clé Groq (gsk_...)
  static const _apiKey =
      "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";
  static const _url = "https://api.groq.com/openai/v1/chat/completions";
  static const _model = "llama-3.3-70b-versatile";
  static const _visionModel = "meta-llama/llama-4-scout-17b-16e-instruct";

  static const _systemPrompt =
      "Tu es 'My Ultra Ai', l'intelligence artificielle officielle et intégrée "
      "de l'application My Chat Ultra. Ton rôle est d'être un assistant universel : "
      "tu dois répondre à TOUTES les questions de l'utilisateur, qu'elles soient "
      "techniques, créatives, personnelles, éducatives, de business ou pratiques. "
      "Sois performant, amical, précis et adopte un ton moderne adapté à une "
      "application de messagerie de pointe. Utilise parfois des emojis pour rendre "
      "le chat vivant.";

  CollectionReference<Map<String, dynamic>> get _historyCollection =>
      FirebaseFirestore.instance
          .collection('ai_conversations')
          .doc(widget.userPhone)
          .collection('messages');

  Future<void> _loadConversationHistory() async {
    try {
      final snapshot = await _historyCollection
          .orderBy('createdAt', descending: false)
          .get();

      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'role': data['role'] as String? ?? 'assistant',
              'text': data['text'] as String? ?? '',
              if (data['type'] is String) 'type': data['type'] as String,
              if (data['imageUrl'] is String)
                'imageUrl': data['imageUrl'] as String,
              if (data['description'] is String)
                'description': data['description'] as String,
              if (data['imagePrompt'] is String)
                'imagePrompt': data['imagePrompt'] as String,
            };
          }));
        _historyLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historyLoaded = true;
      });
    }
  }

  Future<void> _persistMessage(Map<String, String> message) async {
    await _historyCollection.add({
      'role': message['role'] ?? 'assistant',
      'text': message['text'] ?? '',
      'type': message['type'],
      'imageUrl': message['imageUrl'],
      'description': message['description'],
      'imagePrompt': message['imagePrompt'],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _loadAiGuideContext() async {
    try {
      final appFeatures = await _guideService.getAppFeatures();
      final aiGuide = await _guideService.getFeatureGuide('ai');
      final onboarding = await _guideService.getNewUserOnboarding();

      final featureLines = (appFeatures['features'] as List<dynamic>?)
              ?.map((item) => '- ${item['name']}: ${item['description']}')
              .join('\n') ??
          '';
      final onboardingSteps = (onboarding['gettingStarted'] as List<dynamic>?)
              ?.map((item) => '- $item')
              .join('\n') ??
          '';

      if (!mounted) return;
      setState(() {
        _appGuideContext =
            'Contexte de l\'application:\n'
            '$featureLines\n\n'
            'Guide My Ultra AI:\n'
            '${aiGuide['description'] ?? ''}\n\n'
            'Étapes de démarrage:\n'
            '$onboardingSteps';
      });
    } catch (_) {
      // Ne bloque pas l'utilisation de l'IA si le guide échoue.
    }
  }

  String _formatMessageContent(Map<String, String> msg) {
    if (msg['type'] == 'image') {
      final imageUrl = msg['imageUrl'] ?? '';
      final description = msg['description'];
      final imagePrompt = msg['imagePrompt'];
      final caption = msg['text']?.isNotEmpty == true ? '\n${msg['text']}' : '';
      final descText = description?.isNotEmpty == true
          ? 'Description de l\'image: $description\n'
          : '';
      final promptText =
          imagePrompt?.isNotEmpty == true ? 'Prompt image: $imagePrompt\n' : '';
      return 'Voici une image : $imageUrl\n$descText$promptText$caption';
    }
    return msg['text'] ?? '';
  }

  Future<void> _sendRequest() async {
    setState(() {
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final List<Map<String, String>> groqMessages = [
        {"role": "system", "content": _systemPrompt},
        if (_appGuideContext.isNotEmpty)
          {"role": "system", "content": _appGuideContext},
        ..._messages.take(40).map((m) {
          final role = m['role'] == 'user' ? 'user' : 'assistant';
          return {
            "role": role,
            "content": _formatMessageContent(m),
          };
        }),
      ];

      final response = await http.post(
        Uri.parse(_url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
        },
        body: jsonEncode({
          "model": _model,
          "messages": groqMessages,
          "max_tokens": 1024,
          "temperature": 0.7,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final replyText =
            data["choices"]?[0]?["message"]?["content"] ?? "Réponse vide";
        if (!mounted) return;
        setState(() {
          _messages.add({'role': 'assistant', 'text': replyText});
        });
        await _persistMessage({'role': 'assistant', 'text': replyText});
      } else {
        final errorMsg = data["error"]?["message"] ?? response.body;
        if (!mounted) return;
        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': 'Erreur ${response.statusCode}: $errorMsg'
          });
        });
        await _persistMessage({
          'role': 'assistant',
          'text': 'Erreur ${response.statusCode}: $errorMsg'
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': 'Erreur de connexion: ${e.toString()}'
        });
      });
      await _persistMessage({
        'role': 'assistant',
        'text': 'Erreur de connexion: ${e.toString()}'
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgC.text.trim();
    if (text.isEmpty || _isLoading || _isUploading) return;

    final userMessage = {'role': 'user', 'text': text};

    setState(() {
      _messages.add(userMessage);
      _msgC.clear();
    });

    await _persistMessage(userMessage);

    await _sendRequest();
  }

  Future<void> _sendImage({bool fromCamera = false}) async {
    if (_isLoading || _isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    final result = fromCamera
        ? await CloudinaryService.captureAndUploadImage(
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _uploadProgress = progress;
              });
            },
          )
        : await CloudinaryService.pickAndUploadImage(
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _uploadProgress = progress;
              });
            },
          );

    if (!mounted) return;
    if (result == null || result['url'] == null) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger l\'image.')),
      );
      return;
    }

    final imageUrl = result['url'] ?? '';
    final description = result['description'] ?? '';
    final imagePrompt = result['imagePrompt'] ?? '';

    setState(() {
      _messages.add({
        'role': 'user',
        'type': 'image',
        'text': 'Photo envoyée à l\'IA',
        'imageUrl': imageUrl,
        'description': description,
        'imagePrompt': imagePrompt,
      });
      _messages.add({
        'role': 'assistant',
        'text': [
          if (description.isNotEmpty) 'Analyse: $description',
          if (imagePrompt.isNotEmpty) 'Prompt d\'image: $imagePrompt',
        ].join('\n\n'),
      });
    });

    await _persistMessage({
      'role': 'user',
      'type': 'image',
      'text': 'Photo envoyée à l\'IA',
      'imageUrl': imageUrl,
      'description': description,
      'imagePrompt': imagePrompt,
    });

    await _persistMessage({
      'role': 'assistant',
      'text': [
        if (description.isNotEmpty) 'Analyse: $description',
        if (imagePrompt.isNotEmpty) 'Prompt d\'image: $imagePrompt',
      ].join('\n\n'),
    });

    _scrollToBottom();

    if (!mounted) return;
    setState(() {
      _isUploading = false;
      _uploadProgress = 0;
    });
  }

  Future<void> _generateImagePrompt() async {
    if (_isLoading || _isUploading) return;

    final ideaController = TextEditingController();
    final idea = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Créer un prompt d\'image'),
        content: TextField(
          controller: ideaController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Décris l\'image que tu veux générer...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, ideaController.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    ideaController.dispose();

    if (idea == null || idea.isEmpty) return;

    final userMessage = {
      'role': 'user',
      'text': 'Crée un prompt d\'image détaillé pour: $idea',
    };

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    await _persistMessage(userMessage);

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Tu génères uniquement des prompts d\'image en français. Réponds avec un prompt court, concret, visuel et prêt à être utilisé dans un générateur d\'images. Pas d\'explication.'
            },
            {'role': 'user', 'content': idea},
          ],
          'max_tokens': 512,
          'temperature': 0.8,
        }),
      );

      final data = jsonDecode(response.body);
      final String promptText = response.statusCode == 200
          ? ((data['choices']?[0]?['message']?['content'] ?? 'Prompt vide')
              .toString())
          : 'Erreur ${response.statusCode}: ${data['error']?['message'] ?? response.body}';

      final assistantMessage = {
        'role': 'assistant',
        'type': 'image_prompt',
        'text': promptText,
      };

      if (!mounted) return;
      setState(() {
        _messages.add(assistantMessage);
      });

      await _persistMessage(assistantMessage);
      await Clipboard.setData(ClipboardData(text: promptText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prompt d\'image copié')),
        );
      }
    } catch (e) {
      final assistantMessage = {
        'role': 'assistant',
        'type': 'image_prompt',
        'text': 'Erreur de connexion: ${e.toString()}',
      };

      if (!mounted) return;
      setState(() {
        _messages.add(assistantMessage);
      });

      await _persistMessage(assistantMessage);
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _msgC.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadConversationHistory());
    unawaited(_loadAiGuideContext());
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kViolet),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
              return;
            }
            if (widget.onNavigateToFeed != null) {
              widget.onNavigateToFeed!();
              return;
            }
            Navigator.maybePop(context);
          },
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF050510), Color(0xFF0D0D2B)],
            ),
          ),
        ),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology, color: kViolet, size: 18),
            SizedBox(width: 8),
            Text("MY ULTRA AI",
                style: TextStyle(color: kViolet, letterSpacing: 2)),
          ],
        ),
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: kGradientBg),
          child: Column(
            children: [
              // Header card
              Padding(
                padding: const EdgeInsets.all(12),
                child: GlassCard(
                  borderColor: kViolet,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kViolet.withOpacity(0.15),
                          border: Border.all(color: kViolet, width: 1.5),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: kViolet, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("My Ultra Ai",
                              style: TextStyle(
                                  color: kViolet, fontWeight: FontWeight.bold)),
                          Text("Prête à vous répondre",
                              style: TextStyle(color: kTextDim, fontSize: 11)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.greenAccent,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.5),
                                blurRadius: 8)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Messages
              Expanded(
                child: !_historyLoaded
                    ? const Center(
                        child: CircularProgressIndicator(color: kViolet),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.psychology_outlined,
                                    size: 60, color: kViolet.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                const Text("Pose-moi une question...",
                                    style: TextStyle(color: kTextDim)),
                                const SizedBox(height: 8),
                                const Text(
                                    "Business, chat, calculs, autres — je suis là",
                                    style: TextStyle(
                                        color: kTextDim, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _messages.length,
                            itemBuilder: (c, i) {
                              final msg = _messages[i];
                              final isMe = msg['role'] == 'user';
                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.8),
                                  decoration: BoxDecoration(
                                    gradient: isMe
                                        ? LinearGradient(colors: [
                                            kViolet.withOpacity(0.2),
                                            kPink.withOpacity(0.15)
                                          ])
                                        : LinearGradient(
                                            colors: [kCard, kSurface]),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft:
                                          Radius.circular(isMe ? 18 : 4),
                                      bottomRight:
                                          Radius.circular(isMe ? 4 : 18),
                                    ),
                                    border: Border.all(
                                      color: isMe
                                          ? kViolet.withOpacity(0.4)
                                          : kCyan.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        const Padding(
                                          padding: EdgeInsets.only(bottom: 6),
                                          child: Text("MY ULTRA AI",
                                              style: TextStyle(
                                                  color: kViolet,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1)),
                                        ),
                                      Text(msg['text'] ?? '',
                                          style: const TextStyle(color: kText)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              // Indicateur de chargement
              if (_isUploading || _isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GlassCard(
                      borderColor: kViolet,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isUploading)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: kViolet, strokeWidth: 2),
                            )
                          else
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: kViolet, strokeWidth: 2),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                _isUploading
                                    ? 'Téléchargement de l\'image ${(_uploadProgress * 100).toStringAsFixed(0)}%'
                                    : 'Analyse en cours...',
                                style: const TextStyle(
                                    color: kViolet, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Champ de saisie
              Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kSurface,
                    border: Border(
                        top: BorderSide(
                            color: kViolet.withOpacity(0.2), width: 1)),
                  ),
                  child: Row(
                    children: [
                      PopupMenuButton<String>(
                        tooltip: 'Image',
                        color: kCard,
                        onSelected: (value) async {
                          if (_isLoading || _isUploading) return;
                          if (value == 'gallery') {
                            await _sendImage();
                          } else if (value == 'camera') {
                            await _sendImage(fromCamera: true);
                          } else if (value == 'prompt') {
                            await _generateImagePrompt();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'gallery',
                            child: Text('Analyser une image'),
                          ),
                          PopupMenuItem(
                            value: 'camera',
                            child: Text('Analyser une photo'),
                          ),
                          PopupMenuItem(
                            value: 'prompt',
                            child: Text('Créer un prompt image'),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: kViolet.withOpacity(0.2), width: 1),
                            color: kSurface,
                          ),
                          child: const Icon(Icons.photo_camera,
                              color: kViolet, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _msgC,
                          style: const TextStyle(color: kText),
                          maxLines: null,
                          onSubmitted: (_) => _isLoading || _isUploading
                              ? null
                              : _sendMessage(),
                          decoration: const InputDecoration(
                            hintText: "Demande à l'IA...",
                            hintStyle: TextStyle(color: kTextDim),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _isLoading || _isUploading ? null : _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [kViolet, kPink]),
                            boxShadow: [
                              BoxShadow(
                                  color: kViolet.withOpacity(0.3),
                                  blurRadius: 15)
                            ],
                          ),
                          child: const Icon(Icons.send,
                              color: Colors.white, size: 20),
                        ),
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
  }
}
