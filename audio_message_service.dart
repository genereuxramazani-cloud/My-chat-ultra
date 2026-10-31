import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../cloudinary_service.dart';
import 'package:uuid/uuid.dart';
import 'audio_message_file_stub.dart'
    if (dart.library.io) 'audio_message_file_io.dart' as audio_file;

class AudioMessageService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _recordingPath;
  Uint8List? _recordingData; // Stocker les données en mémoire pour le web

  /// Démarrer l'enregistrement audio en Opus
  Future<bool> startRecording() async {
    try {
      // Vérifier la permission microphone
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        return false;
      }

      // Configuration Opus : supportée nativement par le package 'record'
      const config = RecordConfig(
        encoder: AudioEncoder.opus,
        sampleRate: 48000,
        bitRate: 64000, // Qualité excellente pour la voix
      );

      // Sur mobile: créer un chemin temporaire
      // Sur web: le recorder gère cela automatiquement en mémoire
      if (!kIsWeb) {
        final tempDir = Directory.systemTemp;
        _recordingPath = '${tempDir.path}/${const Uuid().v4()}.opus';
      }

      await _recorder.start(config, path: _recordingPath ?? '');
      _recordingData = null; // Réinitialiser les données
      return true;
    } catch (e) {
      print('Erreur startRecording: $e');
      return false;
    }
  }

  /// Arrêter l'enregistrement et récupérer le chemin/données
  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (path != null) {
        _recordingPath = path;
      }
      return path;
    } catch (e) {
      print('Erreur stopRecording: $e');
      return null;
    }
  }

  /// Upload l'audio vers Firebase Storage
  /// Upload direct vers Firebase Storage sur toutes les plateformes.
  /// Retourne l'URL de téléchargement ou null en cas d'erreur
  Future<String?> uploadAudio(String recordingPath, String senderPhone) async {
    try {
      if (recordingPath.isEmpty) {
        print('Recording path vide');
        return null;
      }

      return await _uploadAudioDirect(recordingPath, senderPhone);
    } catch (e) {
      print('Erreur uploadAudio: $e');
      return null;
    }
  }

  /// Upload direct sur Firebase Storage (Mobile)
  Future<String?> _uploadAudioDirect(
      String recordingPath, String senderPhone) async {
    try {
      final fileName = '${const Uuid().v4()}.opus';

      Uint8List data;
      if (kIsWeb) {
        data = await _getBlobDataAsBytes(recordingPath);
      } else {
        data = await audio_file.readFileBytes(recordingPath);
      }

      if (data.isEmpty) {
        print('Erreur: données audio vides');
        return null;
      }

      // Upload via Cloudinary
      final uploadedUrl = await CloudinaryService.uploadBytes(
        data,
        fileName,
        onProgress: (p) => null,
      );

      if (kIsWeb) {
        await _cleanupWebBlob(recordingPath);
      }

      return uploadedUrl;
    } catch (e) {
      print('Erreur _uploadAudioDirect: $e');
      return null;
    }
  }

  /// Récupérer les bytes d'un blob URL via JavaScript avec callback
  Future<Uint8List> _getBlobDataAsBytes(String blobUrl) async {
    return Uint8List(0);
  }

  Future<void> _cleanupWebBlob(String blobUrl) async {}

  /// Lire un message audio
  Future<void> playAudio(String url) async {
    try {
      await _player.play(UrlSource(url));
    } catch (e) {
      print('Erreur playAudio: $e');
    }
  }

  /// Pause la lecture
  Future<void> pauseAudio() async {
    try {
      await _player.pause();
    } catch (e) {
      print('Erreur pauseAudio: $e');
    }
  }

  /// Resume la lecture
  Future<void> resumeAudio() async {
    try {
      await _player.resume();
    } catch (e) {
      print('Erreur resumeAudio: $e');
    }
  }

  /// Obtenir l'état de la lecture
  Stream<PlayerState> getPlayerState() {
    return _player.onPlayerStateChanged;
  }

  /// Obtenir la durée totale
  Future<Duration?> getDuration(String url) async {
    try {
      return await _player.getDuration();
    } catch (e) {
      print('Erreur getDuration: $e');
      return null;
    }
  }

  /// Obtenir la position actuelle
  Stream<Duration> getPosition() {
    return _player.onPositionChanged;
  }

  /// Arrêter complètement la lecture
  Future<void> stopAudio() async {
    try {
      await _player.stop();
    } catch (e) {
      print('Erreur stopAudio: $e');
    }
  }

  /// Nettoyer les ressources
  Future<void> dispose() async {
    try {
      await _recorder.dispose();
      await _player.dispose();

      // Nettoyer le fichier temporaire si sur mobile
      if (_recordingPath != null && !kIsWeb) {
        await audio_file.deleteFileIfExists(_recordingPath!);
      }
    } catch (e) {
      print('Erreur dispose: $e');
    }
  }

  /// Vérifier si la permission microphone est accordée
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }
}
