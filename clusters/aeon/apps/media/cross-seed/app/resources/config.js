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
    "/media/torrents/audiobooks",
    "/media/torrents/anime",
    "/media/torrents/books",
    "/media/torrents/games",
    "/media/torrents/movies",
    "/media/torrents/music",
    "/media/torrents/software",
    "/media/torrents/tv"
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
    "http://prowlarr.media.svc.cluster.local:9696/?apikey=" + process.env.SONARR_API_KEY
  ],
  torznab: [],
  useClientTorrents: true,
};
