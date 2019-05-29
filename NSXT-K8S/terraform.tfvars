nsx = {
    ip  = "10.190.1.80"
    user = "admin"
    password = "VMware123!VMware123!"
}

nsx_data_vars = {
    transport_zone_overlay  = "TZ-Overlay"
    transport_zone_edge_vlan  = "TZ-VLAN-Edge"
    edge_cluster = "EdgeCluster"    
    t0_router_name = "tf-T0-K8S-Domain"
    t1_router_name = "tf-T1-K8S-Node-Management"
    scope = "k8s-cluster2"
    tag = "ncp/cluster"

    IP_block_name ="tf-K8S-POD-IP-BLOCK"
    IP_block_cidr ="172.27.0.0/16"

    IP_pool_name_nat ="tf-K8S-NAT-Pool"
    IP_pool_cidr_nat ="10.190.27.0/24"
    IP_pool_range_nat ="10.190.27.100-10.190.27.200"
    IP_pool_name_LB ="tf-K8S-LB-Pool"
    IP_pool_cidr_LB ="10.190.37.0/24"
    IP_pool_range_LB ="10.190.37.100-10.190.37.200"

    FW_section_top ="K8s-FW-top"
    FW_section_bottom ="K8s-FW-bottom"
}

vSphere = {
  user = "administrator@vsphere.local"
  password = "VMware123!"
  vsphere_server = "vc.demo.local"

  vsphere_datacenter = "istanbul"
  datastore = "esx5ds2"
  cluster ="ClusterC"
  template ="ubuntutemplate"
  K8s-master-vm = "tf-K8s-master"
  K8s-master-vm-ipv4_address = "10.190.5.50"
  K8s-master-vm-ipv4_netmask = "24"
  K8s-master-vm-ipv4_gateway = "10.190.5.1"
  K8s-node1-vm = "tf-K8s-node1"
  K8s-node2-vm = "tf-K8s-node2"

  domain="demo.local"

}
