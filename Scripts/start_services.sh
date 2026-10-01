#!/bin/bash

cd /home/free5gc1/free5gc || exit 1

sudo systemctl start mongod
sleep 2

./bin/nrf -c config/nrfcfg.yaml 2>&1 | tee ~/nrf-current.log &
sleep 2

./bin/udr -c config/udrcfg.yaml 2>&1 | tee ~/udr-current.log &
sleep 2

./bin/udm -c config/udmcfg.yaml 2>&1 | tee ~/udm-current.log &
sleep 2

./bin/ausf -c config/ausfcfg.yaml 2>&1 | tee ~/ausf-current.log &
sleep 2

./bin/nssf -c config/nssfcfg.yaml 2>&1 | tee ~/nssf-current.log &
sleep 2

./bin/pcf -c config/pcfcfg.yaml 2>&1 | tee ~/pcf-current.log &
sleep 2

./bin/amf -c config/amfcfg.yaml 2>&1 | tee ~/amf-current.log &
sleep 2

sudo ip netns exec upf1ns ./bin/upf \
    -c config/multiUPF/upfcfg01.yaml \
    2>&1 | tee ~/upf1-current.log &
sleep 2

sudo ip netns exec upf2ns ./bin/upf \
    -c config/multiUPF/upfcfg02.yaml \
    2>&1 | tee ~/upf2-current.log &
sleep 2

./bin/smf \
    -c config/multiUPF/smfcfg.ulcl.yaml \
    -u config/multiUPF/uerouting.yaml \
    2>&1 | tee ~/smf-n9-current.log &

echo "free5GC services started"
wait
