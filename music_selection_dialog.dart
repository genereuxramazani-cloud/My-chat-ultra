import 'package:flutter/material.dart';

import '../theme.dart';

class MusicSuggestion {
  final String title;
  final String artist;
  final String audioUrl;

  const MusicSuggestion({
    required this.title,
    required this.artist,
    required this.audioUrl,
  });

  String get label => '$title • $artist';
}

const List<MusicSuggestion> trendingMusicSuggestions = [
  // Pop/Electronic
  MusicSuggestion(
    title: 'Sunset Drive',
    artist: 'Neon Wave',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  ),
  MusicSuggestion(
    title: 'Midnight City',
    artist: 'Luna Beats',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
  ),
  MusicSuggestion(
    title: 'Ocean Breeze',
    artist: 'Skyline Soul',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
  ),
  MusicSuggestion(
    title: 'Electric Heart',
    artist: 'Pulse Mode',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
  ),
  MusicSuggestion(
    title: 'Dream Pop',
    artist: 'Cloud Nine',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
  ),
  MusicSuggestion(
    title: 'City Lights',
    artist: 'Retro Groove',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
  ),
  MusicSuggestion(
    title: 'Velvet Rhythm',
    artist: 'Noir Sound',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
  ),
  MusicSuggestion(
    title: 'Cosmic Chill',
    artist: 'Stellar Echo',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
  ),
  MusicSuggestion(
    title: 'Afterglow',
    artist: 'Echo Avenue',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
  ),
  MusicSuggestion(
    title: 'Neon Nights',
    artist: 'Lofi Lounge',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
  ),
  // Chill/Lofi
  MusicSuggestion(
    title: 'Sky High',
    artist: 'Delta V',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3',
  ),
  MusicSuggestion(
    title: 'Golden Hour',
    artist: 'Aqua Tempo',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
  ),
  MusicSuggestion(
    title: 'Rainy Days',
    artist: 'Chill Vibes',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  ),
  MusicSuggestion(
    title: 'Moonlight Jazz',
    artist: 'Night Owl',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
  ),
  MusicSuggestion(
    title: 'Summer Vibes',
    artist: 'Sunny Days',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
  ),
  MusicSuggestion(
    title: 'Cafe Ambiance',
    artist: 'Background Beats',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
  ),
  // Hip-Hop/Rap
  MusicSuggestion(
    title: 'Urban Pulse',
    artist: 'Street Kings',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
  ),
  MusicSuggestion(
    title: 'Rhythm Nation',
    artist: 'Bass Master',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
  ),
  MusicSuggestion(
    title: 'Flow State',
    artist: 'Hip Hop Kings',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
  ),
  MusicSuggestion(
    title: 'Street Heat',
    artist: 'Rap Legends',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
  ),
  // Rock/Alternative
  MusicSuggestion(
    title: 'Rock Anthem',
    artist: 'Guitar Heroes',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
  ),
  MusicSuggestion(
    title: 'Alternative Waves',
    artist: 'Indie Rebellion',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
  ),
  MusicSuggestion(
    title: 'Electric Storm',
    artist: 'Rock Rising',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3',
  ),
  MusicSuggestion(
    title: 'Rebellious Soul',
    artist: 'Alternative Echo',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',
  ),
  // Dance/EDM
  MusicSuggestion(
    title: 'Dance Floor Energy',
    artist: 'DJ Phoenix',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  ),
  MusicSuggestion(
    title: 'Festival Vibes',
    artist: 'Electronic Beats',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
  ),
  MusicSuggestion(
    title: 'Techno Paradise',
    artist: 'Synth Masters',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
  ),
  MusicSuggestion(
    title: 'Bass Drop',
    artist: 'EDM Kings',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
  ),
  // Soul/R&B
  MusicSuggestion(
    title: 'Smooth Groove',
    artist: 'Soul Singers',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
  ),
  MusicSuggestion(
    title: 'R&B Nights',
    artist: 'Silky Voices',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
  ),
  MusicSuggestion(
    title: 'Soulful Melodies',
    artist: 'Heart & Soul',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
  ),
  // Indie/Folk
  MusicSuggestion(
    title: 'Acoustic Dreams',
    artist: 'Folk Tales',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
  ),
  MusicSuggestion(
    title: 'Indie Folk',
    artist: 'Storytellers',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
  ),
  MusicSuggestion(
    title: 'Whispered Words',
    artist: 'Acoustic Harmony',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
  ),
];

Future<Map<String, dynamic>?> showMusicSelectionDialog(
    BuildContext context, TextEditingController captionController) async {
  captionController.clear();
  MusicSuggestion? selectedMusic;
  String searchQuery = '';

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final filteredSuggestions = searchQuery.isEmpty
          ? trendingMusicSuggestions
          : trendingMusicSuggestions
              .where((music) =>
                  music.title
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()) ||
                  music.artist
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()))
              .toList();

      return Dialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Nouvelle publication',
                  style: TextStyle(
                      color: kCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.5)),
              const SizedBox(height: 16),
              TextField(
                controller: captionController,
                style: const TextStyle(color: kText),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Décris ta publication...',
                  hintStyle: TextStyle(color: kTextDim),
                ),
              ),
              const SizedBox(height: 20),
              // Recherche musique
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: kText),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une musique...',
                        hintStyle: const TextStyle(color: kTextDim),
                        prefixIcon: const Icon(Icons.search, color: kCyan),
                        suffixIcon: searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () => setState(() => searchQuery = ''),
                                child: const Icon(Icons.clear, color: kTextDim),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: kTextDim, width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: kTextDim.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: kCyan, width: 1.5),
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => searchQuery = value.trim()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filteredSuggestions.length} musique${filteredSuggestions.length != 1 ? 's' : ''} trouvée${filteredSuggestions.length != 1 ? 's' : ''}',
                  style: TextStyle(
                      color: kTextDim,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 10),
              // Liste des musiques filtrées
              if (filteredSuggestions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(Icons.music_off_outlined, color: kTextDim, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Aucune musique trouvée',
                        style: TextStyle(color: kTextDim, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.vertical,
                    itemCount: filteredSuggestions.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected = selectedMusic == null;
                        return ChoiceChip(
                          label: const Text('✕ Aucune musique'),
                          selected: isSelected,
                          selectedColor: kViolet,
                          backgroundColor: kCard,
                          labelStyle: TextStyle(
                              color: isSelected ? Colors.white : kText),
                          onSelected: (_) =>
                              setState(() => selectedMusic = null),
                        );
                      }
                      final suggestion = filteredSuggestions[index - 1];
                      final isSelected = selectedMusic == suggestion;
                      return ChoiceChip(
                        label: Text(suggestion.label,
                            style: TextStyle(
                                color: isSelected ? Colors.white : kText,
                                fontSize: 12)),
                        selected: isSelected,
                        selectedColor: kViolet,
                        backgroundColor: kCard,
                        side: BorderSide(
                            color: isSelected
                                ? kViolet
                                : kTextDim.withOpacity(0.5)),
                        onSelected: (_) {
                          setState(() => selectedMusic = suggestion);
                        },
                      );
                    },
                  ),
                ),
              if (selectedMusic != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: kViolet.withOpacity(0.1),
                    border: Border.all(color: kViolet.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.music_note, color: kCyan, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(selectedMusic!.label,
                          style: const TextStyle(color: kCyan, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kTextDim)),
                      child: const Center(
                          child: Text('Annuler',
                              style: TextStyle(color: kTextDim))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, {
                      'caption': captionController.text.trim(),
                      'music': selectedMusic != null
                          ? {
                              'title': selectedMusic!.title,
                              'artist': selectedMusic!.artist,
                              'audioUrl': selectedMusic!.audioUrl,
                              'label': selectedMusic!.label,
                            }
                          : null,
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient:
                              const LinearGradient(colors: [kViolet, kPink])),
                      child: const Center(
                          child: Text('Publier',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      );
    }),
  );
}
