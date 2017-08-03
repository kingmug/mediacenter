#!/bin/bash

baseFolder="/home/arthur/Dropbox-prive/install-server/scripts"
shazamDir="/home/arthur/Dropbox/shazam-tags"
targetFolder="/home/arthur/Downloads/internal/music"

for f in $shazamDir/*
do
	if [ -d "$f" ]; then
		continue
	fi
	echo "Process file $f"
	# Read Shazam string from file
	line=$(head -n 1 "$f")

	# Parse the song name
	l=`expr match "$line" 'I just used Shazam to discover .*.\. http://'`
	l=${line:31:$l-40}
	l="${l/ by / }"

	echo "Searching for '$l'"

	# Download the torrent
	url=$(python $baseFolder/downloadMp3.py "$l")
	rand=$RANDOM
	if echo "$url" | grep -q "magnet:?";
	then
		echo "Torrent '$l' found!"
		echo "Torrent '$l' found!" >> $baseFolder/log.txt
	        transmission-remote -n"admin:arthurislief" -w"$targetFolder" --add "$url"

        	# Move the file
	       	mv "$f" $shazamDir/processed/song-$rand.txt
	else
                echo "Torrent '$l' could not be found"
                echo "Torrent '$l' could not be found" >> $baseFolder/log.txt
                mv "$f" $shazamDir/processed/song-unfound-$rand.txt

	fi
	echo "Done"
done
