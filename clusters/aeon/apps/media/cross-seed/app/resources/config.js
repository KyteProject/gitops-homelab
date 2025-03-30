// Torrent content layout: Original
// media Torrent Management Mode: Automatic
// media Save Path: /media/downloads/torrents/complete
// Incomplete Save Path: /media/downloads/torrents/incomplete

module.exports = {
  action: "inject",
  apiKey: process.env.CROSS_SEED_API_KEY,
  delay: 30,
  duplicateCategories: false,
  flatLinking: false,
  includeEpisodes: true,
  includeNonVideos: true,
  includeSingleEpisodes: true,
  linkCategory: "cross-seed",
  linkDirs: [
    "/torrents/audiobooks",
    "/torrents/anime",
    "/torrents/books",
    "/torrents/games",
    "/torrents/movies",
    "/torrents/music",
    "/torrents/software",
    "/torrents/tv"
  ],
  linkType: "hardlink",
  matchMode: "partial",
  outputDir: null,
  port: Number(process.env.CROSS_SEED_PORT),
  qbittorrentUrl: "http://qbittorrent.media.svc.cluster.local:8080",
  radarr: [
    "http://radarr.media.svc.cluster.local:7878/?apikey=" + process.env.RADARR_API_KEY
  ],
  skipRecheck: true,
  sonarr: [
    "http://sonarr.media.svc.cluster.local:8989/?apikey=" + process.env.SONARR_API_KEY
  ],
  torznab: [
    'http://prowlarr.media.svc.cluster.local:9696/1/api',
    'http://prowlarr.media.svc.cluster.local:9696/2/api',
    'http://prowlarr.media.svc.cluster.local:9696/3/api',
    'http://prowlarr.media.svc.cluster.local:9696/36/api',
    'http://prowlarr.media.svc.cluster.local:9696/35/api'
  ],
  useClientTorrents: true,
};
