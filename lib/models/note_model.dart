class Note {
  String id;
  String title;
  String body;
  String? imagePath;
  String? voicePath;
  bool isVoice;
  bool isVideo;

  Note({
    required this.id,
    required this.title,
    required this.body,
    this.imagePath,
    this.voicePath,
    this.isVoice = false,
    this.isVideo = false,
  });
}
