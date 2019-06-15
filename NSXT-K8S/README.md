# Automate VMware NSX-T and Kubernetes (K8S) integration with Terraform 

These Terraform files can be used to automate steps described in VMware NSX-T and Kubernetes (K8S) Guide (<https://github.com/dumlutimuralp/nsx-t-k8s)>

Prerequisites are as follows :

1. Terraform v0.11.14 is used since NSX-T Terraform provider is not supported with v0.12.x yet
2. Base NSX-T deployment should be ready in advance
   * NSX-T Manager
   * Fabric Preperation
   * Transport Zones
   * VTEP Pool
   * Uplink Profile
   * Host Transport Node
   * Edge Transport Node
   * Edge Cluster
2. Tier 0 Logical Router Uplink Interface Configuration is not supported by current NSX-T Terraform provider. This step should be done manually (https://github.com/dumlutimuralp/nsx-t-k8s/tree/master/Part%201#tier-0-logical-router-uplink-interface-configuration)
3. Tier 0 BGP Configuration and route redistribution are not supported by current NSX-T Terraform provider. These steps should be done manually (https://github.com/dumlutimuralp/nsx-t-k8s/tree/master/Part%201#tier-0-bgp-configuration)
4. Base Ubuntu OS with 2 NICs should be installed. Root Login via SSH should be enabled
5. NSX-T Container package should be dowloaded and copied to root directory of Ubuntu OS (https://github.com/dumlutimuralp/nsx-t-k8s/tree/master/Part%203#install-cni). After this step, Virtual machine should be converted to a template.
6. Tagging existing NSX-T logical ports is not supported by current NSX-T Terraform provider. This step should be done manually (https://github.com/dumlutimuralp/nsx-t-k8s/blob/master/Part%203/README.md#tagging-nsx-t-objects-for-k8s)

**After Prerequisites are ready, following steps are realised by Terraform script :**
1. All necessary NSX-T Logical Switches will be created
2. Tier 0 and Tier 1 routers will be created
3. Tier 1 will be connected to Tier 0
4. Router advertisement will be enabled on Tier 1 router
5. All necessary NSX-T IP Blocks and IP Pools will be created
6. All NSX-T firewall sections will be created
7. Three (3) Virtual Machines will be deployed from vSphere template [one (1) for K8S master and two (2) for K8S nodes]
8. All three (3) Ubuntu OS will be configured based on TF configuration file (terraform.tfvars)
9. All necessary software packages will be deployed and configured (docker, K8s, NSX-T CNI Plugin, Open vSwitch)

**Caution :**
When 'dpkg -i nsx-cni_2.4.1.13515827_amd64.deb' command is executed, TF script shown as stuck, but in fact the script is running in the background and realising remaining steps. I could not find root cause for that. 
