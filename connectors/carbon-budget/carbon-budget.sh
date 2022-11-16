#!/bin/sh

# 2022

cite2022="Global Carbon Project. (2022). Supplemental data of Global Carbon Budget 2022 (Version 1.0) [Data set]. Global Carbon Project. https://doi.org/10.18160/gcp-2022"
link2022="https://www.icos-cp.eu/science-and-impact/global-carbon-budget/2022"
node fossil-emissions-by-fuel-type-2021.js --file Global_Carbon_Budget_2022v1.0_Emissions-by-type.csv --key emissions-by-fuel-type-2022 --source=$cite2022 --link=$link2022
node national-carbon-emissions-2021.js --file National_Carbon_Emissions_2022v1.0_Territorial.csv --key emissions-by-region-2022 --countries "World,Africa,Asia,Central America,Europe,Middle East,North America,South America,Oceania,Bunkers"  --source=$cite2022 --link=$link2022

# 2021

node fossil-emissions-by-fuel-type-2021.js --file Global_Carbon_Budget_2021v1.0_Emissions-by-type.csv --key emissions-by-fuel-type
node national-carbon-emissions-2021.js --file National_Carbon_Emissions_2021v1.0_Territorial.csv --key "emissions-by-region" --countries "World,Africa,Asia,Central America,Europe,Middle East,North America,South America,Oceania,Bunkers"
