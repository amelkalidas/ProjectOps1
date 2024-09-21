variable "subscriptionId" {             # During Terraform plan we can input the subscription.
    type = string
//    default = ""
}

variable "Location" {
    default = "centralindia"  
}

variable "admin_password" {
  description = "The admin password for the Linux VM"
  type        = string
//  sensitive   = true  # Mark the variable as sensitive
  
}

variable "storageaccount" {
  default = "opsprodfileshare01"
  type = string
  description = "file share for the ops ."
  
}

variable "recoveryvaultname" {
  default = "CentralIndia-RV"
  
}