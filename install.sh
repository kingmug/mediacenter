REPO_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $REPO_DIR

echo "enabled=0" | sudo tee /etc/default/apport > /dev/null

source $REPO_DIR/config/globals.conf

if [ -z "${ROOT_FOLDER}" ]; then
    echo "ERROR: You should configure ROOT_FOLDER first. See file config/globals.conf"
    exit
fi
if [ -z "${STORAGE_ROOT_FOLDER}" ]; then
    echo "ERROR: You should configure STORAGE_ROOT_FOLDER first. See file config/globals.conf"
    exit
fi
if [ -z "${IP_ADDRESS}" ]; then
    echo "ERROR: You should configure IP_ADDRESS first. See file config/globals.conf"
    exit
fi



# Setup download folders
storageFolder=$ROOT_FOLDER/storage
downloadsFolder=$storageFolder/downloads
movies=$downloadsFolder/movies
unordered=$downloadsFolder/unordered
torrents=$downloadsFolder/torrents
series=$downloadsFolder/series
downloading=$downloadsFolder/downloading
subtitles=$downloadsFolder/subtitles

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

# Create docker folder
cd $storageFolder
dockerStorageFolder=$storageFolder/.mediacenter-docker-files
if [ ! -d $storageFolder/.mediacenter-docker-files ]; then 
  mkdir $storageFolder/.mediacenter-docker-files
fi



declare -A variables
variables['couchpotato.movies']="/transmission/download-movies"
variables['couchpotato.password']="$USER"
variables['couchpotato.IP_ADDRESS']="$IP_ADDRESS"
variables['sickrage.series']="/transmission/download-series"
variables['sickrage.IP_ADDRESS']="$IP_ADDRESS"
variables['transmission.downloading']="/transmission/incomplete"
variables['transmission.home']="/transmission"
variables['transmission.unordered']="/transmission/download"


rm -rf $REPO_DIR/config/generated
mkdir $REPO_DIR/config/generated
cp -r $REPO_DIR/config-templates/* $REPO_DIR/config/generated

cd $REPO_DIR
for i in $REPO_DIR/config/generated/*; do
#    echo "Processing config file $i"
    cp ${i} tmp
    for j in ${!variables[@]}; do
        result="sed -e 's|\${${j}}|${variables[$j]}|g' tmp > tmp2"
#        echo "Replacing var $j: $result"
        eval $result

        mv tmp2 tmp
    done
    mv tmp "$i"
done

grep "\${" $REPO_DIR/config/generated/*
if [ "$?" -eq 0 ]; then
  echo "There are unresolved variables in the config files (see above lines). Exiting." 
  exit
fi


#echo "Setting up series"
declare -A series
while IFS=$'    ' read -r f1 f2; do 
   series[$f1]=$f2;
done < $REPO_DIR/config/series.csv


cp $REPO_DIR/config/kodi.desktop $HOME/.config/autostart/
cp $REPO_DIR/config/generated/start-mediacenter.desktop $HOME/.config/autostart/


if ! [ -x "$(command -v kodi)" ]; then
  echo "Package kodi (xbmc) is not installed. Installing now"
  sudo add-apt-repository -y ppa:team-xbmc/ppa >&2
  sudo apt-get update
  sudo apt-get install xbmc >&2
fi


# Generate the kodi configuration
cd $HOME/.kodi/userdata/
if [ ! -d $dockerStorageFolder/kodi ]; then 
  mkdir $dockerStorageFolder/kodi
fi
if [ ! -f $dockerStorageFolder/kodi/sources.xml ]; then 
  cp $REPO_DIR/config/generated/kodi-sources.xml $dockerStorageFolder/kodi/sources.xml
fi
rm sources.xml
ln -s $dockerStorageFolder/kodi/sources.xml

if [ ! -f $dockerStorageFolder/kodi/guisettings.xml ]; then 
  cp $REPO_DIR/config/generated/kodi-guisettings.xml $dockerStorageFolder/kodi/guisettings.xml
fi
rm guisettings.xml
ln -s $dockerStorageFolder/kodi/guisettings.xml





#if ! [ -x "$(command -v linux-image-generic)" ]; then
#  echo "Package linux-image-generic is not installed. Installing now"
#  sudo apt-get install linux-image-generic
#fi
if ! [ -x "$(command -v curl)" ]; then
  echo "Package curl is not installed. Installing now"
  sudo apt-get install curl
fi



if ! [ -x "$(command -v docker)" ]; then
  # Get the latest Docker package
  curl -sSL https://get.docker.com/ | sh

  # Create the docker group and add your user.
  sudo usermod -aG docker "${USER}"
fi


# Install the crontab
crontab $REPO_DIR/cron/crontab




# Delete all docker containers
docker rm -f `docker ps --no-trunc -aq`

#### Install transmission
docker ps -a | grep -q "mediacenter_transmission"
if [ "$?" -eq 0 ]; then
  cd $REPO_DIR
  git clone https://github.com/dgholz/docker-transmission.git
  cd docker-transmission
  docker build -t transmission .
  rm -rf $REPO_DIR/docker-transmission
fi

# Override config
mkdir -p $dockerStorageFolder/transmission/config/
if [ ! -f $dockerStorageFolder/transmission/config/settings.json ]; then 
  cp $REPO_DIR/config/generated/transmission.json $dockerStorageFolder/transmission/config/settings.json
fi


docker run -d \
 --name mediacenter_transmission \
 -v $downloadsFolder/series:/transmission/download-series \
 -v $downloadsFolder/movies:/transmission/download-movies \
 -v $downloadsFolder/downloading:/transmission/incomplete \
 -v $downloadsFolder/unordered:/transmission/download \
 -v $downloadsFolder/torrents:/transmission/watch \
 -v $dockerStorageFolder/transmission/config:/transmission/config \
 -p 9091:9091 \
 -p 51413:51413 \
 -p 51413:51413/udp \
 --restart=always \
 transmission

docker run -d \
 --name mediacenter_transmissionClient \
 --link mediacenter_transmission:transmission \
 --restart=always \
 busybox




#### Install Sickbeard
cd $REPO_DIR
docker ps -a | grep -q "mediacenter_sickrage"
if [ "$?" -eq 0 ]; then
  git clone http://github.com/timhaak/docker-sickrage.git
  cd docker-sickrage
  docker build -t sickrage .
  rm -rf $REPO_DIR/docker-sickrage
fi

# Override config
mkdir -p $dockerStorageFolder/sickrage/config/
if [ ! -f $dockerStorageFolder/sickrage/config/config.ini ]; then 
  cp $REPO_DIR/config/generated/sickbeard.ini $dockerStorageFolder/sickrage/config/config.ini
fi

docker run -d \
 --name mediacenter_sickrage \
 -h localhost \
 -v $dockerStorageFolder/sickrage/config:/config \
 -v $downloadsFolder/series:/transmission/download-series \
 -p 8081:8081 \
 --restart=always \
 sickrage












#### Install couchpotato
docker ps -a | grep -q "mediacenter_couchpotato"
if [ "$?" -eq 0 ]; then
  cd $REPO_DIR
  git clone https://github.com/timhaak/docker-couchpotato.git
  cd docker-couchpotato
  docker build -t couchpotato .
  rm -rf $REPO_DIR/docker-couchpotato
fi

# Override config
mkdir -p $dockerStorageFolder/couchpotato/config/
if [ ! -f $dockerStorageFolder/couchpotato/config/CouchPotato.cfg ]; then 
  cp $REPO_DIR/config/generated/couchpotato.cfg $dockerStorageFolder/couchpotato/config/CouchPotato.cfg
fi

docker run -d \
 --name mediacenter_couchpotato \
 -h localhost \
 -v $dockerStorageFolder/couchpotato/config:/config \
 -v $downloadsFolder/movies:/transmission/download-movies \
 -p 5050:5050 \
 --restart=always \
 couchpotato




