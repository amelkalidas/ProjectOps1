variable "subscriptionId" {             # During Terraform plan we can input the subscription.
    type = string
    default = "8d3ed687-4dc7-4a9b-903a-b9a14bde85c4"
}

variable "Location" {
    default = "centralindia"  
}

variable "admin_password" {
  description = "The admin password for the Linux VM"
  type        = string
  sensitive   = true  # Mark the variable as sensitive
  default = "SupersecurePass@2022"
}