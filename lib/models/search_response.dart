import 'dart:convert';

class SearchResponse {
  final List<SearchSong> lists;
  final int indextotal;
  final int correctiontype;
  final String algPath;

  SearchResponse({
    required this.lists,
    required this.indextotal,
    required this.correctiontype,
    required this.algPath,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      lists: (json['data']['lists'] as List)
          .map((x) => SearchSong.fromJson(x))
          .toList(),
      indextotal: json['data']['indextotal'] ?? 0,
      correctiontype: json['data']['correctiontype'] ?? 0,
      algPath: json['data']['AlgPath'] ?? '',
    );
  }
}

class SearchSong {
  final String sqFileHash;
  final int sqFileSize;
  final String image;
  final int fileSize;
  final String fileHash;
  final String fileName;
  final String songName;
  final List<Singer> singers;
  final String mixSongId;
  final int? duration;

  SearchSong({
    required this.sqFileHash,
    required this.sqFileSize,
    required this.image,
    required this.fileSize,
    required this.fileHash,
    required this.fileName,
    required this.songName,
    required this.singers,
    required this.mixSongId,
    this.duration,
  });

  factory SearchSong.fromJson(Map<String, dynamic> json) {
    return SearchSong(
      sqFileHash: json['SQFileHash'] ?? '',
      sqFileSize: json['SQFileSize'] ?? 0,
      image: json['Image'] ?? '',
      fileSize: json['FileSize'] ?? 0,
      fileHash: json['FileHash'] ?? '',
      fileName: json['FileName'] ?? '',
      songName: json['SongName'] ?? '',
      singers: json['Singers'] != null
          ? (json['Singers'] as List).map((x) => Singer.fromJson(x)).toList()
          : [],
      mixSongId: json['MixSongID']?.toString() ?? '',
      duration: json['Duration'] is int
          ? json['Duration']
          : int.tryParse(json['Duration']?.toString() ?? '0'),
    );
  }
}

class Singer {
  final String name;
  final int ipId;
  final int id;

  Singer({
    required this.name,
    required this.ipId,
    required this.id,
  });

  factory Singer.fromJson(Map<String, dynamic> json) {
    return Singer(
      name: json['name'] ?? '',
      ipId: json['ip_id'] ?? 0,
      id: json['id'] ?? 0,
    );
  }
}
