# appoptics-agent-docker

Docker and Kubernetes assets for running AppOptics

## About

Use the containerized AppOptics agent to monitor Docker or Kubernetes environments. Monitor Kubernetes cluster and application health. Aggregate metrics across clusters distributed across multiple data centers and cloud providers. Track pods, deployments, services and more with Kubernetes-integrated service discovery.

Kubernetes assets:
- [Deployment](appoptics-agent-deployment.yaml) - A single pod to talk to the Kubernetes API to send Kubernetes specific metrics to AppOptics.
- [DaemonSet](appoptics-agent-daemonset.yaml) - A DaemonSet that runs a pod on every node in your cluster and publishes HostAgent and Docker metrics to AppOptics.

A typical cluster will utilize both the Deployment and DaemonSet assets.

Alternatively, you can deploy the containerized agent in a sidecar to run the other [AppOptics Integrations](https://docs.appoptics.com/kb/host_infrastructure/integrations/) and monitor your Kubernetes applications running in the same Pod.

## Installation

### Deployment

If you're using RBAC on your Kubernetes cluster you'll need to deploy the Service Account first so that the agent can talk to your Kubernetes API:
``` bash
kubectl apply -f appoptics-agent-serviceaccount.yaml
```

To deploy the Deployment to Kubernetes, update the `APPOPTICS_TOKEN` environment variable in `appoptics-agent-deployment.yaml` and run:
``` bash
kubectl apply -f appoptics-agent-deployment.yaml
```

Enable the Kubernetes plugin in the AppOptics UI and you should start seeing data trickle in.

### DaemonSet

To deploy the DaemonSet to Kubernetes, update the `APPOPTICS_TOKEN` environment variable in `appoptics-agent-daemonset.yaml` and run:
``` bash
kubectl apply -f appoptics-agent-daemonset.yaml
```

Enable the Docker plugin in the AppOptics UI and you should start seeing data trickle in.

### Sidecar

If you wanted to run this on Kubernetes as a sidecar for monitoring specific services, you can follow the instructions below which use Zookeeper as an example.

Add a second container to your deployment YAML underneath `spec.template.spec.containers` and the agent should now have access to your service over `localhost`:
``` yaml
- name: zookeeper-ao-sidecar
  image: 'appoptics/appoptics-agent-docker:v0.x'
  env:
    - name: APPOPTICS_TOKEN
      value: APPOPTICS_TOKEN
    - name: APPOPTICS_ENABLE_ZOOKEEPER
      value: 'true'
    - name: APPOPTICS_DISABLE_HOSTAGENT
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

Now we are ready to inject these configMaps to either daemonset or deployment. Let's do this on `appoptics-agent-deployment.yaml`:

``` diff
22a23,27
>           volumeMounts:
>             - name: plugins-vol
>               mountPath: /opt/appoptics/etc/plugins.d
>             - name: tasks-vol
>               mountPath: /opt/appoptics/etc/tasks.d
32,33c37,38
<             - name: APPOPTICS_ENABLE_KUBERNETES
<               value: 'true'
---
>             - name: APPOPTICS_ENABLE_KUBERNETES # turn off default plugin configuration
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
 APPOPTICS_TOKEN                | Your AppOptics token. This parameter is required.
 LOG_LEVEL                      | Expected value: DEBUG, INFO, WARN, ERROR or FATAL. Default value is WARN.
 APPOPTICS_HOSTNAME             | This value overrides the hostname tagged for default host metrics. The DaemonSet uses this to override with Node name.
 APPOPTICS_ENABLE_DOCKER        | Set this to `true` to enable the Docker plugin.
 APPOPTICS_ENABLE_APACHE        | Set this to `true` to enable the Apache plugin.
 APPOPTICS_ENABLE_ELASTICSEARCH | Set this to `true` to enable the Elasticsearch plugin.
 APPOPTICS_ENABLE_KUBERNETES    | Set this to `true` to enable the Kubernetes plugin. Enabling this option on the DaemonSet will cause  replication of Kubernetes metrics where the replication count is the number of pods with Kubernetes collection enabled minus one.  Typically Kubernetes collection is only enabled on the Deployment asset.
 APPOPTICS_ENABLE_MESOS         | Set this to `true` to enable the Mesos plugin.
 APPOPTICS_ENABLE_MONGODB       | Set this to `true` to enable the MongoDB plugin.
 APPOPTICS_ENABLE_RABBITMQ      | Set this to `true` to enable the RabbitMQ plugin.
 APPOPTICS_DISABLE_HOSTAGENT    | Set this to `true` to disable the Host Agent system metrics collection.
 APPOPTICS_ENABLE_ZOOKEEPER     | Set this to `true` to enable the Zookeeper plugin.
 APPOPTICS_ENABLE_MYSQL         | Set this to `true` to enable the MySQL plugin. If enabled the following ENV vars are required to be set as well: MYSQL_USER, MYSQL_PASS, MYSQL_HOST & MYSQL_PORT
 APPOPTICS_CUSTOM_TAGS          | Set this to a comma separated K=V list to enable custom tags eg. `NAME=TEST,IS_PRODUCTION=false,VERSION=5`

If you use `APPOPTICS_ENABLE_<plugin_name>` set to `true`, then keep in mind that AppOptics Host Agent will use default plugins configs and task manifests. For custom configuration see [Custom plugins configuration and tasks manifests](###custom-plugins-configuration-and-tasks-manifests).

## Dashboard
Successful deployments will report metrics in the AppOptics Kubernetes Dashboard.
<img src="kubernetes-appoptics-dashboard.png" width="400px" align="middle">

## Development

The included Kubernetes resources rely on a Docker image from [Docker Hub](https://hub.docker.com/r/appoptics/appoptics-agent-docker), see the [Dockerfile](Dockerfile) for more details. You can build and push this by updating the tag in the [Makefile](Makefile) and running:
```
make build-and-release-docker
```
