# solarwinds-snap-agent-docker

Docker and Kubernetes assets for running SolarWinds Snap Agent

## Table of contents

  * [About](#about)
  * [Installation](#installation)
    * [Deployment](#deployment)
    * [DaemonSet](daemonset)
    * [Sidecar](#sidecar)
  * [Configuration](#configuration)
    * [Custom plugins configuration and tasks manifests](#custom-plugins-configuration-and-tasks-manifests)
    * [Environment Parameters](#environment-parameters)
  * [Integrating Kubernetes Cluster Events Collection With Loggly](#integrating-kubernetes-cluster-events-collection-with-loggly)
  * [Dashboard](#dashboard)
  * [Development](#development)

## About

Use the containerized SolarWinds Snap Agent to monitor Docker or Kubernetes environments. Monitor Kubernetes cluster and application health. Aggregate metrics across clusters distributed across multiple data centers and cloud providers. Track pods, deployments, services and more with Kubernetes-integrated service discovery.

Kubernetes assets:
- [Deployment](deploy/base/deployment/swisnap-agent-deployment.yaml) - A single pod to talk to the Kubernetes API to send Kubernetes specific metrics to AppOptics.
- [DaemonSet](deploy/base/daemonset/swisnap-agent-daemonset.yaml) - A DaemonSet that runs a pod on every node in your cluster and publishes HostAgent and Docker metrics to AppOptics.

A typical cluster will utilize both the Deployment and DaemonSet assets.

Alternatively, you can deploy the containerized agent in a sidecar to run the other [AppOptics Integrations](https://docs.appoptics.com/kb/host_infrastructure/integrations/) and monitor your Kubernetes applications running in the same Pod.

## Installation

Kubernetes assests available in this repository expect a `solarwinds-token` secret to exist. To create this secret run:
``` bash
kubectl create secret generic solarwinds-token -n kube-system --from-literal=SOLARWINDS_TOKEN=<REPLACE WITH TOKEN>
```

### Deployment

By default, RBAC is enabled in the deploy manifests. If you are not using RBAC you can deploy [swisnap-agent-deployment.yaml](deploy/base/deployment/swisnap-agent-deployment.yaml) removing the reference to the Service Account.

In the `configMapGenerator` section of [kustomization.yaml](deploy/base/deployment/kustomization.yaml)>, you can configure which plugins should be run by setting `SWISNAP_ENABLE_<plugin_name>` to either `true` or `false`. Plugins turned on via environment variables are using default configuration and taskfiles. To see list of plugins currently supported this way please refer to: [Environment Parameters](#environment-parameters). 

After configuring deployment to your needs (please refer to [Configuration](#configuration) and ensuring that `solarwinds-token` secret was already created run:

``` bash
kubectl apply -k ./deploy/overlays/stable/deployment
```

Finally, check if the deployment is running properly:
``` bash
kubectl get deployment swisnap-agent-k8s -n kube-system
```

Enable the Kubernetes plugin in the AppOptics UI and you should start seeing data trickle in.

### DaemonSet

The DaemonSet, by default, will give you insight into [containers](https://docs.appoptics.com/kb/host_infrastructure/#list-and-map-view) running within its nodes and gather system, processes and docker-related metrics. To deploy the DaemonSet to Kubernetes verify you have an `solarwinds-token` secret already created and run:
``` bash
kubectl apply -k ./deploy/overlays/stable/daemonset
```

Enable the Docker plugin in the AppOptics UI and you should start seeing data trickle in.

### Sidecar

#### Docker

If you wanted to run containerized SolarWinds Snap Agent with custom taskfiles, you can use following snippets:

```shell
docker run -d -e SOLARWINDS_TOKEN=token \
           -v my_custom_statsd.yaml:/opt/SolarWinds/Snap/etc/plugins.d/statsd.yaml \
           --name swisnap-agent
           solarwinds/solarwinds-snap-agent-docker:3.3.0-3.1.1.717
```

or using docker-compose:

```yaml
version: '3'
services:
  swisnap:
    image: solarwinds/solarwinds-snap-agent-docker:3.3.0-3.1.1.717
    hostname: swisnap-agent
    container_name: swisnap-agent
    volumes:
      - /path/to/my_custom_statsd.yaml:/opt/SolarWinds/Snap/etc/plugins.d/statsd.yaml
    environment:
      - SOLARWINDS_TOKEN=token
```

#### Kubernetes

If you wanted to run this on Kubernetes as a sidecar for monitoring specific services, you can follow the instructions below, which use Apache Server as an example. In this setup, the agent will monitor only services running in particular pod(s), not Kubernetes itself.

- Useful when you want to monitor only specific per-pod-services
- Configuration is similar to pod setup
- In order to monitor specific services only, the `kubernetes` and `aosystem` plugins should be disabled by setting `SWISNAP_ENABLE_KUBERNETES` to `false` and `SWISNAP_DISABLE_HOSTAGENT` to `true` in `swisnap-agent-deployment.yaml`

In order to monitor Apache with the agent in a sidecar, add a second container to your deployment YAML underneath `spec.template.spec.containers` and the agent should now have access to your service over `localhost` (notice `SWISNAP_ENABLE_APACHE`):

Note: Containers inside the same pod can communicate through localhost, so there's no need to pass a static IP - [Resource sharing and communication](https://kubernetes.io/docs/concepts/workloads/pods/pod/#resource-sharing-and-communication)

``` yaml
        containers:
        - name: apache
            imagePullPolicy: Always
            image: '<your-image>'
            ports:
            - containerPort: 80
        - name: swisnap-agent-ds
            image: 'solarwinds/solarwinds-snap-agent-docker:1.0.0'
            imagePullPolicy: Always
            env:
            - name: SOLARWINDS_TOKEN
                value: 'SOLARWINDS_TOKEN'
            - name: APPOPTICS_HOSTNAME
                valueFrom:
                fieldRef:
                    fieldPath: spec.nodeName
            - name: SWISNAP_ENABLE_DOCKER
                value: 'false'
            - name: SWISNAP_ENABLE_APACHE
                value: 'true'
            - name: SWISNAP_DISABLE_HOSTAGENT
                value: 'true'
            - name: HOST_PROC
                value: '/host/proc'
```

In the example above, the sidecar will run only the Apache plugin. Additionally, if the default [Apache Plugin](https://docs.appoptics.com/kb//host_infrastructure/integrations/apache/) configuration is not sufficient, custom one should be passed to pod running SolarWinds Snap Agent - [Configuration](#configuration).

## Configuration

### Custom plugins configuration and tasks manifests

SolarWinds Snap Agent image is using default plugins configuration files and tasks manifests. In order to use your own configuration you would have to create [Kubernetes configMap](https://kubernetes.io/docs/concepts/storage/volumes/#configmap). In this example we'll set up two configMaps, one for SolarWinds Snap Agent Kubernetes plugin config and second one for corresponding task.

``` bash
# create plugin configMap
kubectl create configmap kubernetes-plugin-config --from-file=/path/to/my/plugins.d/kubernetes.yaml --namespace=kube-system

# create task configMap
kubectl create configmap kubernetes-task-manifest --from-file=/path/to/my/tasks.d/task-aokubernetes.yaml --namespace=kube-system

# check if everything is fine
kubectl describe configmaps --namespace=kube-system kubernetes-task-manifest kubernetes-plugin-config
```

ConfigMaps should be attached to SolarWinds Snap Agent deployment. Here's the example, notice `spec.template.spec.containers.volumeMounts` and `spec.template.spec.volumes`:

``` diff
diff --git a/deploy/base/deployment/kustomization.yaml b/deploy/base/deployment/kustomization.yaml
index 79e0110..000a108 100644
--- a/deploy/base/deployment/kustomization.yaml
+++ b/deploy/base/deployment/kustomization.yaml
@@ -15,7 +15,7 @@ configMapGenerator:
       - SWISNAP_ENABLE_APACHE=false
       - SWISNAP_ENABLE_DOCKER=false
       - SWISNAP_ENABLE_ELASTICSEARCH=false
-      - SWISNAP_ENABLE_KUBERNETES=true
+      - SWISNAP_ENABLE_KUBERNETES=false
       - SWISNAP_ENABLE_PROMETHEUS=false
       - SWISNAP_ENABLE_MESOS=false
       - SWISNAP_ENABLE_MONGODB=false
diff --git a/deploy/base/deployment/swisnap-agent-deployment.yaml b/deploy/base/deployment/swisnap-agent-deployment.yaml
index 294c4b4..babff7d 100644
--- a/deploy/base/deployment/swisnap-agent-deployment.yaml
+++ b/deploy/base/deployment/swisnap-agent-deployment.yaml
@@ -45,6 +45,12 @@ spec:
             - configMapRef:
                 name: swisnap-k8s-configmap
           volumeMounts:
+            - name: kubernetes-plugin-vol
+              mountPath: /opt/SolarWinds/Snap/etc/plugins.d/kubernetes.yaml
+              subPath: kubernetes.yaml
+            - name: kubernetes-task-vol
+              mountPath: /opt/SolarWinds/Snap/etc/tasks.d/task-aokubernetes.yaml
+              subPath: task-aokubernetes.yaml
             - name: proc
               mountPath: /host/proc
               readOnly: true
@@ -56,6 +62,18 @@ spec:
               cpu: 100m
               memory: 256Mi
       volumes:
+        - name: kubernetes-plugin-vol
+          configMap:
+            name: kubernetes-plugin-config
+            items:
+              - key: kubernetes.yaml
+                path: kubernetes.yaml
+        - name: kubernetes-task-vol
+          configMap:
+            name: kubernetes-task-manifest
+            items:
+              - key: task-aokubernetes.yaml
+                path: task-aokubernetes.yaml
         - name: proc
           hostPath:
             path: /proc
```
Notice that we're not utilizing [Environment Parameters](#environment-parameters) to turn on Kubernetes plugin. When you're attaching taskfiles and plugin configuration files through configMaps, there's no need to set environment variables `SWISNAP_ENABLE_<plugin-name>`. SolarWinds Snap Agent will automatically load plugins based on files stored in configMaps.

### Environment Parameters

The following environment parameters are available:

 Parameter                      | Description
--------------------------------|---------------------
 APPOPTICS_CUSTOM_TAGS          | Set this to a comma separated K=V list to enable custom tags eg. `NAME=TEST,IS_PRODUCTION=false,VERSION=5`
 SOLARWINDS_TOKEN               | Your SolarWinds token. This parameter is required.
 APPOPTICS_TOKEN                | Depreciated. Your SolarWinds token. This parameter is used as fallback if SOLARWINDS_TOKEN is not present.
 APPOPTICS_HOSTNAME             | This value overrides the hostname tagged for default host metrics. The DaemonSet uses this to override with Node name.
 LOG_LEVEL                      | Expected value: DEBUG, INFO, WARN, ERROR or FATAL. Default value is WARN.
 LOG_PATH                       | Set this value to enable SolarWinds Snap Agent logging to file. Default logs are printed to stdout for SolarWinds Snap Agent running in Docker container. Overriding this option disable reading Snap Agent log using `docker logs`, or `kubectl logs`.
 SWISNAP_SECURE                 | Set this to `true` to run only signed plugins.
 SWISNAP_DISABLE_HOSTAGENT      | Set this to `true` to disable the SolarWinds Snap Agent system metrics collection.
 SWISNAP_DISABLE_PROCESSES      | Set this to `true` to disable the SolarWinds Snap Agent processes metrics collection.
 SWISNAP_ENABLE_DOCKER          | Set this to `true` to enable the Docker plugin.
 SWISNAP_ENABLE_APACHE          | Set this to `true` to enable the Apache plugin.
 SWISNAP_ENABLE_ELASTICSEARCH   | Set this to `true` to enable the Elasticsearch plugin.
 SWISNAP_ENABLE_KUBERNETES      | Set this to `true` to enable the Kubernetes plugin. Enabling this option on the DaemonSet will cause replication of Kubernetes metrics where the replication count is the number of pods with Kubernetes collection enabled minus one. Typically Kubernetes collection is only enabled on the Deployment asset.
 SWISNAP_ENABLE_MESOS           | Set this to `true` to enable the Mesos plugin.
 SWISNAP_ENABLE_MONGODB         | Set this to `true` to enable the MongoDB plugin.
 SWISNAP_ENABLE_MYSQL           | Set this to `true` to enable the MySQL plugin. If enabled the following ENV vars are required to be set as well: MYSQL_USER, MYSQL_PASS, MYSQL_HOST & MYSQL_PORT
 SWISNAP_ENABLE_PROMETHEUS      | Set this to `true` to enable prometheus pod annotation scrapping
 SWISNAP_ENABLE_RABBITMQ        | Set this to `true` to enable the RabbitMQ plugin.
 SWISNAP_ENABLE_STATSD          | Set this to `true` to enable the Statsd plugin.
 SWISNAP_ENABLE_ZOOKEEPER       | Set this to `true` to enable the Zookeeper plugin.

If you use `SWISNAP_ENABLE_<plugin_name>` set to `true`, then keep in mind that SolarWinds Snap Agent will use default plugins configs and task manifests. For custom configuration see [Custom plugins configuration and tasks manifests](#custom-plugins-configuration-and-tasks-manifests).

## Integrating Kubernetes Cluster Events Collection With Loggly

Version 22 of Kubernetes collector allows you to collect cluster events and push them to Loggly using logs collector under the hood. To enable event collection in your deployment, follow below steps:
* Create `kubernetes.yaml` file that will configure kubernetes collector. This config should contain `collector.kubernetes.all.events` field with specified filter. Following example config will watch for `normal` events in `default` namespace:
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
* Create Kubernetes secret for `SOLARWINDS_TOKEN`:
  ```shell
  kubectl create secret generic solarwinds-token -n kube-system --from-literal=SOLARWINDS_TOKEN=<REPLACE WITH TOKEN>
  ```
* Create Events Collector Deployment (it will automatically create corresponding ServiceAccount):
  ```shell
  kubectl apply -k ./deploy/overlays/stable/events-collector/
  ```
* Watch your cluster events in Loggly


## Dashboard
Successful deployments will report metrics in the AppOptics Kubernetes Dashboard.
<img src="kubernetes-appoptics-dashboard.png" width="400px" align="middle">

## Development

The included Kubernetes resources rely on a Docker image from [Docker Hub](https://hub.docker.com/r/solarwinds/solarwinds-snap-agent-docker), see the [Dockerfile](Dockerfile) for more details. You can build and push this by updating the tag in the [Makefile](Makefile) and running:
```
make build-and-release-docker
```
After new custom Docker image is succesfuly released to Docker Hub, please remember to update corresponding entry in stable overlay for used [Kubernetes objects](deploy/base/).
