#!/bin/sh
while read searchStr folderName
do
        location="/transmission/download-series/${folderName}"
	mkdir "${location}"

	cd "/transmission/download-series"
        find ./ -maxdepth 1 -iname "${searchStr}" -exec mv "{}" "${location}" \;
        find ./ -maxdepth 2 -iname "${searchStr}" -exec mv "{}" "${location}" \;

	cd "/transmission/download"
        find ./ -maxdepth 1 -iname "${searchStr}" -exec mv "{}" "${location}" \;
        find ./ -maxdepth 2 -iname "${searchStr}" -exec mv "{}" "${location}" \;
done < /transmission/config/postprocess/series.csv

rmdir /transmission/download/*

echo "Finished!"
