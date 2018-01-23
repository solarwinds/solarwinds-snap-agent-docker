# kube-ao
Kubernetes assets for running AppOptics

Replace `APPOPTICS_TOKEN` in `conf/appoptics-config.yaml` and then build and run the docker container with:
```
docker build -t kube-ao .
docker run kube-ao
```

To run a bash shell in the container instead:
```
docker run -it kube-ao /bin/bash
```
