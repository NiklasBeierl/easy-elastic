#!/usr/bin/env sh

for x in elastic-data kibana-data;
do
  DIR_PATH=./volumes/$x;
  echo "Ensuring $DIR_PATH"
  mkdir -p $DIR_PATH
done

echo "Some elastic config files must be owned by root."
for x in metricbeat.yml filebeat-container.yml;
do
  FILE=./config/$x
  echo $FILE
  sudo -n chown root: $FILE
done

if ! [ -e .env ]; then
  echo "Make sure to create a .env file by copying .env.example and filling in any missing values!"
fi

echo "done"
