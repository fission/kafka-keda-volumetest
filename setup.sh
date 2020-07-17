DOCKERHUB_REPO="repo" # Replace with your repo/org name
suffix="latest" # Topic name suffix and Docker image tag uses this for unique identification

echo "Creating temp repo"
mkdir temp
cd temp

## Install Helm3 ####
echo "Installing Helm3"
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
### END ####

# Install Fission ##
echo "Installing Fission"
kubectl create ns fission
git clone https://github.com/fission/fission.git
cd fission
sed -i -e "s/<DOCKERHUB_REPO>/$DOCKERHUB_REPO/g" skaffold.yaml
sed -i -e '/^ *prometheus:/,/^ *[^:]*:/s/enabled: true/enabled: false/' charts/fission-all/values.yaml
TAG=$suffix skaffold run
echo "Installing Fission CLI"
cd cmd/fission-cli
go build -o fission
chmod +x fission && sudo mv fission /usr/local/bin/
cd ../../../
#### END ####

## Install KEDA ##
echo "Installing KEDA"
kubectl create ns keda
helm install keda kedacore/keda --namespace keda
#### END ####

# Install Strimzi ##
echo "Installing Strimzi"
kubectl create ns kafka
wget https://github.com/strimzi/strimzi-kafka-operator/releases/download/0.18.0/strimzi-0.18.0.zip
unzip strimzi-0.18.0.zip
cd strimzi-0.18.0
sed -i 's/namespace: .*/namespace: kafka/' install/cluster-operator/*RoleBinding*.yaml
kubectl create ns my-kafka-project
mv ../../kafka-cluster/050-Deployment-strimzi-cluster-operator.yaml install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml

kubectl apply -f install/cluster-operator/ -n kafka
kubectl apply -f install/cluster-operator/020-RoleBinding-strimzi-cluster-operator.yaml -n my-kafka-project
kubectl apply -f install/cluster-operator/032-RoleBinding-strimzi-cluster-operator-topic-operator-delegation.yaml -n my-kafka-project
kubectl apply -f install/cluster-operator/031-RoleBinding-strimzi-cluster-operator-entity-operator-delegation.yaml -n my-kafka-project

# Creating cluster
echo "Creating Cluster"
kubectl apply -f ../../kafka-cluster/cluster.yaml -n my-kafka-project
echo "Waiting for cluster creation"
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n my-kafka-project


sed -i -e "s/##suffix/$suffix/g" ../../kafka-cluster/response-topic.yaml
sed -i -e "s/##suffix/$suffix/g" ../../kafka-cluster/request-topic.yaml
sed -i -e "s/##suffix/$suffix/g" ../../kafka-cluster/error-topic.yaml

# Creating topics
echo "Creating Topics"
kubectl apply -f ../../kafka-cluster/response-topic.yaml -n my-kafka-project
kubectl apply -f ../../kafka-cluster/request-topic.yaml -n my-kafka-project
kubectl apply -f ../../kafka-cluster/error-topic.yaml -n my-kafka-project
cd ..
### END ####

## Installing Redis ##
echo "Installing Redis"
kubectl create ns redis
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install redis-single --namespace redis \
  --set usePassword=false \
  --set cluster.enabled=false \
  --set master.persistence.enabled=false \
    bitnami/redis
#### END ####

## Apply fission spec ##
echo "Apply fission spec"
fission spec apply
#### END ####


## Remove ###
echo "Removing temp"
cd ..
rm -rf temp
#### END ####