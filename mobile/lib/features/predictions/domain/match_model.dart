enum MatchStatus { upcoming, live, finished }

class League {
  final String id;
  final String name;
  final String country;
  final String? flagEmoji;

  const League({
    required this.id,
    required this.name,
    required this.country,
    this.flagEmoji,
  });
}

class Team {
  final String id;
  final String name;
  final String? logoUrl;

  const Team({required this.id, required this.name, this.logoUrl});
}

class MatchScore {
  final int home;
  final int away;

  const MatchScore({required this.home, required this.away});
}

class Match {
  final String id;
  final int? externalId;
  final Team homeTeam;
  final Team awayTeam;
  final League league;
  final DateTime dateTime;
  final MatchStatus status;
  final MatchScore? score;
  final int? minute;
  final int tier;

  const Match({
    required this.id,
    this.externalId,
    required this.homeTeam,
    required this.awayTeam,
    required this.league,
    required this.dateTime,
    required this.status,
    this.score,
    this.minute,
    this.tier = 2,
  });

  String get statusLabel {
    switch (status) {
      case MatchStatus.live:
        return minute != null ? "$minute'" : "LIVE";
      case MatchStatus.finished:
        return "Terminé";
      case MatchStatus.upcoming:
        return "";
    }
  }
}
