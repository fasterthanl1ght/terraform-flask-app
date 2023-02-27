variable "region" {
  type = string
  default = "us-east-1"
}

variable "allow_ports" {
  description = "List of ports to open for server"
  type = list
  default = ["80"] #insert list of ports you need seperated by ","
}