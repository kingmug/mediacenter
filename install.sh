REPO_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $REPO_DIR

source $REPO_DIR/config/globals.conf

declare -A variables
while IFS='= ' read var val
do
    if [ ! -z "$var" ]; then
        variables["$var"]="$val"
    fi
done < config/globals.conf

if [ -z "${variables['ROOT_FOLDER']}" ]; then
    echo ""
    echo "ERROR: You should configure it first. See file config/globals.conf"
    echo ""
    exit
fi

# Prepare root folder
if [ ! -d $ROOT_FOLDER ]; then 
  mkdir $ROOT_FOLDER
fi

# Link to storage folder
cd $ROOT_FOLDER

if [ -L storage ]; then 
  rm storage
fi
ln -s "$STORAGE_ROOT_FOLDER" storage

# Setup download folders
storageFolder=$ROOT_FOLDER/storage
downloadsFolder=$storageFolder/downloads
movies=$downloadsFolder/movies
unordered=$downloadsFolder/unordered
torrents=$downloadsFolder/torrents
series=$downloadsFolder/series
downloading=$downloadsFolder/downloading
subtitles=$downloadsFolder/subtitles

# Create docker folder
cd $storageFolder
dockerStorageFolder=$storageFolder/.mediacenter-docker-files
if [ ! -d $storageFolder/.mediacenter-docker-files ]; then 
  mkdir $storageFolder/.mediacenter-docker-files
fi




rm -rf $REPO_DIR/config/generated
mkdir $REPO_DIR/config/generated
cp -r $REPO_DIR/config-templates/* $REPO_DIR/config/generated

cd $REPO_DIR
for i in $REPO_DIR/config/generated/*; do
    #echo "Processing config file $i"
    cp ${i} tmp
    for j in ${!variables[@]}; do
        result="sed -e 's|<${j}>|${variables[$j]}|g' tmp > tmp2"
        #echo "Replacing var $j: $result"
        eval $result

        mv tmp2 tmp
    done
    mv tmp "$i"
done


#echo "Setting up series"
declare -A series
while IFS=$'    ' read -r f1 f2; do 
   series[$f1]=$f2;
done < $REPO_DIR/config/series.csv



sudo add-apt-repository -y ppa:team-xbmc/ppa

sudo apt-get update
sudo apt-get install linux-image-generic curl

# Get the latest Docker package
curl -sSL https://get.docker.com/ | sh

# Create the docker group and add your user.
sudo usermod -aG docker "${USER}"



docker rm -f `docker ps --no-trunc -aq`



# Install File manager
#docker build -t cron cron
crontab $REPO_DIR/cron/crontab




#### Install transmission
cd $REPO_DIR
git clone https://github.com/dgholz/docker-transmission.git
cd docker-transmission
docker build -t transmission .
rm -rf $REPO_DIR/docker-transmission

# Override config
mkdir -p $dockerStorageFolder/transmission/config/
if [ ! -f $dockerStorageFolder/transmission/config/settings.json ]; then 
  cp $REPO_DIR/config/generated/transmission.json $dockerStorageFolder/transmission/config/settings.json
fi







#### Install Sickbeard
cd $REPO_DIR
git clone http://github.com/timhaak/docker-sickrage.git
cd docker-sickrage
docker build -t sickrage .
rm -rf $REPO_DIR/docker-sickrage

# Override config
mkdir -p $dockerStorageFolder/sickrage/config/
if [ ! -f $dockerStorageFolder/sickrage/config/config.ini ]; then 
  cp $REPO_DIR/config/generated/sickbeard.ini $dockerStorageFolder/sickrage/config/config.ini
fi








#### Install couchpotato
cd $REPO_DIR
git clone https://github.com/timhaak/docker-couchpotato.git
cd docker-couchpotato
docker build -t couchpotato .
rm -rf $REPO_DIR/docker-couchpotato

# Override config
mkdir -p $dockerStorageFolder/couchpotato/config/
if [ ! -f $dockerStorageFolder/couchpotato/config/CouchPotato.cfg ]; then 
  cp $REPO_DIR/config/generated/couchpotato.cfg $dockerStorageFolder/couchpotato/config/CouchPotato.cfg
fi




#docker run -d \
# --name cron \
# -v $dockerStorageFolder/data/downloads:/data \
# -v $dockerStorageFolder/data/shazam-tags:/shazam-tags \
# cron

docker run -d \
 --name transmission1 \
 -v $downloadsFolder/unordered:/transmission/download \
 -v $dockerStorageFolder/transmission/config:/transmission/config \
 -p 9091:9091 \
 -p 51413:51413 \
 -p 51413:51413/udp \
 transmission

docker run \
 --name transmissionClient \
 --link transmission1:transmission \
 busybox

docker run -d \
 --name sickrage \
 -h localhost \
 -v $dockerStorageFolder/sickrage/config:/config \
 -v $downloadsFolder/series:/data \
 -p 8081:8081 \
 sickrage


# Run docker container
docker run -d \
 --name couchpotato \
 -h localhost \
 -v $dockerStorageFolder/couchpotato/config:/config \
 -v $downloadsFolder/movies:/data \
 -p 5050:5050 \
 couchpotato


cp $REPO_DIR/config/kodi.desktop $HOME/.config/autostart/
cp $REPO_DIR/config/generated/start-mediacenter.desktop $HOME/.config/autostart/

echo "enabled=0" | sudo tee /etc/default/apport

#### Install KODI
echo "Installing XBMC"
sudo apt-get install xbmc

# Generate the kodi configuration
if [ ! -d $dockerStorageFolder/kodi ]; then 
  mkdir $dockerStorageFolder/kodi
fi
if [ ! -f $dockerStorageFolder/kodi/sources.xml ]; then 
  cp $REPO_DIR/config-templates/kodi-sources.xml $dockerStorageFolder/kodi/sources.xml
fi
cd $HOME/.kodi/userdata/
rm sources.xml
ln -s $dockerStorageFolder/kodi/sources.xml
