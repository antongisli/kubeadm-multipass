#cloud-config

packages:
  - bridge-utils
  - git
  - net-tools
  - apt-transport-https 
  - ca-certificates 
  - curl 
  - gnupg
  - jq

write_files:
  - path: /etc/systemd/system/vxlan-mesh.service
    content: |
      [Unit]
      Description=VXLAN Mesh Agent Service
      After=network.target

      [Service]
      Type=simple
      ExecStart=/usr/bin/python3 /home/ubuntu/vxlan-mesh/vxlan-mesh-agent.py -p cp-1 -i 10.10.10.1/24 -n enp0s1
      Restart=on-failure

      [Install]
      WantedBy=multi-user.target

bootcmd:
  - echo "NODE_TYPE=${TYPE}" > /etc/environment

runcmd:
  # Add Kubernetes APT repository and install Kubernetes components
  - curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
  - echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
  # Update package list and install kubelet, kubeadm, and kubectl
  - apt-get update && apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl
  # Clone the desired repository
  - git clone https://github.com/antongisli/vxlan-mesh.git /home/ubuntu/vxlan-mesh
  - chown -R ubuntu:ubuntu /home/ubuntu/vxlan-mesh
  # Setup kubeadm bash completion for the 'ubuntu' user
  - sudo -H -u ubuntu bash -c 'mkdir -p /home/ubuntu/.kube'
  - chown -R ubuntu:ubuntu /home/ubuntu/.kube
  - sudo -H -u ubuntu bash -c 'kubeadm completion bash > /home/ubuntu/.kube/kubeadm_completion.bash'
  - echo 'source /home/ubuntu/.kube/kubeadm_completion.bash' >> /home/ubuntu/.bashrc
  - |
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF

    modprobe overlay
    modprobe br_netfilter

    # sysctl params required by setup, params persist across reboots
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF

    # Apply sysctl params without reboot
    sysctl --system
  # Setup containerd
  - |
    # Add Docker's official GPG key:
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources:
    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt install containerd.io
    sed -i 's/^disabled_plugins = \["cri"\]/# disabled_plugins = ["cri"]/g' /etc/containerd/config.toml
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl restart containerd

  # Reload the systemctl daemon to recognize the new service
  - systemctl daemon-reload
  # Enable the service to start on boot
  - systemctl enable vxlan-mesh.service
  # Start the service
  - systemctl start vxlan-mesh.service

  # install flannel
  #- curl https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  #- kubectl apply -f kube-flannel.yml
  # TODO need to set the pod cidr
  # wget https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  # sed command
  # - curl -s https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml | kubectl apply -f -



# starting vxlan sudo python3 vxlan-mesh-agent.py -p cp-1 -i 10.10.10.1/24 -n enp0s1

### CP-1 kubernetes setup
#sudo kubeadm init --pod-network-cidr 10.244.0.0/16 --control-plane-endpoint cluster-endpoint.home --apiserver-advertise-address=10.10.10.1
  - | 
    . /etc/environment
    if [ "$NODE_TYPE" = "first-cp" ]; then
      echo "Setting up first control plane node."
      mkdir -p /home/ubuntu/.kube
      sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
      sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config
      kubeadm init --pod-network-cidr 10.244.0.0/16 --control-plane-endpoint cluster-endpoint.home --apiserver-advertise-address=10.10.10.1
      sudo -H -u ubuntu bash -c 'curl -s https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml | kubectl apply -f -'
    fi
final_message: "The system is finally up, after $UPTIME seconds"
#kubectl taint node cp-1 node-role.kubernetes.io/control-plane:NoSchedule-

# TODO install metrics server
# wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# wget kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# edit components.yaml to add       --kubelet-insecure-tls to args section
# kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# 


# get key and join command

### CP-2 join command
#sudo kubeadm join cluster-endpoint.home:6443 --token yelzco.xdt1jmv161f4j8vw \
# --discovery-token-ca-cert-hash sha256:ee1dcad60d93af293576edf163e7fc97561d9d32d236120fc7696e3f94aced41 \
# --control-plane --certificate-key 0309e440a69e38456c351563da6713d117dc73ddfc8010da4828eec19097d5ba\
# --apiserver-advertise-address 10.10.10.2

#debugging and troubleshooting
#sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps --all

#flannel
#https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml


#
# KUBEVIP (as root)
#https://kube-vip.io/docs/installation/static/
#export VIP=10.10.10.10
#export INTERFACE=br-100
#KVVERSION=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")
#kube-vip manifest pod \
#    --interface $INTERFACE \
#    --address $VIP \
#    --controlplane \
#    --services \
#    --arp \
#    --leaderElection | tee /etc/kubernetes/manifests/kube-vip.yaml

# ADD NEW CPs (use kubevip)
# add kubevip
# ...

