Simple docker container metrics.
====

This is shell script for monitoring docker container metrics, and put metrics data to aws cloudwatch.


## Usage

Start metrics. (default: 5 sec interval, for all containers)

```
$ sh mon-docker-cloudwatch.sh
```

- You need execute permission for put-metrics-data in cloudwatch.

- You need to run it on your EC2 instance (use EC2 instance ID).


## Options

You can set options as environment variables.

- `FILTER` : Set container name patterns by comma separated. (default: no pattern)

- `INTERVAL` : Set monitoring interval as seconds. (default: 5 sec)


## Dimentions and Metrics

- Dimentions
  - InstanceId
  - ContainerName

- Metrics
  - ContainerCPUUtilization (%)
  - ContainerCPUUser (Bytes)
  - ContainerCPUSystem (Bytes)
  - ContainerMemoryUtilization (%)
  - ContainerMemoryUsed
  - ContainerMemoryAvairable

The calculation method is the same as the stats command of docker cli.


## Requirements

- awscli
- docker
- curl
- jq
- ec2-utils


// EOF

