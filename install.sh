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

if [ -z "${variables['TARGET_DIR']}" ]; then
    echo ""
    echo "ERROR: You should configure it first. See file config/globals.conf"
    echo ""
    exit
fi

sudo rm -rf $TARGET_DIR/couchpotato
sudo rm -rf $TARGET_DIR/sickrage/
sudo rm -rf $TARGET_DIR/transmission

rm -rf config/generated
mkdir config/generated
cp -r config-templates/* config/generated

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



sudo add-apt-repository ppa:team-xbmc/ppa

sudo apt-get update
sudo apt-get install linux-image-generic curl

# Get the latest Docker package
curl -sSL https://get.docker.com/ | sh

# Create the docker group and add your user.
sudo usermod -aG docker "${user}"



docker rm -f `docker ps --no-trunc -aq`

sudo rm -rf $TARGET_DIR
mkdir $TARGET_DIR



# Install File manager
#docker build -t cron cron
crontab /home/arthur/git-repos/mediacenter/cron/crontab




#### Install transmission
cd $REPO_DIR
git clone https://github.com/dgholz/docker-transmission.git
cd docker-transmission
docker build -t transmission .
rm -rf $REPO_DIR/docker-transmission

# Override config
mkdir -p $TARGET_DIR/transmission/config/
sudo cp $REPO_DIR/config/generated/transmission.json $TARGET_DIR/transmission/config/settings.json







#### Install Sickbeard
cd $REPO_DIR
git clone http://github.com/timhaak/docker-sickrage.git
cd docker-sickrage
docker build -t sickrage .
rm -rf $REPO_DIR/docker-sickrage

# Override config
mkdir -p $TARGET_DIR/sickrage/config/
sudo cp $REPO_DIR/config/generated/sickbeard.ini $TARGET_DIR/sickrage/config/config.ini






#### Install couchpotato
cd $REPO_DIR
git clone https://github.com/timhaak/docker-couchpotato.git
cd docker-couchpotato
docker build -t couchpotato .
rm -rf $REPO_DIR/docker-couchpotato

# Override config
mkdir -p $TARGET_DIR/couchpotato/config/
sudo cp $REPO_DIR/config/generated/couchpotato.cfg $TARGET_DIR/couchpotato/config/CouchPotato.cfg


cd $TARGET_DIR/
rm data
rm storage
ln -s "$STORAGE_FOLDER/" storage
ln -s storage data


#### Install KODI

# Install XBMC
sudo apt-get install xbmc
cp $REPO_DIR/config/kodi.desktop $home/.config/autostart/
