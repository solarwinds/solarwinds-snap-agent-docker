# kube-ao
Kubernetes assets for running AppOptics

## Development

The included Kubernetes resources rely on a Docker image from [Docker Hub](https://hub.docker.com/r/cmrust/kube-ao/). You can build and push that with the included `Dockerfile` by running:
```
docker build -t cmrust/kube-ao:v0.1 .
docker push cmrust/kube-ao:v0.1
```

## Installation

To deploy to Kubernetes, first update `APPOPTICS_TOKEN` in `conf/appoptics-config.yaml` and then push it as a secret to your namespace:
```
kubectl create secret -n <your-namespace-here> generic kube-ao-config-secret --from-file=./conf/appoptics-config.yaml
```

Then create the ServiceAccount that your pod will use to access the kube-api. Replace `<your-namespace-here>` references in `kube-ao-serviceaccount.yaml` and run:
```
kubectl apply -f kube-ao-serviceaccount.yaml
```

Then replace `<your-namespace-here>` in `kube-ao-deployment.yaml` and run:
```
kubectl apply -f kube-ao-deployment.yaml
```

Enable the Kubernetes plugin in the AppOptics UI and you should start seeing data trickle in.
