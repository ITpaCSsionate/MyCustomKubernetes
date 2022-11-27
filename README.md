# My Custom Kubernetes
## What is this?
I am a Kubernetes fan. I worked with OpenShift for approximately a year and a half, and it allowed me to learn both OpenShift and Kubernetes. 

So, I had some spare time and I explored setting up a local kubernetes cluster using Libvirt + kubeadm (all by hand), and then using Vagrant (with Libvirt provider) and Kubespray. 

## Is this finished?
Not at all. It just has some folders for setting up a basic kubernetes cluster and installing some valuable applications. A lot of valuable applications and integrations are missing for a _fully-productive_ cluster. But, for playing in my local computer, this made the trick.

## What is missing?
Basically, _valuable_ applications:
- NFS provider (tested it in an older version though)
- Prometheus stack (monitoring)
- ElasticSearch+Kibana+FluentD (logging)
- OPA-gateekeper (policies)
- Velero+Restic (backups)
- Knative (serverless)
- Some service mesh (in case this is setup in the cloud). Istio?
