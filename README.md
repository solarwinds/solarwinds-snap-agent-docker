# kube-ao
Kubernetes assets for running AppOptics

## About

This repo contains two Kubernetes assets:
- Deployment - A single pod to run on a master node and talk to the kube-api. Communication with kube-api is facilitated by the included ServiceAccount with RBAC restrictions.
- DaemonSet - A DaemonSet that runs a pod on every node in your cluster and publishes HostAgent and Docker metrics.

## Installation

To deploy to Kubernetes, first update `APPOPTICS_TOKEN` in `conf/appoptics-config.yaml` and then push it as a secret to your namespace:
```
kubectl create secret -n <your-namespace-here> generic kube-ao-config-secret --from-file=./conf/appoptics-config.yaml
```

### Deployment

Then create the ServiceAccount that your pod will use to access the kube-api. Replace `<your-namespace-here>` references in `kube-ao-serviceaccount.yaml` and run:
```
kubectl apply -f kube-ao-serviceaccount.yaml
```

Then replace `<your-namespace-here>` in `kube-ao-deployment.yaml` and run:
```
kubectl apply -f kube-ao-deployment.yaml
```

Enable the Kubernetes plugin in the AppOptics UI and you should start seeing data trickle in.

### DaemonSet

Replace `<your-namespace-here>` in `kube-ao-daemonset.yaml` and run:
```
kubectl apply -f kube-ao-daemonset.yaml
```

Enable the Docker plugin in the AppOptics UI and you should start seeing data trickle in.

Note: If the `docker` group's `gid` on your host machine is not `233`, you'll need to manually change this in the DaemonSet yaml before deploying. See: `securityContext.fsGroup`.

## Development

The included Kubernetes resources rely on Docker images from Docker Hub, see respectively for the [Deployment](https://hub.docker.com/r/cmrust/kube-ao/) and [DaemonSet](https://hub.docker.com/r/cmrust/kube-ao-ds/). You can build and push those with the included Dockerfiles by running:
```
docker build -t cmrust/kube-ao:v0.1 .
docker push cmrust/kube-ao:v0.1
```
```
docker build -f Dockerfile-ds -t cmrust/kube-ao-ds:v0.1 .
docker push cmrust/kube-ao-ds:v0.1
```
