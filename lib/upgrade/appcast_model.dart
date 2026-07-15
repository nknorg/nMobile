class AppcastModel {
  final String minVersion;
  final String latestVersion;
  final Map<String, String> releaseNotes;
  final AppcastLinks links;

  AppcastModel({
    required this.minVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.links,
  });

  factory AppcastModel.fromJson(Map<String, dynamic> json) {
    return AppcastModel(
      minVersion: json['minVersion'] as String? ?? '',
      latestVersion: json['latestVersion'] as String? ?? '',
      releaseNotes: (json['releaseNotes'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value.toString())) ??
          {},
      links: AppcastLinks.fromJson(json['links'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class AppcastLinks {
  final String ios;
  final String androidPlay;
  final String androidApk;

  AppcastLinks({
    required this.ios,
    required this.androidPlay,
    required this.androidApk,
  });

  factory AppcastLinks.fromJson(Map<String, dynamic> json) {
    return AppcastLinks(
      ios: json['ios'] as String? ?? '',
      androidPlay: json['android_play'] as String? ?? '',
      androidApk: json['android_apk'] as String? ?? '',
    );
  }
}

