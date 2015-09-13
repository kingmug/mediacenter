REPO_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $REPO_DIR

source $REPO_DIR/config/globals.sh

rm -rf config/generated
mkdir config/generated
cp -r config-templates/* config/generated

declare -A variables
while IFS='= ' read var val
do
	if [ ! -z "$var" ]; then
    	variables["$var"]="$val"
	fi
done < config/globals.sh



for i in config/generated/*; do
	echo "Processing config file $i"
	cp ${i} tmp
	for j in ${!variables[@]}; do
		result="sed -e 's|<${j}>|${variables[$j]}|g' tmp > tmp2"
		echo "Replacing var $j: $result"
		eval $result

		mv tmp2 tmp
	done
	mv tmp "$i"
done


declare -A series
while IFS=$'    ' read -r f1 f2; do 
   series[$f1]=$f2;
done < $REPO_DIR/config/series.csv


bash $REPO_DIR/cron/scripts/move-series.sh
#for pattern in "${!series[@]}"
#do
        #echo ${series[$pattern]}
#done




sudo add-apt-repository ppa:team-xbmc/ppa

sudo apt-get update
sudo apt-get install linux-image-generic
sudo apt-get install curl

# Get the latest Docker package
curl -sSL https://get.docker.com/ | sh

# Create the docker group and add your user.
sudo usermod -aG docker arthur



docker rm -f `docker ps --no-trunc -aq`

sudo rm -rf $TARGET_DIR
mkdir $TARGET_DIR

# Install file manager

docker build -t cron cron
docker run -d \
 --name cron \
 -v $TARGET_DIR/data/downloads:/data \
 -v $TARGET_DIR/data/shazam-tags:/shazam-tags \
 cron








#### Install transmission

# Install docker image
cd $REPO_DIR

# Run docker container
docker run -d \
 --name transmission1 \
 -v $TARGET_DIR/data/downloads/unordered:/transmission/download \
 -v $TARGET_DIR/transmission/config:/transmission/config \
 -p 9091:9091 \
 -p 51413:51413 \
 -p 51413:51413/udp \
 dgholz/docker-transmission
rm -rf $REPO_DIR/docker-transmission

# Override config
sudo cp $REPO_DIR/config/generated/transmission.json $TARGET_DIR/transmission/config/settings.json
docker restart "transmission1"







#### Install Transmission ambassador

docker run \
 --name transmissionClient \
 --link transmission1:transmission \
 busybox








#### Install Sickbeard

# Install docker image
cd $REPO_DIR
git clone git@github.com:timhaak/docker-sickrage.git
cd docker-sickrage
docker build -t sickrage .
rm -rf $REPO_DIR/docker-sickrage

# Run docker container
docker run -d \
 --name="sickrage" \
 -h localhost \
 -v $TARGET_DIR/sickrage/config:/config \
 -v $TARGET_DIR/data/downloads/series:/data \
 -p 8081:8081 \
 sickrage

# Override config
sudo cp $REPO_DIR/config/generated/sickbeard.ini $TARGET_DIR/sickrage/config/config.ini
docker restart "sickrage"






#### Install couchpotato

# Install docker image
cd $REPO_DIR
git clone https://github.com/timhaak/docker-couchpotato.git
cd docker-couchpotato
docker build -t couchpotato .
rm -rf $REPO_DIR/docker-couchpotato

# Run docker container
docker run -d \
 --name couchpotato \
 -h localhost \
 -v $TARGET_DIR/couchpotato/config:/config \
 -v $TARGET_DIR/data/downloads/movies:/data \
 -p 5050:5050 \
 couchpotato

# Override config
sudo cp $REPO_DIR/config/generated/couchpotato.cfg $TARGET_DIR/couchpotato/config/CouchPotato.cfg
docker restart "couchpotato"





#### Install KODI

# Install XBMC
sudo apt-get install xbmc python-software-properties pkg-config software-properties-common
