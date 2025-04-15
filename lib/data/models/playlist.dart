class Playlist {
  final String id;
  final String name;
  final int songCount;
  final String? coverUrl;
  final bool isCreated; // 是否为用户创建的歌单
  final String? username;

  Playlist({
    required this.id,
    required this.name,
    required this.songCount,
    this.coverUrl,
    required this.isCreated,
    this.username,
  });

  factory Playlist.fromJson(Map<String, dynamic> json,
      {bool isCreated = false}) {
    // 尝试从多个可能的字段名中获取歌单ID
    String id = '';

    if (json['global_collection_id'] != null) {
      id = json['global_collection_id'].toString();
    } else if (json['listid'] != null) {
      id = json['listid'].toString();
    } else if (json['list_id'] != null) {
      id = json['list_id'].toString();
    } else if (json['id'] != null) {
      id = json['id'].toString();
    }

    print(
        '解析歌单ID: $id, 原始数据中的ID字段: global_collection_id=${json['global_collection_id']}, listid=${json['listid']}');

    return Playlist(
      id: id,
      name: json['name'] ?? '未知歌单',
      songCount: json['count'] ?? 0,
      coverUrl: json['pic'],
      isCreated: isCreated,
      username: json['list_create_username'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songCount': songCount,
        'coverUrl': coverUrl,
        'isCreated': isCreated,
        'username': username,
      };
}

class PlaylistResponse {
  final List<Playlist> createdPlaylists;
  final List<Playlist> collectedPlaylists;

  PlaylistResponse({
    required this.createdPlaylists,
    required this.collectedPlaylists,
  });

  factory PlaylistResponse.fromJson(Map<String, dynamic> json) {
    final List<Playlist> created = [];
    final List<Playlist> collected = [];

    try {
      // 首先检查是否存在data字段
      final data = json['data'] is Map ? json['data'] : json;

      // 然后检查info字段是否存在且是列表
      if (data != null && data['info'] != null && data['info'] is List) {
        for (var item in data['info']) {
          try {
            if (item is Map<String, dynamic>) {
              final isMine = item['is_mine'] == 1 || item['is_mine'] == true;
              if (isMine) {
                created.add(Playlist.fromJson(item, isCreated: true));
              } else {
                collected.add(Playlist.fromJson(item, isCreated: false));
              }
            }
          } catch (e) {
            print('解析歌单项目失败: $e, 项目: $item');
            // 继续处理下一项
          }
        }
      }
    } catch (e) {
      print('解析歌单响应失败: $e, 原始数据: $json');
    }

    return PlaylistResponse(
      createdPlaylists: created,
      collectedPlaylists: collected,
    );
  }
}
