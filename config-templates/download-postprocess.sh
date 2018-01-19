#!/bin/sh
while read searchStr folderName
do
    location="/downloads/series/${folderName}"
	mkdir "${location}"

	cd "/downloads/series"
        find ./ -maxdepth 1 -iname "${searchStr}" -exec mv "{}" "${location}" \;
        find ./ -maxdepth 2 -iname "${searchStr}" -exec mv "{}" "${location}" \;

	cd "/downloads/unordered"
        find ./ -maxdepth 1 -iname "${searchStr}" -exec mv "{}" "${location}" \;
        find ./ -maxdepth 2 -iname "${searchStr}" -exec mv "{}" "${location}" \;
done < /config/postprocess/series.csv

rmdir /downloads/unordered/*

echo "Finished!"
