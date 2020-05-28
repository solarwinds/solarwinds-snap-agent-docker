# solarwinds-snap-agent-docker

Docker and Kubernetes assets for running SolarWinds Snap Agent

## About

Use the containerized SolarWinds Snap Agent to monitor Docker or Kubernetes environments. Monitor Kubernetes cluster and application health. Aggregate metrics across clusters distributed across multiple data centers and cloud providers. Track pods, deployments, services and more with Kubernetes-integrated service discovery.

Kubernetes assets:
- [Deployment](deploy/base/deployment/swisnap-agent-deployment.yaml) - A single pod to talk to the Kubernetes API to send Kubernetes specific metrics to AppOptics.
- [DaemonSet](deploy/base/daemonset/swisnap-agent-daemonset.yaml) - A DaemonSet that runs a pod on every node in your cluster and publishes HostAgent and Docker metrics to AppOptics.

A typical cluster will utilize both the Deployment and DaemonSet assets.

Alternatively, you can deploy the containerized agent in a sidecar to run the other [AppOptics Integrations](https://docs.appoptics.com/kb/host_infrastructure/integrations/) and monitor your Kubernetes applications running in the same Pod.

## Installation

All deployments expect an appoptics-token secret to exist.  You can create this secret via
```
kubectl create secret generic appoptics-token -n kube-system --from-literal=APPOPTICS_TOKEN=<REPLACE WITH TOKEN>
```


### Deployment

By default, RBAC is enabled in the deploy manifests.  If you are not using RBAC you can deploy [swisnap-agent-daemonset.yaml](deploy/base/daemonset/swisnap-agent-daemonset.yaml) removing the reference to the Service Account.


To deploy the Deployment to Kubernetes verify you have an appoptics-token secret already created and run:
``` bash
kustomize build ./deploy/overlays/stable/deployment | kubectl apply -f-
```

Enable the Kubernetes plugin in the AppOptics UI and you should start seeing data trickle in.

### DaemonSet

The DaemonSet, by default, will give you insight into [containers](https://docs.appoptics.com/kb/host_infrastructure/#list-and-map-view) running within its node and gather system, processes and docker-related metrics. To deploy the DaemonSet to Kubernetes verify you have an appoptics-token secret already created and run:
``` bash
kustomize build ./deploy/overlays/stable/daemonset | kubectl apply -f-
```

Enable the Docker plugin in the AppOptics UI and you should start seeing data trickle in.

### Sidecar

#### Docker

If you wanted to run containerized SolarWinds Snap Agent with custom taskfiles, you can use following snippets:

```shell
docker run -d -e APPOPTICS_TOKEN=token \
           -v my_custom_statsd.yaml:/opt/SolarWinds/Snap/etc/plugins.d/statsd.yaml \
           --name swisnap-agent
           solarwinds/solarwinds-snap-agent-docker:1.1.0
```

or using docker-compose:

```yaml
version: '3'
services:
  swisnap:
    image: solarwinds/solarwinds-snap-agent-docker:1.1.0
    hostname: swisnap-agent
    container_name: swisnap-agent
    volumes:
      - /path/to/my_custom_statsd.yaml:/opt/SolarWinds/Snap/etc/plugins.d/statsd.yaml
    environment:
      - APPOPTICS_TOKEN=token
```

#### Kubernetes

If you wanted to run this on Kubernetes as a sidecar for monitoring specific services, you can follow the instructions below which use Zookeeper as an example.

Add a second container to your deployment YAML underneath `spec.template.spec.containers` and the agent should now have access to your service over `localhost`:
``` yaml
- name: zookeeper-ao-sidecar
  image: 'solarwinds/solarwinds-snap-agent-docker:x.x.x'
  env:
    - name: APPOPTICS_TOKEN
      value: APPOPTICS_TOKEN
    - name: SWISNAP_ENABLE_ZOOKEEPER
      value: 'true'
    - name: SWISNAP_DISABLE_HOSTAGENT
      value: 'true'
```

## Configuration

### Custom plugins configuration and tasks manifests

Host Agent image is using default plugins configuration files and tasks manifests. In order to use your own configuration you would have to create [Kubernetes configMap](https://kubernetes.io/docs/concepts/storage/volumes/#configmap). In this example we'll set up two configMaps, one for plugins and second for tasks.

``` bash
# create plugins configMap
kubectl create configmap plugin-configs --from-file=/path/to/my/plugins.d/ --namespace=kube-system

# create tasks configMap
kubectl create configmap task-manifests --from-file=/path/to/my/tasks.d/ --namespace=kube-system

# check if everything is fine
kubectl describe configmaps plugin-configs task-manifests
```

Now we are ready to inject these configMaps to either daemonset or deployment. Let's do this on `swisnap-agent-deployment.yaml`:

``` diff
22a23,27
>           volumeMounts:
>             - name: plugins-vol
>               mountPath: /opt/SolarWinds/Snap/etc/plugins.d
>             - name: tasks-vol
>               mountPath: /opt/SolarWinds/Snap/etc/tasks.d
32,33c37,38
<             - name: SWISNAP_ENABLE_KUBERNETES
<               value: 'true'
---
>             - name: SWISNAP_ENABLE_KUBERNETES # turn off default plugin configuration
>               value: 'false'
52a58,70
>       volumes:
>         - name: plugins-vol
>           configMap:
>             name: plugin-configs
>             items:
>               - key: kubernetes.yaml
>                 path: kubernetes.yaml
>         - name: tasks-vol
>           configMap:
>             name: task-manifests
>             items:
>               - key: task-aokubernetes.yaml
>                 path: task-aokubernetes.yaml
58d75
```
Notice that we're not utilizing [Environment Parameters](###environment-parameters) to turn on Kubernetes plugin. After editing deployment manifest it's time to create it - follow the steps in [Installation](##installation).

### Environment Parameters

The following environment parameters are available:

 Parameter                      | Description
--------------------------------|---------------------
 APPOPTICS_CUSTOM_TAGS          | Set this to a comma separated K=V list to enable custom tags eg. `NAME=TEST,IS_PRODUCTION=false,VERSION=5`
 APPOPTICS_TOKEN                | Your AppOptics token. This parameter is required.
 APPOPTICS_HOSTNAME             | This value overrides the hostname tagged for default host metrics. The DaemonSet uses this to override with Node name.
 LOG_LEVEL                      | Expected value: DEBUG, INFO, WARN, ERROR or FATAL. Default value is WARN.
 SWISNAP_SECURE                 | Set this to `true` to run only signed plugins
 SWISNAP_DISABLE_HOSTAGENT      | Set this to `true` to disable the Host Agent system metrics collection.
 SWISNAP_DISABLE_PROCESSES      | Set this to `true` to disable the Host Agent processes metrics collection.
 SWISNAP_ENABLE_DOCKER          | Set this to `true` to enable the Docker plugin.
 SWISNAP_ENABLE_APACHE          | Set this to `true` to enable the Apache plugin.
 SWISNAP_ENABLE_ELASTICSEARCH   | Set this to `true` to enable the Elasticsearch plugin.
 SWISNAP_ENABLE_KUBERNETES      | Set this to `true` to enable the Kubernetes plugin. Enabling this option on the DaemonSet will cause  replication of Kubernetes metrics where the replication count is the number of pods with Kubernetes collection enabled minus one.  Typically Kubernetes collection is only enabled on the Deployment asset.
 SWISNAP_ENABLE_MESOS           | Set this to `true` to enable the Mesos plugin.
 SWISNAP_ENABLE_MONGODB         | Set this to `true` to enable the MongoDB plugin.
 SWISNAP_ENABLE_RABBITMQ        | Set this to `true` to enable the RabbitMQ plugin.
 SWISNAP_ENABLE_STATSD          | Set this to `true` to enable the Statsd plugin.
 SWISNAP_ENABLE_ZOOKEEPER       | Set this to `true` to enable the Zookeeper plugin.
 SWISNAP_ENABLE_MYSQL           | Set this to `true` to enable the MySQL plugin. If enabled the following ENV vars are required to be set as well: MYSQL_USER, MYSQL_PASS, MYSQL_HOST & MYSQL_PORT

If you use `SWISNAP_ENABLE_<plugin_name>` set to `true`, then keep in mind that AppOptics Host Agent will use default plugins configs and task manifests. For custom configuration see [Custom plugins configuration and tasks manifests](###custom-plugins-configuration-and-tasks-manifests).

## Events collector

Version 22 of Kubernetes collector allows you to collect cluster events and push them to Loggly using logs collector under the hood. To enable event collection in your deployment, follow these easy steps:
* Create `kubernetes.yaml` file that will configure kubernetes collector. This config should contain `collector.kubernetes.all.events` field with specified filter. Following example config will watch for normal events in default namespace:
  ```yaml
  collector:
    kubernetes:
      all:
        incluster: true
        kubeconfigpath: ""
        interval: "60s"

        events: |
          # Embedded YAML (as a multiline string literal)
          filters:
          - namespace: default
            type: normal

        grpc_timeout: 30

  load:
    plugin: snap-plugin-collector-aokubernetes
    task: task-aokubernetes.yaml
  ```
* If you want to monitor events count in AppOptics, then edit your current `task-aokubernetes.yaml` task manifest so it contains `/kubernetes/events/count` metric in `workflow.collect.metrics` list, and copy it to working directory:
  ```yaml
  ---
  version: 1

  schedule:
    type: streaming

  deadline: "55s"

  workflow:
    collect:

      config:
        /kubernetes:
          MaxCollectDuration: "2s"
          MaxMetricsBuffer: 250

      metrics:
        /kubernetes/events/count: {}
        /kubernetes/pod/*/*/*/status/phase/Running: {}
      publish:
      - plugin_name: publisher-appoptics
        config:
          period: 60
          floor_seconds: 60
  ```
* Create `logs.yaml` file configuring the logs collector. Make sure that logs collector looks for `/var/log/SolarWinds/Snap/events.log` file:
  ```yaml
  collector:
    logs:
      all:
        loggly_token: <your loggly token>
        api_host: "logs-01.loggly.com"

        api_port: 514
        api_protocol: "tcp"

        connect_timeout: "30s"

        write_timeout: "30s"

        files: |
          /var/log/SolarWinds/Snap/events.log

        exclude_patterns: |
          .*self-skip-logs-collector.*

  load:
    plugin: snap-plugin-collector-logs
    task: task-logs.yaml
  ```
* Copy your current `task-logs.yaml` task manifest to working directory.
* Once all 4 files are ready (`kubernetes.yaml`, `logs.yaml`, `task-aokubernetes.yaml` and `task-logs.yaml`), create 2 configmaps:
  ```shell
  kubectl create configmap plugin-configs --from-file=./logs.yaml --from-file=./kubernetes.yaml --namespace=kube-system
  kubectl create configmap task-manifests --from-file=./task-logs.yaml --from-file=./task-aokubernetes.yaml --namespace=kube-system

  kubectl describe configmaps -n kube-system plugin-configs task-manifests
  ```
* Edit `configmaps/appoptics-token.yaml` and insert your `APPOPTICS_TOKEN`.
* Create ServiceAccount and Deployment:
  ```shell
  kubectl apply -f swisnap-agent-serviceaccount.yaml
  kubectl create -f configmaps/appoptics-token.yaml -f configmaps/deployment.yaml
  kubectl apply -f swisnap-agent-deployment.yaml
  ```
* Watch your cluster events in Loggly :)


## Dashboard
Successful deployments will report metrics in the AppOptics Kubernetes Dashboard.
<img src="kubernetes-appoptics-dashboard.png" width="400px" align="middle">

## Development

The included Kubernetes resources rely on a Docker image from [Docker Hub](https://hub.docker.com/r/solarwinds/solarwinds-snap-agent-docker), see the [Dockerfile](Dockerfile) for more details. You can build and push this by updating the tag in the [Makefile](Makefile) and running:
```
make build-and-release-docker
```
