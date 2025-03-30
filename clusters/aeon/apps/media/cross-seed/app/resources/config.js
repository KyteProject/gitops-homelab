// Torrent content layout: Original
// Default Torrent Management Mode: Automatic
// Default Save Path: /media/downloads/torrents/complete
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
  outputDir: "/tmp",
  port: Number(process.env.CROSS_SEED_PORT),
  qbittorrentUrl: "http://qbittorrent.media.svc.cluster.local:8080",
  radarr: [
    `http://radarr.default.svc.cluster.local/?apikey=${RADARR_API_KEY}`
  ],
  skipRecheck: true,
  sonarr: [
    `http://sonarr.default.svc.cluster.local/?apikey=${SONARR_API_KEY}`
  ],
  torznab: [],
  useClientTorrents: true,
};
