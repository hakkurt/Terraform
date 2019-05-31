variable "nsx" {
    type = "map"
    description = "NSX Login Details"
}
variable "nsx_data_vars" {
    type = "map"
    description = "Existing NSX vars for data sources"
}
variable "vSphere" {
    type = "map"
    description = "Existing vSphere vars for data sources"
}
variable "dns_server_list" {
    type = "list"
    description = "DNS Servers"
}
