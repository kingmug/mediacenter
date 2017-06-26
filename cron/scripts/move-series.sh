#!/bin/bash
declare -A series
series["*Marvel*Agents*"]="Marvel's Agents of S.H.I.E.L.D"
series["*Homeland*"]="Homeland"
series["*Big*Bang*Theory*"]="The Big Bang Theory"
series["*House*Cards*"]="House of Cards (US)"
series["*Suits*"]="Suits"
series["*Arrow*"]="Arrow"
series["*Broke*Girls*"]="Two Broke Girls"
series["*Californication*"]="Californication"
series["*Black*Mirror*"]="Black Mirror"
series["*The*Americans*"]="The Americans (2013)"
series["*Tyrant*"]="Tyrant"
series["*Under*Dome*"]="Under the Dome"
series["*Black*Sails*"]="Black Sails"
series["*Breakout*Kings*"]="Breakout Kings"
#series["**"]=

for pattern in "${!series[@]}"
do
        location="/home/arthur/Downloads/storage/series/${series[$pattern]}"
	mkdir "${location}"

	cd "/home/arthur/Downloads/storage/series"
        find ./ -maxdepth 1 -iname "${pattern}" -exec mv "{}" "${location}" \;
        find ./ -maxdepth 2 -iname "${pattern}" -exec mv "{}" "${location}" \;

	cd "/home/arthur/Downloads/storage/unordered"
        find ./ -maxdepth 1 -iname "${pattern}" -exec mv "{}" "${location}" \;
        find ./ -maxdepth 2 -iname "${pattern}" -exec mv "{}" "${location}" \;
done
rmdir /home/arthur/Downloads/storage/unordered/*

echo "Finished!"
