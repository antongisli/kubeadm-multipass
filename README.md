An incomplete toy project.

I wanted to automate creating a k8s cluster using kubeadm using multipass. I have 3 files here to represent 3 different control plane nodes.

The work is incomplete in terms of automating everything:
- the join token from the initial init node needs to be grabbed and used / provided somehow to the subsequent nodes that are created
- I started to create a quick template along with a script that would take a type as input (type being first control plane, additional control plane, or worker node). The type is injected into the cloud-init and is supposed to be picked up by the instance.
- left to do are things like cluster endpoint configuration, pod cidr configurations, etc.

Probably the next steps are to get preprocess.sh wrapped with something else, and paramaterize a bunch of things.

Still, quite a lot of the dirty work of setting up K8s is here.
