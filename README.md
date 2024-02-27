# Easy-Elastic

This is an absolutely minimal docker-compose setup for elasticsearch and kibana.
It cuts all corners on reliability and many on security in order to allow you to just
get started and play around with it as quickly as possible.

## Why?

Elasticsearch and Kibana are amazingly helpful for analyzing large amounts of logs and
metrics. However, there is a common belief that they are hard to set up and operate
them. I agree with the common wisdom that a highly available "production" setup should
have at least three nodes for redundancy - that is probably true for any production 
database. But many resources out there seem to suggest that with elastic, you can't or
shouldn't even get started with less than three nodes - which is simply not true.

Regarding setup: there are some aspects of elastic's auto-setup and
configuration which make it non-trivial to create a `docker compose up`-experience. 
This is what this project is trying to solve:

Specify passwords, run `docker compose up`, wait a few seconds, enjoy!

Regarding performance: I have analyzed anything from a few megabytes to hundreds of 
gigabytes worth of logs on single node setups.

## Disclaimer

**Do not** use this setup to persist anything remotely important!
If you ingest logfiles, keep the originals. If you collect metrics with metricbeat, be
aware that you might easily lose them!

**Do not** expose the started services over the network. The compose project sets two
port forwards, so you can access elastic and kibana. They are bound to localhost, so
they are not accessible from the outside. If you are running this on a remote machine,
use ssh port-forwards.

**Be responsible** and do not put sensitive data into databases that are not thoroughly
secured.

There are absolutely **no warranties** on either elastic's - or my behalf.

## Howto

Copy `./docker/.env.example` to `./docker/.env` and fill in passwords.

Run:

```sh
cd docker

# Creates directories and changes some file ownerships
# It will complain about a missing sudo password, if you want to ingest container-logs
# or metrics, run (again) with sudo / as root
./prepare-docker.sh

docker compose up
```

There will be a lot of output. After about a minute kibana should be accessible 
at http://localhost:5601 and elastic's API at http://localhost:9200.

## Going further

The project also provides pre-configured beats in separate yml files. You can either 
copy the services over to `docker-compose.yml` or include them using the `-f` flag for
`docker compose`.  
E.g.: `docker compose -f docker-compose.yml -f container-logs.yml -f ... up`

### logfiles.yml

Collects log files from `$LOG_DIR` - ideally .jsonl files (ndjson format). You might 
need to adjust the config file: `./docker/config/filebeat-experiments.yml` to use a 
different glob.

### metricbeat.yml

Collects system metrics from the linux host. The config file 
`./docker/config/metricbeat.yml` needs to be owned by root.

### container-logs.yml

Collects the logs of docker containers running on the same host. The config file
`./docker/config/filebeat-container.yml` needs to be owned by root. You need to set the
docker logging driver to `json-file` in `/etc/docker/daemon.json` and restart `dockerd`.

```json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
```

## FAQ

### What is the `set-kibana-password` service?

This service simply starts with your stack and sets the `kibana_system` password to the
value of the `KIBANA_PASSWORD` environment variable. The elasticsearch docker image
unfortunately has no built-in mechanism to set a password for `kibana_system`. The
intended solution for this is copying the enrollment token from the logs when elastic
starts for the first time and giving that to kibana. This is at odds with the intended
`docker compose up` experience of this project, especially since the logs
elastic produces are rather verbose.

### Why is TLS on transport and http disabled?

I am a huge fan of security-in-depth, I actually spent quite some time trying to figure
out how I could enable elastic's automatic TLS setup for this setup. But the way it is
implemented seems fundamentally at odds with providing your own configuration in
`elasticsearch.yml`. The short explanation is that if you mount `elasticsearch.yml`
into the container with configuration values that will allow for the automatic TLS
setup, elasticsearch will try to move this file - presumably to create a backup before
adding some values - which doesn't work with a mounted file. Just mounting a dir with
the prepared `elasticsearch.yml` in it also doesn't work, because then we are hiding
other required files which are part of the container image.

The only reasonable way I see to set up TLS without breaking the `docker compose up`
-experience would be another initialization service, similar to `set-kibana-password`,
but that added isn't worth it, since you are not supposed to expose this setup in the
first place. If you want to extend this setup for your own porpuses, I suggest you read
here:  
https://www.elastic.co/guide/en/elasticsearch/reference/current/security-basic-setup.html

### Why are my indices marked as unhealthy?

The minimum number of replicas for an index defaults to two. Since this is a single 
node setup, that level of replication cannot be achieved. There is unfortunately
no global setting to change this, you must set it for every index, or on the
index-template. That is why the below snippet is included in all the included
beats-configurations files.

```yaml
template:
  # ...
  settings.index:
    number_of_replicas: 0
```
