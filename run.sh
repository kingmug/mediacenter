
docker run -d \
 --name cron \
 -v $TARGET_DIR/data/downloads:/data \
 -v $TARGET_DIR/data/shazam-tags:/shazam-tags \
 cron

docker run -d \
 --name transmission1 \
 -v $TARGET_DIR/data/downloads/unordered:/transmission/download \
 -v $TARGET_DIR/transmission/config:/transmission/config \
 -p 9091:9091 \
 -p 51413:51413 \
 -p 51413:51413/udp \
 transmission

 docker run \
 --name transmissionClient \
 --link transmission1:transmission \
 busybox

docker run -d \
 --name="sickrage" \
 -h localhost \
 -v $TARGET_DIR/sickrage/config:/config \
 -v $TARGET_DIR/data/downloads/series:/data \
 -p 8081:8081 \
 sickrage


# Run docker container
docker run -d \
 --name couchpotato \
 -h localhost \
 -v $TARGET_DIR/couchpotato/config:/config \
 -v $TARGET_DIR/data/downloads/movies:/data \
 -p 5050:5050 \
 couchpotato
