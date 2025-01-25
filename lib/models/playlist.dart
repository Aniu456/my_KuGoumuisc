class Playlist {
  final String name;
  final String pic;
  final int count;
  final String listCreateGid;
  final String globalCollectionId;
  final String listCreateUserid;
  final DateTime createTime;

  Playlist({
    required this.name,
    required this.pic,
    required this.count,
    required this.listCreateGid,
    required this.globalCollectionId,
    required this.listCreateUserid,
    required this.createTime,
  });

  // 空歌单构造函数
  factory Playlist.empty() {
    return Playlist(
      name: '',
      pic: '',
      count: 0,
      listCreateGid: '',
      globalCollectionId: '',
      listCreateUserid: '',
      createTime: DateTime.now(),
    );
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    String picUrl = json['pic']?.toString() ?? '';
    // 如果pic是空字符串，尝试使用create_user_pic
    if (picUrl.isEmpty) {
      picUrl = json['create_user_pic']?.toString() ?? '';
    }

    // 解析创建时间
    DateTime createTime;
    try {
      createTime = DateTime.parse(json['create_time']?.toString() ?? '');
    } catch (e) {
      createTime = DateTime.now(); // 如果解析失败，使用当前时间
    }

    return Playlist(
      name: json['name']?.toString() ?? '',
      pic: picUrl,
      count: json['count'] is int
          ? json['count']
          : int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      listCreateGid: json['list_create_gid']?.toString() ?? '',
      globalCollectionId: json['global_collection_id']?.toString() ?? '',
      listCreateUserid: json['list_create_userid']?.toString() ?? '',
      createTime: createTime,
    );
  }
}
