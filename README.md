# kube-ao

Kubernetes assets for running AppOptics

## About

This repo contains two Kubernetes assets:
- Deployment - A single pod to run on a master node and talk to the Kubernetes API to send Kubernetes specific metrics to AppOptics.
- DaemonSet - A DaemonSet that runs a pod on every node in your cluster and publishes HostAgent and Docker metrics to AppOptics.

## Installation

### Deployment

The Deployment asset contains a Service Account that is needed by the AppOptics agent to talk to your Kubernetes API.

To deploy the Service Account and Deployment to Kubernetes, update the `APPOPTICS_TOKEN` environment variable in `kube-ao-deployment.yaml` and run:
```
kubectl apply -f kube-ao-deployment.yaml
```

Enable the Kubernetes plugin in the AppOptics UI and you should start seeing data trickle in.

### DaemonSet

To deploy the DaemonSet to Kubernetes, update the `APPOPTICS_TOKEN` environment variable in `kube-ao-daemonset.yaml` and run:
```
kubectl apply -f kube-ao-daemonset.yaml
```

Enable the Docker plugin in the AppOptics UI and you should start seeing data trickle in.

### Notes

By default, these assets deploy to the `kube-system` namespace.

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

## Development

The included Kubernetes resources rely on a Docker image from [Docker Hub](https://hub.docker.com/r/appoptics/kube-ao), see the [Dockerfile](Dockerfile) for more details. You can build and push this by running:
```
docker build -t appoptics/kube-ao:v0.1 .
docker push appoptics/kube-ao:v0.1
```
