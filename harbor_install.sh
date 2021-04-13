#!/bin/bash
set -ex
# Installation Prerequisites
# Update the apt package index and install packages to allow apt to use a repository over HTTPS
sudo apt-get update
sudo apt-get install -y \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg \
     lsb-release \
     openssl

# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Use the following command to set up the stable repository.
sudo echo \
     "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the apt package index, and install the latest version of Docker Engine and containerd
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Install docker-compose
# Run this command to download the current stable release of Docker Compose
# sudo curl -L "https://github.com/docker/compose/releases/download/1.28.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Apply executable permissions to the binary
sudo chmod +x /usr/local/bin/docker-compose

#  create a symbolic link to /usr/bin
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Command-line completion for the bash
# sudo curl \
#      -L https://raw.githubusercontent.com/docker/compose/1.28.5/contrib/completion/bash/docker-compose \
#      -o /etc/bash_completion.d/docker-compose
sudo curl \
    -L https://raw.githubusercontent.com/docker/compose/1.29.0/contrib/completion/bash/docker-compose \
    -o /etc/bash_completion.d/docker-compose

mkdir -p /root/harbor_offline_package
cd /root/harbor_offline_package

wget https://github.com/goharbor/harbor/releases/download/v2.2.1/harbor-offline-installer-v2.2.1.tgz
wget https://github.com/goharbor/harbor/releases/download/v2.2.1/harbor-offline-installer-v2.2.1.tgz.asc

gpg --keyserver hkps://keyserver.ubuntu.com --receive-keys 644FF454C0B4115C
gpg -v --keyserver hkps://keyserver.ubuntu.com --verify harbor-offline-installer-v2.2.1.tgz.asc

mkdir -p /root/software/tls/internal && mkdir ../server && mkdir ../ca
tar -xvf /root/harbor_offline_package/harbor-offline-installer-v2.2.1.tgz -C /root/software/

# Generate a Certificate Authority Certificate
cd /root/software/tls/
openssl genrsa -out harbor_ca.key 4096

openssl req -x509 -new -nodes -sha512 -days 36500 \
 -subj "/C=CN/ST=Beijing/L=Beijing/O=DWNEWS/OU=IT/CN=private_harbor" \
 -key harbor_ca.key \
 -out harbor_ca.crt

# Generate a Server Certificate
openssl genrsa -out harbor.key 4096
openssl req -sha512 -new \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=DWNEWS/OU=IT/CN=harbor" \
    -key harbor.key \
    -out harbor.csr
cat > v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=harbor.com
DNS.2=harbor
DNS.3=harbor
EOF
openssl x509 -req -sha512 -days 36500 \
    -extfile v3.ext \
    -CA harbor_ca.crt -CAkey harbor_ca.key -CAcreateserial \
    -in harbor.csr \
    -out harbor.crt

openssl x509 -inform PEM -in harbor.crt -out harbor.cert

cp harbor.cert /etc/docker/certs.d/harbor/
cp harbor.key /etc/docker/certs.d/harbor/
cp harbor_ca.crt /etc/docker/certs.d/harbor/

systemctl restart docker

docker run -v /:/hostfs goharbor/prepare:v2.2.0 gencert -p /root/software/tls/internal


mv /root/software/harbor/harbor.yml.tmpl /root/software/harbor/harbor.yml.origin
cp /root/software/harbor/harbor.yml.origin /root/software/harbor/harbor.yml

# sudo ./install.sh --with-notary --with-trivy --with-chartmuseum

