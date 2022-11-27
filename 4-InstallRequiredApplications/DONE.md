# Install OLM - Helm chart
[Source0](https://olm.operatorframework.io) and [Source1](https://github.com/operator-framework/operator-lifecycle-manager)

git clone https://github.com/operator-framework/operator-lifecycle-manager.git

kubectl create namespace charts-installation

kubectl config set-context charts-installation --cluster=cluster.local --user=kubernetes-admin --namespace=charts-installation
kubectl config use-context charts-installation

cd crds
for file in $(ls); do kubectl create -f ${file}; done #cannot be kubectl apply as it will trigger a limitation because of the file size
cd ..
> I had to modify the .spec.securityContext of the deployments of the operator and catalog operator so that runAsNonRoot: false instead of true. Even when setting privileged psa it was not working... the reason seems to be that the image runs with root, or I am missing some knowledge in this regard. 
> Also, I had to comment the flag --set-workload-user-id from catalog-operator deployment as the logs were telling me: unknown flag: --set-workload-user-id
helm upgrade --debug --install -f values.yaml olm .


kubectl config set-context operator-lifecycle-manager --cluster=cluster.local --user=kubernetes-admin --namespace=operator-lifecycle-manager
kubectl config use-context operator-lifecycle-manager


> I do not know why (I suppose Ansible and the config I am applying when joining workers) but I could not get logs of the containers due to firewall issues. However, I stopped the service and disabled it in the Vagrantfile... Confirmed by using nmap on the host and seeing the port of kubelet (10250) filtered. Causes can be Vagrantfile or Ansible... (Ansible makes no sense though as it should not be modifying host-related things...)
> systemctl stop firewalld && systemctl disable firewalld



But then packageserver was created by the operator... and I could not modify the same runAs as I did with the other two deployments (the operator rewrites it). The solution is using the recommended installation method...


# Install OLM - recommended install
## install operator-sdk  binary
```
export ARCH=$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n $(uname -m) ;; esac)
export OS=$(uname | awk '{print tolower($0)}')
export OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/download/v1.23.0
curl -LO ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}
gpg --keyserver keyserver.ubuntu.com --recv-keys 052996E2A20B5C7E
curl -LO ${OPERATOR_SDK_DL_URL}/checksums.txt
curl -LO ${OPERATOR_SDK_DL_URL}/checksums.txt.asc
gpg -u "Operator SDK (release) <cncf-operator-sdk@cncf.io>" --verify checksums.txt.asc
grep operator-sdk_${OS}_${ARCH} checksums.txt | sha256sum -c -
chmod +x operator-sdk_${OS}_${ARCH} && sudo mv operator-sdk_${OS}_${ARCH} /usr/local/bin/operator-sdk   
```

## install OLM
> First remove all the CRDs and apiservices
```
kubectl config use-context charts-installation
operator-sdk olm install
```


# Install ArgoCD operator
[Source](https://argocd-operator.readthedocs.io/en/latest/install/olm/) and [Source](https://argocd-operator.readthedocs.io/en/latest/contribute/development/) and [Source](https://github.com/argoproj-labs/argocd-operator/) and [Source tag](https://github.com/argoproj-labs/argocd-operator/releases/tag/v0.4.0)

## Package the operator following the official guide
wget https://github.com/argoproj-labs/argocd-operator/archive/refs/tags/v0.4.0.tar.gz
tar -xf v0.4.0.tar.gz
cd argocd-operator-0.4.0
docker login 
make bundle-build bundle-push BUNDLE_IMG=itpacssionate/local-kubernetes-images:argocd-operator
make bundle-build bundle-push BUNDLE_IMG=itpacssionate/kubernetes-local:argocd-operator

make catalog-build catalog-push BUNDLE_IMG=itpacssionate/local-kubernetes-images:argocd-operator CATALOG_IMG=itpacssionate/local-kubernetes-images:argocd-operator-catalogsource
make catalog-build catalog-push BUNDLE_IMG=itpacssionate/kubernetes-local:argocd-operator CATALOG_IMG=itpacssionate/kubernetes-local:argocd-operator-catalogsource

## Install the operator

kubectl create namespace argocd 

### Create a catalogsource, subscription and operatorgroups
[Reference](https://olm.operatorframework.io/docs/concepts/crds/)
```
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: myargocdoperator-catalog
  namespace: olm
spec:
  sourceType: grpc
  image: hub.docker.com/itpacssionate/local-kubernetes-images:argocd-operator
  displayName: MyArgoCDOperator
  publisher: Custom
```
Then, we want it to watch all the namespaces
```
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: argocd
  namespace: argocd
```
> Or, if we want it to watch our GitOps namespaces:
> ```
> apiVersion: operators.coreos.com/v1alpha2
> kind: OperatorGroup
> metadata:
>   name: argocd
>   namespace: argocd
> spec:
>   selector:
>     itpacssionate-gitops: "true"
> ```

### apply the resources
kubectl create -f catalog_source.yaml
kubectl create -f operator_group.yaml

> The catalog pod was crashlooping...
```
kubectl logs -f myargocdoperator-catalog-cdnlr -n olm
time="2022-09-02T20:02:47Z" level=warning msg="\x1b[1;33mDEPRECATION NOTICE:\nSqlite-based catalogs and their related subcommands are deprecated. Support for\nthem will be removed in a future release. Please migrate your catalog workflows\nto the new file-based catalog format.\x1b[0m"
Error: open db-674382782: permission denied
Usage:
  opm registry serve [flags]

Flags:
  -d, --database string          relative path to sqlite db (default "bundles.db")
      --debug                    enable debug logging
  -h, --help                     help for serve
  -p, --port string              port number to serve on (default "50051")
      --skip-migrate             do  not attempt to migrate to the latest db revision when starting
  -t, --termination-log string   path to a container termination log file (default "/dev/termination-log")
      --timeout-seconds string   Timeout in seconds. This flag will be removed later. (default "infinite")

Global Flags:
      --skip-tls-verify   skip TLS certificate verification for container image registries while pulling bundles
      --use-http          use plain HTTP for container image registries while pulling bundles

```

# It never worked. Trying to install ArgoCD with the catalogsource available (created by OLM installation, operatorhub.io)
kubectl get packagemanifests -A | grep argo
Create the following resources:
```
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: argocd
  namespace: argocd
```
```
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: argocd
  namespace: argocd
spec:
  channel: alpha
  name: argocd-operator
  source: operatorhubio-catalog
  sourceNamespace: olm
  installPlanApproval: Automatic
```
```
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  namespace: argocd
  name: cluster-argocd
spec: {}
```

kubectl get -o json secret cluster-argocd-cluster -n argocd | jq .data.\"admin.password\" | tr -d \" | base64 -d -
kubectl port-forward service/cluster-argocd-server 8443:443 -n argocd 

access https://localhost:8443, user admin, the password has already been obtained

# SealedSecrets
## Why?
GitOps is something I am super passionate about. The reasons are its simplicity and its cleanliness. However, there is one issue with keeping sensitive data (secrets) stored in clear-text in Git: what happens if someone breaks into your Git?

For this reason, SealedSecrets allow us to store secrets in Git as they are encrypted. This enables full GitOps. 

## Procedure
git clone https://github.com/bitnami-labs/sealed-secrets.git
cd sealed-secrets/helm/sealed-secrets
kubectl create namespace bitnami-sealed-secrets
> edit values.yaml 
helm upgrade --install -f values.yaml bitnami-sealed-secrets . --debug

### Install kubeseal
cd ../../
export releaseTag=v0.18.2
export version=0.18.2
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/${releaseTag}/kubeseal-${version}-linux-amd64.tar.gz
tar -xvzf kubeseal-${version}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

kubectl create namespace sealedsecrets-testunseal
kubeseal --controller-name bitnami-sealed-secrets --controller-namespace bitnami-sealed-secrets --format yaml --v 5 < examplesecret.yaml > examplesecret-sealed.yaml
### check that it works:
kubectl get -o json secret testunseal -n sealedsecrets-testunseal | jq .data.\"test\" | tr -d \" | base64 -d -
kubectl get -o json secret testunseal -n sealedsecrets-testunseal | jq .data.\"testtwo\" | tr -d \" | base64 -d -



# Install kubernetes-dashboard. [Source](https://github.com/kubernetes/dashboard.git)
## Why?
Kubernetes-dashbaord is a very useful UI for interacting with the cluster. With a few additions (authentication by using a proxy) it can be super useful, and it is open source (free for use).

## Procedure
git clone https://github.com/kubernetes/dashboard.git
cd dashboard/aio/deploy/helm-chart/kubernetes-dashboard/
kubectl create namespace kubernetes-dashboard
kubectl config set-context kubernetes-dashboard --cluster=cluster.local --user=kubernetes-admin --namespace kubernetes-dashboard
kubectl config use-context kubernetes-dashboard
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm dependency build
> edit values.yaml
helm upgrade --install -f values.yaml kubernetes-dashboard . --debug

## Test
kubectl port-forward service/kubernetes-dashboard 8443:443 -n kubernetes-dashboard
kubectl apply -f serviceaccount.yaml
kubectl apply -f clusterrolebinding.yaml
kubectl apply -f secret.yaml
token=$(kubectl get -o json secret  kubernetes-dashboard-access-serviceaccount-secret -n kubernetes-dashboard | jq .data.\"token\" | tr -d \" | base64 -d -)

kubectl config set-credentials kubernetes-dashboard-access-serviceaccount --token ${token}
kubectl config set-context kubernetes-dashboard-access-serviceaccount --cluster=cluster.local --namespace=kubernetes-dashboard --user=kubernetes-dashboard-access-serviceaccount
kubectl config use-context kubernetes-dashboard-access-serviceaccount


Access https://localhost:8443 and login with the token, check that you can see everything. 



# Install kube-metrics server. [Source](https://github.com/kubernetes-sigs/metrics-server)
## Why? 
The purpose of installing it is getting the ability to know what your pods are consuming in terms of cpu and memory.

## Procedure
git clone https://github.com/kubernetes-sigs/metrics-server
cd metrics-server/charts/metrics-server/

kubectl create namespace kube-metrics-server
kubectl config set-context kube-metrics-server --namespace=kube-metrics-server --cluster=cluster.local --user=kubernetes-admin
kubectl config use-context kube-metrics-server


> edit values.yaml
helm upgrade --install -f values.yaml kubernetes-metrics-server . --debug

> I had to add a new arg __--kubelet-insecure-tls__ because error log: "cannot validate certificate for 192.168.230.3 because it doesn't contain any IP SANs"


## Test
kubectl get apiservices
kubectl top pods

# Install NFS provider (source)[https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner]


# Install (Tekton)[https://tekton.dev/]
## Why?
A tool for CI/CD is a must. Until now, Jenkins has been the most popular. But, for many, jenkins has become _too old_. Also, it is not _kubernetes native_. Tekton is a new tool that aims to run the CICD pipelines in a cloud-native way. 

## Procedure (source)[https://tekton.dev/docs/installation/]
k apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
k apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
k apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml


