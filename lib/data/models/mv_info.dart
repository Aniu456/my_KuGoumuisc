class MvInfo {
  final int videoId;
  final String title;
  final String? author;
  final String? publishDate;
  final String? imgUrl;
  final int? duration;
  final String? hash;

  MvInfo({
    required this.videoId,
    required this.title,
    this.author,
    this.publishDate,
    this.imgUrl,
    this.duration,
    this.hash,
  });

  factory MvInfo.fromJson(Map<String, dynamic> json) {
    return MvInfo(
      videoId: json['video_id'] ?? 0,
      title: json['name'] ?? json['title'] ?? '',
      author: json['author_name'] ?? json['author'],
      publishDate: json['publish_date'],
      imgUrl: json['img'] ?? json['cover'],
      duration: json['duration'],
      hash: json['hash'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'name': title,
      'author_name': author,
      'publish_date': publishDate,
      'img': imgUrl,
      'duration': duration,
      'hash': hash,
    };
  }
}
