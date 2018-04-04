# appoptics-agent-docker

Docker and Kubernetes assets for running AppOptics

## About

This repo contains a Docker image for running the AppOptics agent.

This can be used to monitor Kubernetes clusters with the two Kubernetes assets in this repo:
- [Deployment](appoptics-agent-deployment.yaml) - A single pod to talk to the Kubernetes API to send Kubernetes specific metrics to AppOptics.
- [DaemonSet](appoptics-agent-daemonset.yaml) - A DaemonSet that runs a pod on every node in your cluster and publishes HostAgent and Docker metrics to AppOptics.

Or you can use this in sidecar fashion to run the other [AppOptics Integrations](https://docs.appoptics.com/kb/host_infrastructure/integrations/).

## Installation

### Deployment

If you're using RBAC on your Kubernetes cluster you'll need to deploy the Service Account first so that the agent can talk to your Kubernetes API:
```	
kubectl apply -f appoptics-agent-serviceaccount.yaml	
```

To deploy the Deployment to Kubernetes, update the `APPOPTICS_TOKEN` environment variable in `appoptics-agent-deployment.yaml` and run:
```
kubectl apply -f appoptics-agent-deployment.yaml
```

Enable the Kubernetes plugin in the AppOptics UI and you should start seeing data trickle in.

### DaemonSet

To deploy the DaemonSet to Kubernetes, update the `APPOPTICS_TOKEN` environment variable in `appoptics-agent-daemonset.yaml` and run:
```
kubectl apply -f appoptics-agent-daemonset.yaml
```

Enable the Docker plugin in the AppOptics UI and you should start seeing data trickle in.

### Sidecar

If you wanted to run this on Kubernetes as a sidecar for monitoring specific services, you can follow the instructions below which use Zookeeper as an example.

Add a second container to your deployment YAML underneath `spec.template.spec.containers` and the agent should now have access to your service over `localhost`:
```
- name: zookeeper-ao-sidecar
  image: 'appoptics/appoptics-agent-docker:v0.1'
  env:
    - name: APPOPTICS_TOKEN
      value: APPOPTICS_TOKEN
    - name: APPOPTICS_ENABLE_ZOOKEEPER
      value: 'true'
    - name: APPOPTICS_DISABLE_HOSTAGENT
      value: 'true'
```

## Configuration

### Environment Parameters

The following environment parameters are available:

 Parameter                   | Description
-----------------------------|---------------------
 APPOPTICS_TOKEN             | Your AppOptics token. This parameter is required.
 LOG_LEVEL                   | Expected value: DEBUG, INFO, WARN, ERROR or FATAL. Default value is WARN.
 APPOPTICS_HOSTNAME          | This value overrides the hostname tagged for default host metrics. The DaemonSet uses this to override with Node name.
 APPOPTICS_ENABLE_DOCKER     | Set this to `true` to enable the Docker plugin.
 APPOPTICS_ENABLE_KUBERNETES | Set this to `true` to enable the Kubernetes plugin.
 APPOPTICS_DISABLE_HOSTAGENT | Set this to `true` to disable the Host Agent system metrics collection.
 APPOPTICS_ENABLE_ZOOKEEPER  | Set this to `true` to enable the Zookeeper plugin.

## Development

The included Kubernetes resources rely on a Docker image from [Docker Hub](https://hub.docker.com/r/appoptics/appoptics-agent-docker), see the [Dockerfile](Dockerfile) for more details. You can build and push this by running:
```
docker build -t appoptics/appoptics-agent-docker:v0.1 .
docker push appoptics/appoptics-agent-docker:v0.1
```
