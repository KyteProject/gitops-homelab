#!/bin/sh

# Create config directory if it doesn't exist
mkdir -p /config/qBittorrent

# Set up qBittorrent.conf
cat > /config/qBittorrent/qBittorrent.conf << EOF
[AutoRun]
enabled=false
program=

[BitTorrent]
Session\AddTorrentStopped=false
Session\AsyncIOThreadsCount=10
Session\DiskCacheSize=-1
Session\DiskIOReadMode=DisableOSCache
Session\DiskIOType=SimplePreadPwrite
Session\DiskIOWriteMode=EnableOSCache
Session\DiskQueueSize=4194304
Session\FilePoolSize=40
Session\HashingThreadsCount=2
Session\Port=${QBT_TORRENTING_PORT}
Session\QueueingSystemEnabled=true
Session\ResumeDataStorageType=SQLite
Session\SSL\Port=15203
Session\ShareLimitAction=Stop
Session\UseOSCache=true
Session\UseRandomPort=false

[LegalNotice]
Accepted=true

[Meta]
MigrationVersion=8

[Network]
Cookies=@Invalid()
PortForwardingEnabled=false
Proxy\HostnameLookupEnabled=false
Proxy\Profiles\BitTorrent=true
Proxy\Profiles\Misc=true
Proxy\Profiles\RSS=true

[Preferences]
Connection\PortRangeMin=6881
Connection\UPnP=false
General\Locale=en
General\UseRandomPort=false
WebUI\Address=*
WebUI\CSRFProtection=false
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=false
WebUI\ServerDomains=*
WebUI\UseUPnP=false
WebUI\Username=admin
WebUI\Password_PBKDF2=admin
EOF

# Start qBittorrent
exec /usr/bin/qbittorrent-nox
