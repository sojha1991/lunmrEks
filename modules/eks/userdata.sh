#!/bin/bash
set -o xtrace

# Install required packages
yum update -y
yum install -y amazon-ssm-agent
yum install -y docker

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Install kubectl
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.27.0/2023-03-17/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl

# Configure kubelet
cat <<EOF > /etc/eks/bootstrap.sh
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh ${cluster_name} --kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=normal'
EOF

chmod +x /etc/eks/bootstrap.sh

# Configure kubeconfig
mkdir -p /root/.kube
cat <<EOF > /root/.kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${cluster_certificate}
    server: ${cluster_endpoint}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${cluster_name}"
EOF

# Start kubelet
systemctl start kubelet
systemctl enable kubelet 