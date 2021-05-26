#!/bin/sh

node fossil-emissions-by-fuel-type-2020.js --file Global_Carbon_Budget_2020v1.0_Emissions-by-type.csv --key emissions-by-fuel-type

node national-carbon-emissions.js --file National_Carbon_Emissions_2019_Territorial.csv --key "emissions-by-region" --countries "EU28,Africa,Asia,Central America,Europe,Middle East,North America,South America,Oceania,Bunkers"
