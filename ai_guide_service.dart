import 'package:cloud_firestore/cloud_firestore.dart';

/// Service d'accès en lecture seule pour l'IA
/// Permet à l'IA de consulter les données de l'app pour guider les utilisateurs
/// LECTURE SEULE - Pas de permissions d'écriture
class AiGuideService {
  static final AiGuideService _instance = AiGuideService._internal();

  factory AiGuideService() => _instance;

  AiGuideService._internal();

  final _db = FirebaseFirestore.instance;

  /// Obtenir les statistiques générales de l'application
  Future<Map<String, dynamic>> getAppStatistics() async {
    try {
      final usersCount =
          await _db.collection('users').count().get().then((q) => q.count ?? 0);
      final postsCount =
          await _db.collection('posts').count().get().then((q) => q.count ?? 0);
      final groupsCount = await _db
          .collection('groups')
          .count()
          .get()
          .then((q) => q.count ?? 0);

      return {
        'totalUsers': usersCount,
        'totalPosts': postsCount,
        'totalGroups': groupsCount,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logAiGuideError('Erreur lors de la récupération des statistiques: $e');
      return {'error': 'Impossible de récupérer les statistiques'};
    }
  }

  /// Vérifier si un utilisateur existe et obtenir ses infos basiques
  Future<Map<String, dynamic>?> getUserInfo(String userPhone) async {
    try {
      final doc = await _db.collection('users').doc(userPhone).get();
      if (!doc.exists) return null;

      final data = doc.data() ?? {};
      return {
        'phone': userPhone,
        'name': data['name'] ?? 'Utilisateur',
        'hasAvatar': (data['avatar'] as String?)?.isNotEmpty ?? false,
        'createdAt':
            (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
      };
    } catch (e) {
      _logAiGuideError('Erreur lors de la récupération des infos utilisateur: $e');
      return null;
    }
  }

  /// Obtenir les fonctionnalités disponibles dans l'app
  Future<Map<String, dynamic>> getAppFeatures() async {
    return {
      'features': [
        {
          'name': 'Feed',
          'description':
              'Consulter les publications de la communauté, liker et commenter',
          'icon': 'forum',
        },
        {
          'name': 'Messages Privés',
          'description':
              'Communiquer en privé avec d\'autres utilisateurs, envoyer des fichiers',
          'icon': 'lock',
        },
        {
          'name': 'Business Hub',
          'description':
              'Gérer vos ventes, achats, dépenses et inventaire avec des rapports',
          'icon': 'bar_chart',
        },
        {
          'name': 'My Ultra AI',
          'description':
              'Assistant IA universel pour répondre à vos questions et vous guider',
          'icon': 'psychology',
        },
        {
          'name': 'Profil',
          'description':
              'Gérer votre profil, vos paramètres et vos statistiques personnelles',
          'icon': 'person',
        },
      ],
      'totalFeatures': 5,
    };
  }

  /// Obtenir l'historique des publications récentes (pour contextualiser)
  Future<List<Map<String, dynamic>>> getRecentPosts({int limit = 5}) async {
    try {
      final snapshot = await _db
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'author': data['owner'] ?? 'Anonyme',
          'caption': (data['caption'] as String?)?.substring(0, 100) ?? '',
          'type': data['type'] ?? 'post',
          'createdAt':
              (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
          'likes': (data['likes'] as List?)?.length ?? 0,
        };
      }).toList();
    } catch (e) {
      _logAiGuideError('Erreur lors de la récupération des posts: $e');
      return [];
    }
  }

  /// Obtenir les groupes disponibles
  Future<List<Map<String, dynamic>>> getAvailableGroups(
      {int limit = 10}) async {
    try {
      final snapshot = await _db.collection('groups').limit(limit).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Groupe',
          'description': data['description'] ?? '',
          'membersCount': (data['members'] as List?)?.length ?? 0,
          'createdAt':
              (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
        };
      }).toList();
    } catch (e) {
      _logAiGuideError('Erreur lors de la récupération des groupes: $e');
      return [];
    }
  }

  /// Obtenir les utilisateurs actifs récemment
  Future<List<Map<String, dynamic>>> getRecentlyActiveUsers(
      {int limit = 10}) async {
    try {
      final snapshot = await _db.collection('users').limit(limit).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'phone': doc.id,
          'name': data['name'] ?? 'Utilisateur',
          'online': data['online'] ?? false,
        };
      }).toList();
    } catch (e) {
      _logAiGuideError('Erreur lors de la récupération des utilisateurs: $e');
      return [];
    }
  }
  /// Obtenir les informations sur une fonctionnalité spécifique
  Future<Map<String, dynamic>> getFeatureGuide(String featureName) async {
    final guides = {
      'feed': {
        'title': 'Guide - Feed',
        'description': 'Explorez les publications de la communauté',
        'steps': [
          'Accédez à l\'onglet Feed depuis la barre de navigation',
          'Consultez les publications les plus récentes',
          'Likez ou commentez les publications qui vous intéressent',
          'Utilisez la recherche pour trouver des publications spécifiques',
          'Publiez votre propre contenu avec les boutons +',
        ],
      },
      'messages': {
        'title': 'Guide - Messages Privés',
        'description': 'Communiquez avec d\'autres utilisateurs',
        'steps': [
          'Ouvrez l\'onglet Messages Privés',
          'Sélectionnez un contact ou créez une nouvelle conversation',
          'Envoyez des messages texte, photos, vidéos ou fichiers',
          'Utilisez les emojis pour exprimer vos émotions',
          'Archivez les conversations que vous ne voulez pas voir',
        ],
      },
      'business': {
        'title': 'Guide - Business Hub',
        'description': 'Gérez votre activité commerciale',
        'steps': [
          'Accédez à l\'onglet Business',
          'Enregistrez vos ventes, achats et dépenses',
          'Consultez vos statistiques et graphiques',
          'Exportez vos données en CSV',
          'Analysez vos tendances commerciales',
        ],
      },
      'ai': {
        'title': 'Guide - My Ultra AI',
        'description': 'Utilisez l\'assistant IA pour vous guider',
        'steps': [
          'Ouvrez l\'onglet My Ultra AI',
          'Posez vos questions dans le champ de saisie',
          'Recevez des réponses immédiates de l\'IA',
          'Posez des questions de suivi pour plus de détails',
          'L\'historique est sauvegardé pour vos futures consultations',
        ],
      },
      'profile': {
        'title': 'Guide - Profil',
        'description': 'Gérez votre profil personnel',
        'steps': [
          'Accédez à l\'onglet Profil',
          'Modifiez votre nom et votre photo de profil',
          'Consultez vos statistiques de publication',
          'Gérez vos paramètres et préférences',
          'Suivez d\'autres utilisateurs ou consultez vos followers',
        ],
      },
    };

    return guides[featureName.toLowerCase()] ??
        {
          'error': 'Guide non trouvé pour cette fonctionnalité',
          'availableGuides': guides.keys.toList(),
        };
  }

  /// Obtenir les informations pour les nouveaux utilisateurs
  Future<Map<String, dynamic>> getNewUserOnboarding() async {
    final stats = await getAppStatistics();
    final features = await getAppFeatures();

    return {
      'welcome': 'Bienvenue dans My Chat Ultra!',
      'creator': 'Créé par Genereux Mr & son Équipe',
      'statistics': stats,
      'features': features,
      'gettingStarted': [
        'Complétez votre profil avec votre photo et vos informations',
        'Explorez le Feed pour découvrir la communauté',
        'Connectez-vous avec d\'autres utilisateurs',
        'Utilisez Business Hub pour gérer vos activités',
        'Posez des questions à My Ultra AI pour obtenir de l\'aide',
      ],
    };
  }

  /// Obtenir les vidéos avec le plus de vues
  Future<List<Map<String, dynamic>>> getTopVideosByViews(
      {int limit = 5}) async {
    try {
      final snapshot = await _db
          .collection('posts')
          .where('type', isEqualTo: 'video')
          .orderBy('views', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['caption'] ?? 'Vidéo sans titre',
          'author': data['owner'] ?? 'Anonyme',
          'views': data['views'] ?? 0,
          'likes': (data['likes'] as List?)?.length ?? 0,
          'comments': (data['comments'] as List?)?.length ?? 0,
          'duration': data['duration'] ?? 'Non spécifiée',
          'createdAt':
              (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
          'url': data['videoUrl'] ?? '',
        };
      }).toList();
    } catch (e) {
      _logAiGuideError('Erreur lors de la récupération des vidéos: $e');
      return [];
    }
  }

  /// Obtenir les conseils pour les nouveaux utilisateurs
  Future<String> getNewUserTip() async {
    final tips = [
      'Mettez à jour votre photo de profil pour que les autres vous reconnaissent facilement!',
      'Utilisez le Business Hub pour suivre vos ventes et dépenses en temps réel.',
      'Essayez de publier du contenu intéressant pour engager la communauté.',
      'Les messages privés supportent les fichiers - vous pouvez partager des documents!',
      'Posez des questions à My Ultra AI - elle connaît toutes les fonctionnalités de l\'app!',
      'Rejoignez des groupes pour discuter avec d\'autres utilisateurs partageant vos intérêts.',
      'Utilisez la recherche dans le Feed pour trouver des publications spécifiques.',
      'Consultez vos statistiques de profil pour voir votre activité globale.',
    ];

    tips.shuffle();
    return tips.first;
  }

  /// Préparer un contexte pour l'analyse d'un message par l'IA
  /// Utilisé quand l'utilisateur transfère manuellement un message à l'IA
  Map<String, dynamic> prepareMessageAnalysisContext(
      String message, String sender, String recipientName) {
    return {
      'message': message,
      'sender': sender,
      'recipient': recipientName,
      'timestamp': DateTime.now().toIso8601String(),
      'requestType': 'message_analysis',
    };
  }
}

// Helper pour debug
void _logAiGuideError(String message) {
  print('[AI Guide Service] $message');
}
