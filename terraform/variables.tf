variable "subscription_id" {
  description = "Identifiant de l'abonnement Azure"
  type        = string
}

variable "region" {
  description = "Région Azure, parmi celles autorisées par l'abonnement"
  type        = string
  default     = "austriaeast"
}

variable "vm_size" {
  description = "Taille de la machine (gratuite avec Azure for Students)"
  type        = string
  default     = "Standard_B2ats_v2"
}