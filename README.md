# solarwinds-snap-agent-docker

Docker and Kubernetes assets for running SolarWinds Snap Agent

## Table of contents

  * [About](#about)
  * [Installation](#installation)
    * [Deployment](#deployment)
    * [DaemonSet](#daemonset)
    * [Sidecar](#sidecar)
  * [Configuration](#configuration)
    * [Enabling Docker Logs collector from Kubernetes nodes](#enabling-docker-logs-collector-from-kubernetes-nodes)
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

* (Optional) If you wish to use Logs Collector/Forwarder functionality from SolarWinds Snap Agent and your token for Loggly or Papertrail is different than your SolarWinds token, please create new Kubernetes secrets, depending on a needs. 
If these tokens are the same, there is no need to perform this step - in that case `SOLARWINDS_TOKEN`, will be used by Loggly and Papertrail Publisher plugins.
``` bash
# setting for loggly-http, loggly-http-bulk, loggly-syslog Logs Publishers
kubectl create secret generic loggly-token -n kube-system --from-literal=LOGGLY_TOKEN=<REPLACE WITH LOGGLY TOKEN>

# setting for swi-logs-http-bulk, swi-logs-http Logs Publishers 
kubectl create secret generic papertrail-token -n kube-system --from-literal=PAPERTRAIL_TOKEN=<REPLACE WITH PAPERTRAIL TOKEN>

# setting for papertrail-syslog publisher
kubectl create secret generic papertrail-publisher-settings -n kube-system --from-literal=PAPERTRAIL_HOST=<REPLACE WITH PAPERTRAIL HOST> --from-literal=PAPERTRAIL_PORT=<REPLACE WITH PAPERTRAIL PORT>
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
           --name swisnap-agent \
           solarwinds/solarwinds-snap-agent-docker:latest
```

or using docker-compose:

```yaml
version: '3'
services:
  swisnap:
    image: solarwinds/solarwinds-snap-agent-docker:latest
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
            image: 'solarwinds/solarwinds-snap-agent-docker:latest'
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

### Enabling Docker Logs collector from Kubernetes nodes

In this configuration SolarWinds Snap Agent DaemonSet will gather Docker logs from underlying node and publish them to Loggly (in addition to gathering HostAgent and Docker metrics to AppOptics). In current setting it will gather all logs from container named "nginx"
This option is disabled by default, it has to be turned on to start working. 


* Create `solarwinds-token` secret in your cluster. To create it run:

  ``` bash
  kubectl create secret generic solarwinds-token -n kube-system --from-literal=SOLARWINDS_TOKEN=<REPLACE WITH TOKEN>
  ```

* (Optional step) If your token for Loggly is different than your SolarWinds token, please create new Kubernetes secret. If the tokens are the same, there is no need to perform this step - in that case `SOLARWINDS_TOKEN`, will be used by Loggly Publisher plugin.

  ``` bash
  kubectl create secret generic loggly-token -n kube-system --from-literal=LOGGLY_TOKEN=<REPLACE WITH LOGGLY TOKEN>
  ```

* Set `SWISNAP_ENABLE_DOCKER_LOGS` to `true` and `SWISNAP_DOCKER_LOGS_CONTAINER_NAMES` to desired container names in stable overlay for [DaemonSet kustomization.yaml](deploy/overlays/stable/daemonset/kustomization.yaml).
  ```diff
  --- a/deploy/overlays/stable/daemonset/kustomization.yaml
  +++ b/deploy/overlays/stable/daemonset/kustomization.yaml
  @@ -10,7 +10,7 @@ configMapGenerator:
     - name: swisnap-host-configmap
       behavior: merge
       literals:
  -      - SWISNAP_ENABLE_DOCKER_LOGS=false
  +      - SWISNAP_ENABLE_DOCKER_LOGS=true
  +      - SWISNAP_DOCKER_LOGS_CONTAINER_NAMES="nginx apache"
   
   images:
     - name: solarwinds/solarwinds-snap-agent-docker
  ```

* Create DaemonSet in your cluster.

  ``` bash
  kubectl apply -k ./deploy/overlays/stable/daemonset
  ```

* After a while you should start seeing Docker logs lines in your Loggly organization.

If you would like to use different Loggly endpoint, or use Papertrail enpoints, there will be a need to setup up custom task configuration, as described in [Custom plugins configuration and tasks manifests](#custom-plugins-configuration-and-tasks-manifests)

### Custom plugins configuration and tasks manifests

SolarWinds Snap Agent image is using default plugins configuration files and tasks manifests. In order to use your own configuration you would have to create [Kubernetes configMap](https://kubernetes.io/docs/concepts/storage/volumes/#configmap). Depending on version of the plugin there will be a need to create either task manifest and plugin config (Plugins v1), or task configuration in case of Plugins v2. 

#### Plugins v1
In this example we'll set up two configMaps, one for SolarWinds Snap Agent Kubernetes plugin config and second one for corresponding task.
  ``` bash
  # create plugin configMap and task manifest for Plugin v1
  kubectl create configmap kubernetes-plugin-config --from-file=/path/to/my/plugins.d/kubernetes.yaml --namespace=kube-system
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


#### Plugins v2

In this example we'll set up one configMaps, for SolarWinds Snap Agent Kubernetes Logs Collector/Forwarder task configuration.
  ``` bash
  # create task configuration configMap  for Plugin v2
  kubectl create configmap logs-task-config --from-file=/path/to/my/task-autoload.d/task-logs-k8s-events.yaml --namespace=kube-system
  ```

ConfigMaps should be attached to SolarWinds Snap Agent deployment. Here's the example, notice `spec.template.spec.containers.volumeMounts` and `spec.template.spec.volumes`:
  ```diff
  diff --git a/deploy/base/deployment/swisnap-agent-deployment.yaml b/deploy/base/deployment/swisnap-agent-deployment.yaml
  index 294c4b4..babff7d 100644
  --- a/deploy/base/deployment/swisnap-agent-deployment.yaml
  +++ b/deploy/base/deployment/swisnap-agent-deployment.yaml
  @@ -45,6 +45,12 @@ spec:
               - configMapRef:
                   name: swisnap-k8s-configmap
             volumeMounts:
  +            - name: logs-task-vol
  +              mountPath: /opt/SolarWinds/Snap/etc/tasks-autoload.d/task-logs-k8s-events.yaml
  +              subPath: task-logs-k8s-events.yaml
               - name: proc
                 mountPath: /host/proc
                 readOnly: true
  @@ -56,6 +62,18 @@ spec:
                 cpu: 100m
                 memory: 256Mi
         volumes:
  +        - name: logs-task-vol
  +          configMap:
  +            name: logs-task-config 
  +            items:
  +              - key: task-logs-k8s-events.yaml
  +                path: task-logs-k8s-events.yaml
           - name: proc
             hostPath:
               path: /proc
  ```
Notice that we're not utilizing [Environment Parameters](#environment-parameters) to turn on Logs plugin. When you're attaching task configuration files through configMaps, there's no need to set environment variables `SWISNAP_ENABLE_<plugin-name>`. SolarWinds Snap Agent will automatically load tasks based on files stored in configMaps and mounted to `/opt/SolarWinds/Snap/etc/tasks-autoload.d/` in container.

### Environment Parameters

The following environment parameters are available:

 Parameter                      | Description
--------------------------------|---------------------
 APPOPTICS_CUSTOM_TAGS          | Set this to a comma separated K=V list to enable custom tags eg. `NAME=TEST,IS_PRODUCTION=false,VERSION=5`
 SOLARWINDS_TOKEN               | Your SolarWinds token. This parameter is required.
 APPOPTICS_TOKEN                | Depreciated. Your SolarWinds token. This parameter is used as fallback if SOLARWINDS_TOKEN is not present.
 LOGGLY_TOKEN                   | Optional. Use this when your Loggly token differs from Your SolarWinds token. If set, this will be used for tasks using Loggly Publishers (loggly-syslog, loggly-http-bulk, loggly-http).
 PAPERTRAIL_TOKEN               | Optional. Use this when your Papertrail token differs from Your SolarWinds token. If set, this will be used for tasks using Papertrail Publishers (swi-logs-http, swi-logs-http-bulk).
 PAPERTAIL_HOST                 | Optional. Use this when you intend to use `papertrail-syslog` publisher. Change this to your Papertrail host.
 PAPERTRAIL_PORT                | Optional. Use this when you intend to use `papertrail-syslog` publisher. Change this to your Papertrail port.
 APPOPTICS_HOSTNAME             | This value overrides the hostname tagged for default host metrics. The DaemonSet uses this to override with Node name.
 LOG_LEVEL                      | Expected value: DEBUG, INFO, WARN, ERROR or FATAL. Default value is WARN.
 LOG_PATH                       | Set this value to enable SolarWinds Snap Agent logging to file. Default logs are printed to stdout for SolarWinds Snap Agent running in Docker container. Overriding this option disable reading Snap Agent log using `docker logs`, or `kubectl logs`.
 SWISNAP_SECURE                 | Set this to `true` to run only signed plugins. Turned on by default for Kubernetes assets.
 SWISNAP_DISABLE_HOSTAGENT      | Set this to `true` to disable the SolarWinds Snap Agent system metrics collection.
 SWISNAP_DISABLE_PROCESSES      | Set this to `true` to disable the SolarWinds Snap Agent processes metrics collection.
 SWISNAP_ENABLE_DOCKER          | Set this to `true` to enable the Docker plugin. This requires Docker socket mounted inside container (done by default in DaemonSet).
 SWISNAP_ENABLE_DOCKER_LOGS     | Set this to true to enable Logs collector task for gathering Docker logs. If set to true, setting `SWISNAP_DOCKER_LOGS_CONTAINER_NAMES` var is mandatory. This also requires Docker socket mounted inside container (done by default in DaemonSet).
 SWISNAP_DOCKER_LOGS_CONTAINER_NAMES | Space separated list of container names, for which log colelctor/forwarder should be set.
 SWISNAP_ENABLE_APACHE          | Set this to `true` to enable the Apache plugin.
 SWISNAP_ENABLE_ELASTICSEARCH   | Set this to `true` to enable the Elasticsearch plugin.
 SWISNAP_ENABLE_KUBERNETES      | Set this to `true` to enable the Kubernetes plugin. Enabling this option on the DaemonSet will cause replication of Kubernetes metrics where the replication count is the number of pods with Kubernetes collection enabled minus one. Typically Kubernetes collection is only enabled on the Deployment asset.
 SWISNAP_ENABLE_KUBERNETES_LOGS | Set this to `true` to enable the default Kubernetes logs collector/forwarder. To enable this proper RBAC role have to be set (done for Deployment form this repo).
 SWISNAP_ENABLE_NGINX           | Set this to `true` to enable the Nginx plugin. If enabled the following ENV vars are required to be set:<br>*NGINX_STATUS_URI* - one, or multiple space-separeted link(s) to Nginx stub_status URI.
 SWISNAP_ENABLE_NGINX_PLUS      | Set this to `true` to enable the Nginx Plus plugin. If enabled the following ENV vars are required to be set:<br>*NGINX_PLUS_STATUS_URI* - one, or multiple space-separeted link(s) to ngx_http_status_module or status URI.
 SWISNAP_ENABLE_NGINX_PLUS_API  | Set this to `true` to enable the Nginx Plus Api plugin. If enabled the following ENV vars are required to be set:<br>*NGINX_PLUS_STATUS_URI* - one, or multiple space-separeted link(s) to Nginx API URI.
 SWISNAP_ENABLE_MESOS           | Set this to `true` to enable the Mesos plugin.
 SWISNAP_ENABLE_MONGODB         | Set this to `true` to enable the MongoDB plugin.
 SWISNAP_ENABLE_MYSQL           | Set this to `true` to enable the MySQL plugin. If enabled the following ENV vars are required to be set:<br>*MYSQL_USER*,<br>*MYSQL_PASS*,<br>*MYSQL_HOST*<br>*MYSQL_PORT*
 SWISNAP_ENABLE_PROMETHEUS      | Set this to `true` to enable the Prometheus pod annotation scrapping
 SWISNAP_ENABLE_POSTGRESQL      | Set this to `true` to enable the Postgres plugin.  If enabled the following ENV vars are required to be set:<br>*POSTGRES_ADDRESS* - specify address for Postgres databse
 SWISNAP_ENABLE_RABBITMQ        | Set this to `true` to enable the RabbitMQ plugin.
 SWISNAP_ENABLE_REDIS           | Set this to `true` to enable the Redis plugin. If enabled the following ENV vars are required to be set:<br>*REDIS_SERVERS* - one, or multiple space-separeted link(s) to Redis servers
 SWISNAP_ENABLE_SOCKET_LISTENER | Set this to `true` to enable the Socket Listener plugin. If enabled the following ENV vars are required to be set:<br>*SOCKET_SERVICE_ADDRESS* - URL to listen on,<br>*SOCKET_LISTENER_FORMAT* - Data format to consume: "collectd", "graphite", "influx", "json", or "value".
 SWISNAP_ENABLE_STATSD          | Set this to `true` to enable the Statsd plugin.
 SWISNAP_ENABLE_ZOOKEEPER       | Set this to `true` to enable the Zookeeper plugin.

If you use `SWISNAP_ENABLE_<plugin_name>` set to `true`, then keep in mind that SolarWinds Snap Agent will use default plugins configs and task manifests. For custom configuration see [Custom plugins configuration and tasks manifests](#custom-plugins-configuration-and-tasks-manifests).

## Integrating Kubernetes Cluster Events Collection With Loggly
This documentaton can be also found in [Documentation for SolarWinds](https://documentation.solarwinds.com/en/Success_Center/appoptics/Content/kb/host_infrastructure/host_agent/kubernetes_ha.htm#integrating-kubernetes-cluster-events-collection-with-loggly) webpage.

Starting from SolarWinds Snap Agent release 4.1.0 allows you to collect cluster events and push them to Loggly using embedded logs collector under the hood. There are two different ways to enable this functionality - one with enabling default forwarder for Snap Deployment, in which there will be monitored normal events in default namespace [Instructions](#enabling-default-kuberentes-log-forwarder). The second option is more advanced and require create corresponding configmaps in your cluster, with proper task configuration. This way allows you to manually edit this configuration, with option to modify both desired event filters, monitored Kubernetes namespace and to select desired publisher [Instruction](#advanced-configuration-for-Kuberetes-log-forwarder-with-custom-task-configuration).

### Enabling default Kuberetes log forwarder

* Create Kubernetes secret for `SOLARWINDS_TOKEN`:

  ```shell
  kubectl create secret generic solarwinds-token -n kube-system --from-literal=SOLARWINDS_TOKEN=<REPLACE WITH TOKEN>
  ```
* (Optional step) If your token for Loggly is different than your SolarWinds token, please create new Kubernetes secret. If the tokens are the same, there is no need to perform this step - in that case `SOLARWINDS_TOKEN`, will be used by Loggly Publisher plugin.

  ``` bash
  kubectl create secret generic loggly-token -n kube-system --from-literal=LOGGLY_TOKEN=<REPLACE WITH LOGGLY TOKEN>
  ```

* Edit kustomisation.yaml for Snap Agent Deployment
FIXME

* Create Snap Agent Deployment (it will automatically create corresponding ServiceAccount):

  ```shell
  kubectl apply -k ./deploy/overlays/stable/events-collector/
  ```

* Watch your cluster events in Loggly.

### Advanced configuration for Kuberetes log forwarder with custom task configuration

To utilize this functionality there is a need to create corresponding configmaps in your cluster, with proper task configuration. The example config file can be found in [Event collector configs](examples/event-collector-configs). To enable event collection in your deployment, follow below steps:

* Create Kubernetes secret for `SOLARWINDS_TOKEN`:

  ```shell
  kubectl create secret generic solarwinds-token -n kube-system --from-literal=SOLARWINDS_TOKEN=<REPLACE WITH TOKEN>
  ```

* (Optional) If you wish to use Logs Collector/Forwarder functionality from SolarWinds Snap Agent and your token for Loggly or Papertrail is different than your SolarWinds token, please create new Kubernetes secrets, depending on a needs. 
Note: If these tokens are the same, there is no need to perform this step - in that case `SOLARWINDS_TOKEN`, will be used by Loggly and Papertrail Publisher plugins.

  ``` bash
  # setting for loggly-http, loggly-http-bulk, loggly-syslog Logs Publishers
  kubectl create secret generic loggly-token -n kube-system --from-literal=LOGGLY_TOKEN=<REPLACE WITH LOGGLY TOKEN>

  # setting for swi-logs-http-bulk, swi-logs-http Logs Publishers 
  kubectl create secret generic papertrail-token -n kube-system --from-literal=PAPERTRAIL_TOKEN=<REPLACE WITH PAPERTRAIL TOKEN>

  # setting for papertrail-syslog publisher
  kubectl create secret generic papertrail-publisher-settings -n kube-system --from-literal=PAPERTRAIL_HOST=<REPLACE WITH PAPERTRAIL HOST> --from-literal=PAPERTRAIL_PORT=<REPLACE WITH PAPERTRAIL PORT>
  ```

* [task-logs-k8s-events.yaml](examples/event-collector-configs/task-logs-k8s-events.yaml) file configures the Kubernetes Events Log task. This config contains `plugins.config.filters` field with specified filter. With this example filter event collector will watch for `normal` events in `default` namespace. Depending on your needs, you can modify this filter to monitor other event types, or other namespaces.

  ```yaml
  version: 2

  schedule:
    type: streaming

  plugins:
    - plugin_name: k8s-events
      config:
        incluster: true

        filters:
        - namespace: default
          watch_only: true
          options:
            fieldSelector: "type==Normal"
        #- namespace: kube-system
        #  watch_only: true
        #  options:
        #    fieldSelector: "type==Warning"

      #tags:
      #  /k8s-events/[namespace=my_namespace]/string_line:
      #    sometag: somevalue

      publish:
        - plugin_name: loggly-http-bulk # this could be set to any other Logs Publisher
  ```

* Once Kubernetes Events Log task configuration is in desired state, create corresponding configmaps:

  ```shell
  kubectl create configmap task-autoload --from-file=./examples/event-collector-configs/task-logs-k8s-events.yaml --namespace=kube-system
  
  kubectl describe configmaps -n kube-system task-autoload
  ```

* Create Events Collector Deployment (it will automatically create corresponding ServiceAccount):

  ```shell
  kubectl apply -k ./deploy/overlays/stable/events-collector/
  ```

* Watch your cluster events in Loggly, or Papertrail.


## Dashboard
Successful deployments will report metrics in the AppOptics Kubernetes Dashboard.
<img src="kubernetes-appoptics-dashboard.png" width="400px" align="middle">

## Development

The included Kubernetes resources rely on a Docker image from [Docker Hub](https://hub.docker.com/r/solarwinds/solarwinds-snap-agent-docker), see the [Dockerfile](Dockerfile) for more details. You can build and push this by updating the tag in the [Makefile](Makefile) and running:
```
make build-and-release-docker
```
After new custom Docker image is succesfuly released to Docker Hub, please remember to update corresponding entry in stable overlay for used [Kubernetes objects](deploy/base/).
