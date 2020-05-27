# NVIDIA Driver container for Flatcar

### Prerequisites

##### Enable required modules
```sh
sudo modprobe -a loop ipmi_msghandler
echo -e "loop\nipmi_msghandler" | sudo tee /etc/modules-load.d/driver.conf
```

#### Add nvidia-runtime
```bash
sudo mkdir -p /etc/systemd/system/docker.service.d

sudo tee /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
Environment=PATH=$PATH:/run/nvidia/driver/usr/bin
ExecStart=
ExecStart=/usr/bin/dockerd --host=fd:// --add-runtime=nvidia=/run/nvidia/driver/usr/bin/nvidia-container-runtime
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker

# Make sure the runtime is added
docker info | grep -i "runtime"
```

#### Flatcar AWS image
```sh
# Run driver container in detached mode

docker run -d --privileged --pid=host --restart=unless-stopped -v /run/nvidia:/run/nvidia:shared --name nvidia-driver nvidia/driver:440.64.00-4.19.107-flatcar

# Check logs to make sure driver container ran properly

docker logs -f nvidia-driver

# Test nvidia-smi with official CUDA image

docker run --runtime=nvidia --rm nvidia/cuda:9.2-base sh -c 'uname -r && nvidia-smi --query-gpu=driver_version --format=csv,noheader'
```

#### In Kubernetes
```sh
# Set up the cluster for Container Linux (https://kubernetes.io/docs/setup/independent/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl)

# Run driver container 

docker run -d --privileged --pid=host --restart=unless-stopped -v /run/nvidia:/run/nvidia:shared --name nvidia-driver nvidia/driver:440.64.00-4.19.107-flatcar

# Make sure the driver container is running before moving on to next steps
docker ps -a | grep -i driver

# Set default runtime to nvidia by editing /etc/systemd/system/docker.service.d

sudo sed -i "s|nvidia=/run/nvidia/driver/usr/bin/nvidia-container-runtime|nvidia=/run/nvidia/driver/usr/bin/nvidia-container-runtime default-runtime=nvidia|" /etc/systemd/system/docker.service.d/override.conf

sudo systemctl daemon-reload
sudo systemctl restart docker

# Deploy nvidia k8s-device-plugin (https://github.com/NVIDIA/k8s-device-plugin#enabling-gpu-support-in-kubernetes)

# Deploy GPU pods

# Set up monitoring

# Install helm (https://docs.helm.sh/using_helm/#installing-the-helm-client) to /opt/bin

# Initialize helm

kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller	 
helm init --service-account tiller

# Label GPU nodes

kubectl label nodes <flatcar-gpu-node> hardware-type=NVIDIAGPU

# Install the monitoring charts

helm repo add gpu-helm-charts https://nvidia.github.io/gpu-monitoring-tools/helm-charts
helm repo update
helm install gpu-helm-charts/prometheus-operator --name prometheus-operator --namespace monitoring
helm install gpu-helm-charts/kube-prometheus --name kube-prometheus --namespace monitoring

# Check the status of the pods

kubectl get pods -n monitoring

# Forward the port for Grafana

kubectl -n monitoring port-forward $(kubectl get pods -n monitoring -lapp=kube-prometheus-grafana -ojsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}') 3000 &

# Open a browser window and type http://localhost:3000 to view the Nodes Dashboard in Grafana
```
