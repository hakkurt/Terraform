provider "nsxt" {
    host = "${var.nsx["ip"]}"
    username = "${var.nsx["user"]}"
    password = "${var.nsx["password"]}"
    allow_unverified_ssl = true
}

data "nsxt_transport_zone" "overlay_transport_zone" {
  display_name = "${var.nsx_data_vars["transport_zone_overlay"]}"
}

data "nsxt_transport_zone" "edge_vlan_transport_zone" {
   display_name = "${var.nsx_data_vars["transport_zone_edge_vlan"]}"
}

data "nsxt_edge_cluster" "edge_cluster" {
  display_name = "${var.nsx_data_vars["edge_cluster_name"]}"
}


data "nsxt_switching_profile" "qos_profile" {
  display_name = "nsx-default-qos-switching-profile"
}

# Create Logical Switches
resource "nsxt_logical_switch" "tf-EdgeUL" {
  admin_state       = "UP"
  description       = "LS provisioned by tf"
  display_name      = "tf-EdgeUL"
  transport_zone_id = "${data.nsxt_transport_zone.edge_vlan_transport_zone.id}"
  

 switching_profile_id {
    key   = "${data.nsxt_switching_profile.qos_profile.resource_type}"
    value = "${data.nsxt_switching_profile.qos_profile.id}"
  }
}

resource "nsxt_logical_switch" "tf-K8SNodeManagementPlaneLS" {
  admin_state       = "UP"
  description       = "LS provisioned by Terraform"
  display_name      = "tf-K8SNodeManagementPlaneLS"
  transport_zone_id = "${data.nsxt_transport_zone.overlay_transport_zone.id}"
  replication_mode  = "MTEP"

 switching_profile_id {
    key   = "${data.nsxt_switching_profile.qos_profile.resource_type}"
    value = "${data.nsxt_switching_profile.qos_profile.id}"
  }
}

resource "nsxt_logical_switch" "tf-K8SNodeDataPlaneLS" {
  admin_state       = "UP"
  description       = "LS provisioned by Terraform"
  display_name      = "tf-K8SNodeDataPlaneLS"
  transport_zone_id = "${data.nsxt_transport_zone.overlay_transport_zone.id}"
  replication_mode  = "MTEP"

 switching_profile_id {
    key   = "${data.nsxt_switching_profile.qos_profile.resource_type}"
    value = "${data.nsxt_switching_profile.qos_profile.id}"
  }
}
# Create Logical Routers
resource "nsxt_logical_tier0_router" "tier0_router" {
  description = "T0 provisioned by Terraform"
  display_name = "${var.nsx_data_vars["t0_router_name"]}"
  edge_cluster_id = "${data.nsxt_edge_cluster.edge_cluster.id}"
  high_availability_mode ="ACTIVE_STANDBY"
  
  tag {
    scope = "${var.nsx_data_vars["scope"]}"
    tag   = "${var.nsx_data_vars["tag"]}"
  }
}
resource "nsxt_logical_tier1_router" "tier1_router" {
  description                 = "T1 provisioned by Terraform"
  display_name                = "${var.nsx_data_vars["t1_router_name"]}"
  failover_mode               = "PREEMPTIVE"
  edge_cluster_id             = "${data.nsxt_edge_cluster.edge_cluster.id}"
  enable_router_advertisement = true
  advertise_connected_routes  = true 
}

resource "nsxt_logical_router_link_port_on_tier0" "link_port_tier0" {
  description       = "T0 Port provisioned by Terraform"
  display_name      = "T0-RouterLinkPort"
  logical_router_id = "${nsxt_logical_tier0_router.tier0_router.id}"
        
}

resource "nsxt_logical_router_link_port_on_tier1" "link_port_tier1" {
  description                   = "T0 Port provisioned by Terraform"
  display_name                  = "LinkedPort_T0"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_router_port_id = "${nsxt_logical_router_link_port_on_tier0.link_port_tier0.id}"
    
}

resource "nsxt_logical_port" "logical_port1" {
  admin_state       = "UP"
  description       = "LP3 provisioned by Terraform"
  display_name      = "K8s-Management-port"
  logical_switch_id = "${nsxt_logical_switch.tf-K8SNodeManagementPlaneLS.id}"
    
}

resource "nsxt_logical_router_downlink_port" "downlink_port3" {
  description                   = "DP3 provisioned by Terraform"
  display_name                  = "tf-K8SNodeManagementInterface"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_switch_port_id = "${nsxt_logical_port.logical_port1.id}"
  ip_address                    = "${var.vSphere["K8s-master-vm-ipv4_gateway"]}/${var.vSphere["K8s-master-vm-ipv4_netmask"]}"
   
}
# Create IP Blocks and Pools
resource "nsxt_ip_block" "ip_block" {
  description  = "ip_block provisioned by Terraform"
  display_name = "${var.nsx_data_vars["IP_block_name"]}"
  cidr         = "${var.nsx_data_vars["IP_block_cidr"]}"

 tag {
    scope = "${var.nsx_data_vars["scope"]}"
    tag   = "${var.nsx_data_vars["tag"]}"
  }
}

resource "nsxt_ip_pool" "ip_pool_nat" {
  description = "ip_pool provisioned by Terraform"
  display_name = "${var.nsx_data_vars["IP_pool_name_nat"]}"

  tag = {
    scope = "${var.nsx_data_vars["scope"]}"
    tag   = "${var.nsx_data_vars["tag"]}"
  }

  subnet = {
    allocation_ranges = ["${var.nsx_data_vars["IP_pool_range_nat"]}"]
    cidr              = "${var.nsx_data_vars["IP_pool_cidr_nat"]}"
    
  }
}

resource "nsxt_ip_pool" "ip_pool_lb" {
  description = "ip_pool provisioned by Terraform"
  display_name = "${var.nsx_data_vars["IP_pool_name_LB"]}"

  tag = {
    scope = "${var.nsx_data_vars["scope"]}"
    tag   = "${var.nsx_data_vars["tag"]}"
  }

  subnet = {
    allocation_ranges = ["${var.nsx_data_vars["IP_pool_range_LB"]}"]
    cidr              = "${var.nsx_data_vars["IP_pool_cidr_LB"]}"
    
  }
}

resource "nsxt_firewall_section" "firewall_sect_top" {
  description  = "FS Top provisioned by Terraform"
  display_name = "${var.nsx_data_vars["FW_section_top"]}"

  section_type = "LAYER3"
  stateful     = true
  depends_on = ["nsxt_firewall_section.firewall_sect_bottom"]
}
resource "nsxt_firewall_section" "firewall_sect_bottom" {
  description  = "FS Bottom provisioned by Terraform"
  display_name = "${var.nsx_data_vars["FW_section_bottom"]}"

  section_type = "LAYER3"
  stateful     = true
}

# vSphere part

provider "vsphere" {
  user           = "${var.vSphere["user"]}"
  password       = "${var.vSphere["password"]}"
  vsphere_server = "${var.vSphere["vsphere_server"]}"
  
  # If you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "${var.vSphere["vsphere_datacenter"]}"
}

data "vsphere_datastore" "datastore" {
  name          = "${var.vSphere["datastore"]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "${var.vSphere["cluster"]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.vSphere["template"]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}


data "vsphere_network" "K8SNodeManagementPlaneLS" {
  name          = "${nsxt_logical_switch.tf-K8SNodeManagementPlaneLS.display_name}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
  depends_on = ["nsxt_logical_switch.tf-K8SNodeManagementPlaneLS"]
}

data "vsphere_network" "K8SNodeDataPlaneLS" {
  name          = "${nsxt_logical_switch.tf-K8SNodeDataPlaneLS.display_name}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
  depends_on = ["nsxt_logical_switch.tf-K8SNodeDataPlaneLS"]
}

resource "vsphere_virtual_machine" "K8s-master-vm" {
  name             = "${var.vSphere["K8s-master-vm"]}"
  resource_pool_id = "${data.vsphere_compute_cluster.cluster.resource_pool_id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 2
  memory   = 2048
  guest_id = "ubuntu64Guest"

  network_interface {
    network_id = "${data.vsphere_network.K8SNodeManagementPlaneLS.id}"
  }
    network_interface {
    network_id = "${data.vsphere_network.K8SNodeDataPlaneLS.id}"
  }
  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${var.vSphere["K8s-master-vm"]}"
        domain    = "${var.vSphere["domain"]}"
      }

      network_interface {
        ipv4_address = "${var.vSphere["K8s-master-vm-ipv4_address"]}"
        ipv4_netmask = "${var.vSphere["K8s-master-vm-ipv4_netmask"]}"
        dns_server_list = "${var.dns_server_list}"
      }

        ipv4_gateway = "${var.vSphere["K8s-master-vm-ipv4_gateway"]}"

      network_interface {
      }
      
    }
  }

  # wait_for_guest_net_timeout = 0

connection {
	type = "ssh",
	agent = "false"
	host = "${var.vSphere["K8s-master-vm-ipv4_address"]}"
      
	user = "${var.vSphere["OS_user"]}"
	password = "${var.vSphere["OS_password"]}"
    }

provisioner "remote-exec" {
	inline = [
	    "hostname ${var.vSphere["K8s-master-vm"]}",        
	    "echo '${var.vSphere["K8s-master-vm"]}' > /etc/hostname",
      "echo '${var.vSphere["K8s-master-vm-ipv4_address"]} ${var.vSphere["K8s-master-vm"]}' >> /etc/hosts",
      "echo 'nameserver ${var.dns_server_list[0]}' >> /etc/resolv.conf",      
	    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable'",
      "apt-get update",
      "apt-get install -y docker-ce",
      "apt-get update && apt-get install -y apt-transport-https curl",
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -",
      "cat <<EOF >/etc/apt/sources.list.d/kubernetes.list",
      "deb https://apt.kubernetes.io/ kubernetes-xenial main",
      "EOF",
      "apt-get update",
      "apt-get install -y kubelet kubeadm kubectl",
      "apt-get install -y python2.7 python-pip python-dev python-six build-essential dkms",
      "cd /nsx-container-2.4.1.13515827/OpenvSwitch/xenial_amd64/",
      "dpkg -i libopenvswitch_2.10.2.13185890-1_amd64.deb",
      "dpkg -i openvswitch-common_2.10.2.13185890-1_amd64.deb",
      "dpkg -i openvswitch-datapath-dkms_2.10.2.13185890-1_all.deb",
      "dpkg -i openvswitch-switch_2.10.2.13185890-1_amd64.deb",
      "systemctl force-reload openvswitch-switch",
      "ovs-vsctl add-br br-int",
      "ovs-vsctl add-port br-int ens192 -- set Interface ens192 ofport_request=1",
      "echo 'auto ens192 \n iface ens192 inet manual' >> /etc/network/interfaces",
      "ifup ens192",
      "swapoff -a",     
      "kubeadm init",
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "mkdir /var/www",
      "kubeadm token create --print-join-command > /var/www/K8sjoin.txt",
      "docker run -d -p 80:80 -v /var/www:/usr/share/nginx/html nginx",
      "cd /nsx-container-2.4.1.13515827/Kubernetes/ubuntu_amd64/",
      "dpkg -i nsx-cni_2.4.1.13515827_amd64.deb",
      "cd /nsx-container-2.4.1.13515827/Kubernetes/",
      "docker load -i nsx-ncp-ubuntu-2.4.1.13515827.tar",
      "docker tag registry.local/2.4.1.13515827/nsx-ncp-ubuntu:latest nsx-ncp:latest",
      "kubectl create -f https://raw.githubusercontent.com/hakkurt/Terraform/master/NSXT-K8S/YAML/nsx-ncp-rbac.yml",
      "wget https://raw.githubusercontent.com/hakkurt/Terraform/master/NSXT-K8S/YAML/ncp-deployment-custom.yml",
      "sed -i 's/10.190.16.50/${var.vSphere["K8s-master-vm-ipv4_address"]}/g' ncp-deployment-custom.yml",
      "sed -i 's/k8scluster2/${var.nsx_data_vars["scope"]}/g' ncp-deployment-custom.yml",
      "sed -i 's/10.190.1.80/${var.nsx["ip"]}/g' ncp-deployment-custom.yml",
      "sed -i 's/VMware123!VMware123!/${var.nsx["password"]}/g' ncp-deployment-custom.yml",
      "sed -i 's/tf-T0-K8S-Domain/${var.nsx_data_vars["t0_router_name"]}/g' ncp-deployment-custom.yml",
      "sed -i 's/tf-K8S-POD-IP-BLOCK/${var.nsx_data_vars["IP_block_name"]}/g' ncp-deployment-custom.yml",
      "sed -i 's/tf-K8S-NAT-Pool/${var.nsx_data_vars["IP_pool_name_nat"]}/g' ncp-deployment-custom.yml",
      "sed -i 's/tf-K8S-LB-Pool/${var.nsx_data_vars["IP_pool_name_LB"]}/g' ncp-deployment-custom.yml",
      "sed -i 's/K8s-FW-top/${var.nsx_data_vars["FW_section_top"]}/g' ncp-deployment-custom.yml",
      "sed -i 's/K8s-FW-bottom/${var.nsx_data_vars["FW_section_bottom"]}/g' ncp-deployment-custom.yml",
      "kubectl create -f ncp-deployment-custom.yml --namespace=nsx-system",
      "wget https://raw.githubusercontent.com/hakkurt/Terraform/master/NSXT-K8S/YAML/nsx-node-agent-ds.yml",
      "sed -i 's/10.190.16.50/${var.vSphere["K8s-master-vm-ipv4_address"]}/g' nsx-node-agent-ds-custom.yml",
      "until kubectl get nodes | grep -q ${var.vSphere["K8s-node2-vm"]}",
      "do",
      "sleep 1;",
      "done",
      "kubectl create -f nsx-node-agent-ds-custom.yml --namespace=nsx-system",

      ]
    }

  }


resource "vsphere_virtual_machine" "K8s-node1-vm" {
  name             = "${var.vSphere["K8s-node1-vm"]}"
  resource_pool_id = "${data.vsphere_compute_cluster.cluster.resource_pool_id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 2
  memory   = 2048
  guest_id = "ubuntu64Guest"

  network_interface {
    network_id = "${data.vsphere_network.K8SNodeManagementPlaneLS.id}"
  }
    network_interface {
    network_id = "${data.vsphere_network.K8SNodeDataPlaneLS.id}"
  }
  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${var.vSphere["K8s-node1-vm"]}"
        domain    = "${var.vSphere["domain"]}"
      }

      network_interface {
        ipv4_address = "${var.vSphere["K8s-node1-vm-ipv4_address"]}"
        ipv4_netmask = "${var.vSphere["K8s-node1-vm-ipv4_netmask"]}"
        dns_server_list = "${var.dns_server_list}"
      }

        ipv4_gateway = "${var.vSphere["K8s-node1-vm-ipv4_gateway"]}"

      network_interface {
      }
      
    }
  }

  # wait_for_guest_net_timeout = 0

connection {
	type = "ssh",
	agent = "false"
	host = "${var.vSphere["K8s-node1-vm-ipv4_address"]}"
      
	user = "${var.vSphere["OS_user"]}"
	password = "${var.vSphere["OS_password"]}"
    }

provisioner "remote-exec" {
	inline = [
	    "hostname ${var.vSphere["K8s-node1-vm"]}",
	    "echo '${var.vSphere["K8s-node1-vm"]}' > /etc/hostname",
      "echo '${var.vSphere["K8s-node1-vm-ipv4_address"]} ${var.vSphere["K8s-node1-vm"]}' >> /etc/hosts",
      "echo 'nameserver ${var.dns_server_list[0]}' >> /etc/resolv.conf",      
	    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable'",
      "apt-get update",
      "apt-get install -y docker-ce",
      "apt-get update && apt-get install -y apt-transport-https curl",
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -",
      "cat <<EOF >/etc/apt/sources.list.d/kubernetes.list",
      "deb https://apt.kubernetes.io/ kubernetes-xenial main",
      "EOF",
      "apt-get update",
      "apt-get install -y kubelet kubeadm kubectl",
      "apt-get install -y python2.7 python-pip python-dev python-six build-essential dkms",
      "cd /nsx-container-2.4.1.13515827/OpenvSwitch/xenial_amd64/",
      "dpkg -i libopenvswitch_2.10.2.13185890-1_amd64.deb",
      "dpkg -i openvswitch-common_2.10.2.13185890-1_amd64.deb",
      "dpkg -i openvswitch-datapath-dkms_2.10.2.13185890-1_all.deb",
      "dpkg -i openvswitch-switch_2.10.2.13185890-1_amd64.deb",
      "systemctl force-reload openvswitch-switch",
      "ovs-vsctl add-br br-int",
      "ovs-vsctl add-port br-int ens192 -- set Interface ens192 ofport_request=1",
      "echo 'auto ens192 \n iface ens192 inet manual' >> /etc/network/interfaces",
      "ifup ens192",
      "swapoff -a",
      "wget --tries=0 --retry-connrefused http://'${var.vSphere["K8s-master-vm-ipv4_address"]}'/K8sjoin.txt",      
      "sh K8sjoin.txt",
      "cd /nsx-container-2.4.1.13515827/Kubernetes/",
      "docker load -i nsx-ncp-ubuntu-2.4.1.13515827.tar",
      "docker tag registry.local/2.4.1.13515827/nsx-ncp-ubuntu:latest nsx-ncp:latest",
      "cd /nsx-container-2.4.1.13515827/Kubernetes/ubuntu_amd64/",
      "dpkg -i nsx-cni_2.4.1.13515827_amd64.deb",
      
      ]
    }

    # depends_on = ["vsphere_virtual_machine.K8s-master-vm"]    
}


resource "vsphere_virtual_machine" "K8s-node2-vm" {
  name             = "${var.vSphere["K8s-node2-vm"]}"
  resource_pool_id = "${data.vsphere_compute_cluster.cluster.resource_pool_id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 2
  memory   = 2048
  guest_id = "ubuntu64Guest"

  network_interface {
    network_id = "${data.vsphere_network.K8SNodeManagementPlaneLS.id}"
  }
    network_interface {
    network_id = "${data.vsphere_network.K8SNodeDataPlaneLS.id}"
  }
  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${var.vSphere["K8s-node2-vm"]}"
        domain    = "${var.vSphere["domain"]}"
      }

      network_interface {
        ipv4_address = "${var.vSphere["K8s-node2-vm-ipv4_address"]}"
        ipv4_netmask = "${var.vSphere["K8s-node2-vm-ipv4_netmask"]}"
        dns_server_list = "${var.dns_server_list}"
      }

        ipv4_gateway = "${var.vSphere["K8s-node2-vm-ipv4_gateway"]}"

      network_interface {
      }
      
    }
  }

  #wait_for_guest_net_timeout = 0

connection {
	type = "ssh",
	agent = "false"
	host = "${var.vSphere["K8s-node2-vm-ipv4_address"]}"
      
	user = "${var.vSphere["OS_user"]}"
	password = "${var.vSphere["OS_password"]}"
    }

provisioner "remote-exec" {
	inline = [
	    "hostname ${var.vSphere["K8s-node2-vm"]}",        
	    "echo '${var.vSphere["K8s-node2-vm"]}' > /etc/hostname",
      "echo '${var.vSphere["K8s-node2-vm-ipv4_address"]} ${var.vSphere["K8s-node2-vm"]}' >> /etc/hosts",
      "echo 'nameserver ${var.dns_server_list[0]}' >> /etc/resolv.conf",      
	    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable'",
      "apt-get update",
      "apt-get install -y docker-ce",
      "apt-get update && apt-get install -y apt-transport-https curl",
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -",
      "cat <<EOF >/etc/apt/sources.list.d/kubernetes.list",
      "deb https://apt.kubernetes.io/ kubernetes-xenial main",
      "EOF",
      "apt-get update",
      "apt-get install -y kubelet kubeadm kubectl",
      "apt-get install -y python2.7 python-pip python-dev python-six build-essential dkms",
      "cd /nsx-container-2.4.1.13515827/OpenvSwitch/xenial_amd64/",
      "dpkg -i libopenvswitch_2.10.2.13185890-1_amd64.deb",
      "dpkg -i openvswitch-common_2.10.2.13185890-1_amd64.deb",
      "dpkg -i openvswitch-datapath-dkms_2.10.2.13185890-1_all.deb",
      "dpkg -i openvswitch-switch_2.10.2.13185890-1_amd64.deb",
      "systemctl force-reload openvswitch-switch",
      "ovs-vsctl add-br br-int",
      "ovs-vsctl add-port br-int ens192 -- set Interface ens192 ofport_request=1",
      "echo 'auto ens192 \n iface ens192 inet manual' >> /etc/network/interfaces",
      "ifup ens192",
      "swapoff -a",
      "wget --tries=0 --retry-connrefused http://'${var.vSphere["K8s-master-vm-ipv4_address"]}'/K8sjoin.txt",      
      "sh K8sjoin.txt",
      "cd /nsx-container-2.4.1.13515827/Kubernetes/",
      "docker load -i nsx-ncp-ubuntu-2.4.1.13515827.tar",
      "docker tag registry.local/2.4.1.13515827/nsx-ncp-ubuntu:latest nsx-ncp:latest",
      "cd /nsx-container-2.4.1.13515827/Kubernetes/ubuntu_amd64/",
      "dpkg -i nsx-cni_2.4.1.13515827_amd64.deb",
      ]
    }
    # depends_on = ["vsphere_virtual_machine.K8s-master-vm"]    
}


