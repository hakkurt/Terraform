provider "nsxt" {
    host = "${var.nsx["ip"]}"
    username = "${var.nsx["user"]}"
    password = "${var.nsx["password"]}"
    allow_unverified_ssl = true
}

# Constant Parameters
data "nsxt_transport_zone" "overlay_transport_zone" {
  display_name = "${var.nsx_data_vars["transport_zone_overlay"]}"
}

data "nsxt_transport_zone" "edge_vlan_transport_zone" {
   display_name = "${var.nsx_data_vars["transport_zone_edge_vlan"]}"
}

data "nsxt_edge_cluster" "edge_cluster" {
  display_name = "${var.nsx_data_vars["edge_cluster"]}"
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

resource "nsxt_logical_router_link_port_on_tier0" "link_port_tier0_UL1" {
  description       = "T0 Uplink Port provisioned by Terraform"
  display_name      = "Uplink1Edge1"
  logical_router_id = "${nsxt_logical_tier0_router.tier0_router.id}"
        
}

resource "nsxt_logical_router_link_port_on_tier0" "link_port_tier0_UL2" {
  description       = "T0 Uplink Port provisioned by Terraform"
  display_name      = "Uplink1Edge2"
  logical_router_id = "${nsxt_logical_tier0_router.tier0_router.id}"
        
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

resource "nsxt_ip_block_subnet" "ip_block_subnet" {
  description = "ip_block_subnet"
  block_id    = "${nsxt_ip_block.ip_block.id}"
  size        = 16
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

resource "vsphere_virtual_machine" "vm" {
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
      }

      network_interface {
      }

      ipv4_gateway = "${var.vSphere["K8s-master-vm-ipv4_gateway"]}"
    }
  }
  wait_for_guest_net_timeout = 0

}