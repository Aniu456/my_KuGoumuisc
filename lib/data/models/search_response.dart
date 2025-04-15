// class SearchResponse {
//   final bool success;
//   final String? message;
//   final List<SearchSongItem> songs;
//   final int total;
//   final int page;
//   final int pageSize;

//   SearchResponse({
//     required this.success,
//     this.message,
//     required this.songs,
//     required this.total,
//     required this.page,
//     required this.pageSize,
//   });

//   factory SearchResponse.fromJson(Map<String, dynamic> json) {
//     final bool success = json['status'] == 1;
//     final List<dynamic> songsData = json['data']['info'] ?? [];

//     return SearchResponse(
//       success: success,
//       message: json['error_msg'],
//       songs: songsData.map((item) => SearchSongItem.fromJson(item)).toList(),
//       total: json['data']['total'] ?? 0,
//       page: json['data']['page'] ?? 1,
//       pageSize: json['data']['pagesize'] ?? 20,
//     );
//   }
// }

// class SearchSongItem {
//   final String hash;
//   final String title;
//   final String artist;
//   final String? albumId;
//   final String? albumName;
//   final String? imgUrl;
//   final String? duration;
//   final bool? isVip;
//   final int? bitRate;
//   final int? fileSize;

//   SearchSongItem({
//     required this.hash,
//     required this.title,
//     required this.artist,
//     this.albumId,
//     this.albumName,
//     this.imgUrl,
//     this.duration,
//     this.isVip,
//     this.bitRate,
//     this.fileSize,
//   });

//   factory SearchSongItem.fromJson(Map<String, dynamic> json) {
//     return SearchSongItem(
//       hash: json['hash'] ?? '',
//       title: json['songname'] ?? '',
//       artist: json['singername'] ?? '',
//       albumId: json['album_id']?.toString(),
//       albumName: json['album_name'],
//       imgUrl: json['img'],
//       duration: json['duration']?.toString(),
//       isVip: json['privilege'] == 5 || json['privilege'] == 1,
//       bitRate: json['bitrate'],
//       fileSize: json['filesize'],
//     );
//   }
// }

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
