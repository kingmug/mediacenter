#!/bin/bash
echo "MOVING"
for pattern in "${!series[@]}"
do
        echo ${series[$pattern]}

#        location="/data/downloads/series/${series[$pattern]}"
	#mkdir "${location}"
#
	#cd "/data/downloads/series"
#        find ./ -maxdepth 1 -iname "${pattern}" -exec mv "{}" "${location}" \;
#        find ./ -maxdepth 2 -iname "${pattern}" -exec mv "{}" "${location}" \;
#
	#cd "/data/downloads/unordered"
#        find ./ -maxdepth 1 -iname "${pattern}" -exec mv "{}" "${location}" \;
#        find ./ -maxdepth 2 -iname "${pattern}" -exec mv "{}" "${location}" \;
done
# rmdir *
