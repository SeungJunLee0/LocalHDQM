#!/bin/bash

mkdir -p /tmp/$USER/hdqm
cd /tmp/$USER/hdqm/
git clone https://github.com/SeungJunLee0/CentralHDQM.git
cd CentralHDQM/

# Get an SSO to access OMS and RR APIs. This has to be done before cmsenv script
# First check if we are the owner of the folder where we'll be puting the cookie
if [ $(ls -ld /tmp/$USER/hdqm/CentralHDQM/backend/api/etc | awk '{ print $3 }') == $USER ]; then 
    cern-get-sso-cookie -u https://cmsoms.cern.ch/agg/api/v1/runs -o backend/api/etc/oms_sso_cookie.txt
    cern-get-sso-cookie -u https://cmsrunregistry.web.cern.ch/api/runs_filtered_ordered -o backend/api/etc/rr_sso_cookie.txt
fi

cd backend/
# This will give us a CMSSW environment
source cmsenv

# Add python dependencies
python3 -m pip install -r requirements.txt -t .python_packages/python3
python -m pip install -r requirements.txt -t .python_packages/python2
#python -m pip install certifi
#python -m pip install urllib3[secure]
export PYTHONPATH="${PYTHONPATH}:$(pwd)/.python_packages/python2"

cd extractor/

# Extract few DQM histograms. Using only one process because we are on SQLite

./hdqmextract.py -c cfg/GEM/trendPlotsGEM_all.ini -r 337971 337972 337973 -j 1 
./calculate.py -c cfg/GEM/trendPlotsGEM_all.ini -r 337971 337972 337973 -j 1
# Calculate HDQM values from DQM histograms stored in the DB

# Get the OMS and RR data about the runs
./oms_extractor.py 
./rr_extractor.py 

cd ../api/
# Run the API
./run.sh &>/dev/null & > run.txt

cd ../../frontend/
# Use local API instead of the production one
sed -i 's/\/api/http:\/\/localhost:8080\/api/g' js/config.js 
# Run the static file server
python3 -m http.server 8000 &>/dev/null &

echo "http://localhost:8000/"
ps awwx | grep python
