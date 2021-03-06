REPO_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $REPO_DIR

echo "enabled=0" | sudo tee /etc/default/apport > /dev/null

source $REPO_DIR/config/globals.conf

if [ -z "$NETWORK_INTERFACE" ]; then
    export NETWORK_INTERFACE="eth0"
fi

if [ -z "${IP_ADDRESS}" ]; then
  IP_ADDRESS=$(ifconfig $NETWORK_INTERFACE | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
  if [ -z "${IP_ADDRESS}" ]; then
    echo "ERROR: Could not find an IP address. You can either connect yourself to the internet on network interface $NETWORK_INTERFACE. You can also change the network interface in config/globals.con using NETWORK_INTERFACE and try again. Or you can set the ip address manually using config variable IP_ADDRESS in config/globals.conf"
    exit
  fi
fi

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
mkdir "$STORAGE_ROOT_FOLDER"
ln -s "$STORAGE_ROOT_FOLDER" storage

# Create docker folder
cd $storageFolder
dockerStorageFolder=$storageFolder/.mediacenter-docker-files
if [ ! -d $storageFolder/.mediacenter-docker-files ]; then 
  mkdir $storageFolder/.mediacenter-docker-files
fi



declare -A variables
variables['couchpotato.movies']="/data"
variables['couchpotato.password']="$USER"
variables['IP_ADDRESS']="$IP_ADDRESS"
variables['kodi.storageFolder']=$storageFolder
variables['startmediacenter.home']=$HOME

rm -rf $REPO_DIR/config/generated
mkdir $REPO_DIR/config/generated
cp -r $REPO_DIR/config-templates/* $REPO_DIR/config/generated

cd $REPO_DIR
for i in $REPO_DIR/config/generated/*; do
#    echo "Processing config file $i"
    cp ${i} tmp
    for j in ${!variables[@]}; do
        result="sed -e 's|\$\${${j}}|${variables[$j]}|g' tmp > tmp2"
#        echo "Replacing var $j: $result"
        eval $result

        mv tmp2 tmp
    done
    mv tmp "$i"
done

grep "\$\${" $REPO_DIR/config/generated/*
if [ "$?" -eq 0 ]; then
  echo "There are unresolved variables in the config files (see above lines). Exiting." 
  exit
fi


mkdir -p $HOME/.config/autostart
cp $REPO_DIR/config/kodi.desktop $HOME/.config/autostart/
cp $REPO_DIR/config/generated/start-mediacenter.desktop $HOME/.config/autostart/


if ! [ -x "$(command -v kodi)" ]; then
  echo "Package kodi (xbmc) is not installed. Installing now"
  sudo add-apt-repository -y ppa:team-xbmc/ppa >&2
  sudo apt-get update
  sudo apt-get install xbmc >&2
fi


# Generate the kodi configuration
if [ ! -d $HOME/.kodi/userdata ]; then 
  mkdir -p $HOME/.kodi/userdata
fi
if [ ! -f $HOME/.kodi/userdata/sources.xml ]; then 
  cp $REPO_DIR/config/generated/kodi-sources.xml $HOME/.kodi/userdata/sources.xml
fi
if [ ! -f $HOME/.kodi/guisettings.xml ]; then 
  cp $REPO_DIR/config/generated/kodi-guisettings.xml $HOME/.kodi/userdata/guisettings.xml
fi





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
fi
echo $USER
sudo usermod -aG docker "${USER}"

sudo service docker start

# Setup the post process script
mkdir -p $dockerStorageFolder/transmission/config/postprocess/
cp $REPO_DIR/config/generated/download-postprocess.sh $dockerStorageFolder/transmission/config/postprocess/download-postprocess.sh
cp $REPO_DIR/config/series.csv $dockerStorageFolder/transmission/config/postprocess/series.csv





# Delete all docker containers
docker stop $(docker ps -a -q)
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
 -v $downloadsFolder/series:/downloads/series \
 -v $downloadsFolder/movies:/downloads/movies \
 -v $downloadsFolder/unordered:/downloads/unordered \
 -v $downloadsFolder/downloading:/incomplete \
 -v $downloadsFolder/torrents:/watch \
 -v $dockerStorageFolder/transmission/config:/config \
 -p 9091:9091 \
 -p 51413:51413 \
 -p 51413:51413/udp \
 --restart=always \
 timhaak/transmission

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
 -v $downloadsFolder/series:/data \
 -p 8081:8081 \
 --restart=always \
 timhaak/sickrage









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
 -v $dockerStorageFolder/couchpotato/data:/data \
 -v $downloadsFolder/movies:/movies \
 -p 5050:5050 \
 --restart=always \
 timhaak/couchpotato




