import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const _localizedValues = {
    'fr': {
      'appTitle': 'MY CHAT ULTRA',
      'profile': 'Profil',
      'profileSubtitle': 'Paramètres personnels et identité',
      'language': 'Langue',
      'chooseLanguage': 'Choisir la langue de l\'app',
      'languageCurrent': 'Langue actuelle',
      'languageSetOn': 'Langue définie sur',
      'changingLanguage': 'Changement de langue...',
      'chooseTheme': 'Thème du compte',
      'accountTheme': 'Thème du compte',
      'editName': 'Modifier le nom',
      'editNameHint': 'Mettre à jour votre identité affichée',
      'security': 'Sécurité',
      'securityHint': 'Paramètres protégés et synchronisés',
      'myPosts': 'Mes publications',
      'deletePostsHint':
          'Supprime tes posts publiés, sans maquette ni simulation.',
      'informationSection': 'Informations',
      'informationSubtitle': 'Vos données principales',
      'quickActions': 'Actions rapides',
      'quickActionsSubtitle': 'Gestion simple du compte',
      'profileLocal': 'Profil local',
      'themeSaved': 'Thème sauvegardé',
      'active': 'Actif',
      'apply': 'Appliquer',
      'cancel': 'Annuler',
      'validate': 'Valider',
      'deleteContactTitle': 'Supprimer le contact',
      'deleteContactConfirmation':
          'Supprimer {name} ({phone}) de vos contacts ?\nLes messages ne seront pas supprimés.',
      'deleteContactCancel': 'Annuler',
      'deleteContactConfirm': 'Supprimer',
      'newContact': 'Nouveau contact',
      'photo': 'Photo',
      'phoneNumberHint': 'Numéro de téléphone *',
      'nameHint': 'Nom *',
      'emailOptional': 'Email (facultatif)',
      'requiredFields': '* Champs obligatoires',
      'phoneNameRequired': '⚠️ Numéro et nom sont obligatoires',
      'addContact': 'Ajouter',
      'privateSettings': 'Paramètres privés',
      'privateSettingsTooltip': 'Paramètres privés',
      'saveNumberTooltip': 'Enregistrer ce numéro',
      'ghostModeOn': '👻 Mode fantôme activé',
      'ghostModeOff': '👁️ Mode fantôme désactivé',
      'privateMessagingTitle': 'Messagerie privée',
      'privateMessagingSubtitle':
          'Retrouve tes conversations et ajoute un numéro en un geste.',
      'offline': 'Hors ligne',
      'online': 'En ligne',
      'minutesAgo': 'Il y a {minutes}min',
      'hoursAgo': 'Il y a {hours}h',
      'voiceRecordingInProgress': 'Message vocal en cours',
      'voiceUploadInProgress': 'Envoi du message vocal...',
      'voiceUploadFinalizing': 'Finalisation du message vocal...',
      'inCall': 'En communication',
      'callOngoing': 'Appel en cours...',
      'video': 'Vidéo',
      'file': 'Fichier',
      'you': 'Vous',
      'createGroup': 'Créer un groupe',
      'createGroupSubtitle': 'Créer une conversation de groupe privée',
      'fontSizeLabel': 'Taille de police : {size}',
      'groupNameHint': 'Nom du groupe',
      'nameRequired': 'Nom requis',
      'groupCreated': 'Groupe créé',
      'searchContactHint': 'Rechercher un contact ou un numéro',
      'clear': 'Effacer',
      'recentConversations': 'Conversations récentes',
      'contacts': 'Contacts',
      'unknown': 'Inconnu',
      'emptyConversation': 'Conversation vide',
      'noConversation': 'Aucune conversation',
      'noResults': 'Aucun résultat',
      'addContactPrompt': 'Appuie sur + pour ajouter un contact',
      'tryAnotherNameOrNumber': 'Essaie un autre nom ou numéro',
      'voiceMessage': 'Message vocal',
      'playing': 'En lecture...',
      'tapToListen': 'Appuyer pour écouter',
      'forwarded': 'Transféré',
      'messageDeleted': '🚫 Message supprimé',
      'edited': ' • modifié',
      'error': 'Erreur',
      'startConversation': 'Début de la conversation...',
      'callsUnavailableWeb': 'Appels non disponibles sur web',
      'agoraNotConfigured':
          'Agora non configuré. Vérifiez AGORA_APP_ID et AGORA_TEMP_TOKEN.',
      'microphoneDeniedPermanently':
          'Microphone désactivé définitivement — activez-le dans les paramètres',
      'microphoneUnauthorized': 'Microphone non autorisé par le plugin record',
      'permissionMicroDenied': 'Permission microphone refusée',
      'seenAt': 'Vu à {time}',
      'recordingError': 'Erreur pendant l\'enregistrement: {error}',
      'recordingStartError':
          'Impossible de démarrer l\'enregistrement: {error}',
      'voiceUploadError': 'Erreur envoi message vocal',
      'fileUploadError': 'Erreur envoi fichier',
      'sendError': 'Erreur envoi',
      'copied': 'Copié !',
      'transferred': 'Transféré !',
      'forwardTo': 'Transférer à',
      'editingInProgress': 'Modification en cours',
      'editMessageHint': 'Modifier le message...',
      'privateMessageHint': 'Message privé...',
      'camera': 'Caméra',
      'delete': 'Supprimer',
      'reply': 'Répondre',
      'forward': 'Transférer',
      'pin': 'Épingler',
      'copy': 'Copier',
      'edit': 'Modifier',
      'ephemeralMessage': 'Message éphémère (30s)',
      'deleteContactSuccess': '{name} supprimé',
      'invalidNumber': 'Numéro invalide',
      'cannotAddYourself': 'Vous ne pouvez pas vous ajouter vous-même',
      'alreadyInContacts': '{phone} est déjà dans vos contacts',
      'addedSuccessfully': '{name} ajouté avec succès !',
      'contactDeleted': '{name} supprimé',
    },
    'en': {
      'appTitle': 'MY CHAT ULTRA',
      'profile': 'Profile',
      'profileSubtitle': 'Personal settings and identity',
      'language': 'Language',
      'chooseLanguage': 'Choose the app language',
      'languageCurrent': 'Current language',
      'languageSetOn': 'Language set to',
      'changingLanguage': 'Changing language...',
      'chooseTheme': 'Account theme',
      'accountTheme': 'Account theme',
      'editName': 'Edit name',
      'editNameHint': 'Update your display name',
      'security': 'Security',
      'securityHint': 'Protected and synced settings',
      'myPosts': 'My posts',
      'deletePostsHint': 'Delete your published posts, no mocks or simulation.',
      'informationSection': 'Information',
      'informationSubtitle': 'Your main data',
      'quickActions': 'Quick actions',
      'quickActionsSubtitle': 'Simple account management',
      'profileLocal': 'Local profile',
      'themeSaved': 'Saved theme',
      'active': 'Active',
      'apply': 'Apply',
      'cancel': 'Cancel',
      'validate': 'Confirm',
      'deleteContactTitle': 'Delete contact',
      'deleteContactConfirmation':
          'Delete {name} ({phone}) from your contacts? Messages will not be removed.',
      'deleteContactCancel': 'Cancel',
      'deleteContactConfirm': 'Delete',
      'newContact': 'New contact',
      'photo': 'Photo',
      'phoneNumberHint': 'Phone number *',
      'nameHint': 'Name *',
      'emailOptional': 'Email (optional)',
      'requiredFields': '* Required fields',
      'phoneNameRequired': '⚠️ Phone and name are required',
      'addContact': 'Add',
      'privateSettings': 'Private settings',
      'privateSettingsTooltip': 'Private settings',
      'saveNumberTooltip': 'Save this number',
      'ghostModeOn': '👻 Ghost mode enabled',
      'ghostModeOff': '👁️ Ghost mode disabled',
      'privateMessagingTitle': 'Private messaging',
      'privateMessagingSubtitle':
          'Find your conversations and add a number in one gesture.',
      'offline': 'Offline',
      'online': 'Online',
      'minutesAgo': '{minutes}m ago',
      'hoursAgo': '{hours}h ago',
      'voiceRecordingInProgress': 'Voice message in progress',
      'voiceUploadInProgress': 'Sending voice message...',
      'voiceUploadFinalizing': 'Finalizing voice message...',
      'inCall': 'In call',
      'callOngoing': 'Call ongoing...',
      'video': 'Video',
      'file': 'File',
      'you': 'You',
      'createGroup': 'Create group',
      'createGroupSubtitle': 'Create a private group chat',
      'fontSizeLabel': 'Font size: {size}',
      'groupNameHint': 'Group name',
      'nameRequired': 'Name required',
      'groupCreated': 'Group created',
      'searchContactHint': 'Search contact or number',
      'clear': 'Clear',
      'recentConversations': 'Recent conversations',
      'contacts': 'Contacts',
      'unknown': 'Unknown',
      'emptyConversation': 'Empty conversation',
      'noConversation': 'No conversations',
      'noResults': 'No results',
      'addContactPrompt': 'Tap + to add a contact',
      'tryAnotherNameOrNumber': 'Try another name or number',
      'voiceMessage': 'Voice message',
      'playing': 'Playing...',
      'tapToListen': 'Tap to listen',
      'forwarded': 'Forwarded',
      'messageDeleted': '🚫 Message deleted',
      'edited': ' • edited',
      'error': 'Error',
      'startConversation': 'Start the conversation...',
      'callsUnavailableWeb': 'Calls are not available on web',
      'agoraNotConfigured':
          'Agora is not configured. Check AGORA_APP_ID and AGORA_TEMP_TOKEN.',
      'microphoneDeniedPermanently':
          'Microphone permanently denied — enable it in settings',
      'permissionMicroDenied': 'Microphone permission denied',
      'microphoneUnauthorized':
          'Microphone not authorized by the record plugin',
      'seenAt': 'Seen at {time}',
      'recordingError': 'Recording error: {error}',
      'recordingStartError': 'Could not start recording: {error}',
      'voiceUploadError': 'Voice message upload error',
      'fileUploadError': 'File upload error',
      'sendError': 'Send error',
      'copied': 'Copied!',
      'transferred': 'Transferred!',
      'forwardTo': 'Forward to',
      'editingInProgress': 'Editing in progress',
      'editMessageHint': 'Edit message...',
      'privateMessageHint': 'Private message...',
      'camera': 'Camera',
      'delete': 'Delete',
      'reply': 'Reply',
      'forward': 'Forward',
      'pin': 'Pin',
      'copy': 'Copy',
      'edit': 'Edit',
      'ephemeralMessage': 'Ephemeral message (30s)',
      'deleteContactSuccess': '{name} deleted',
      'invalidNumber': 'Invalid number',
      'cannotAddYourself': 'You cannot add yourself',
      'alreadyInContacts': '{phone} is already in your contacts',
      'addedSuccessfully': '{name} added successfully!',
      'contactDeleted': '{name} deleted',
    },
  };

  String translate(String key, [Map<String, String>? params]) {
    var raw = _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['fr']?[key] ??
        key;
    if (params != null && params.isNotEmpty) {
      for (final entry in params.entries) {
        raw = raw.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return raw;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['fr', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
