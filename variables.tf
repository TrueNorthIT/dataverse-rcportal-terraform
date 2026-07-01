variable "api_url" {
  type        = string
  description = "Dataverse Contact API base URL"
}

variable "connection_key" {
  type        = string
  sensitive   = true
  description = "Pre-shared admin connection key. Must equal ADMIN_CONNECTION_KEY on the Contact API. Sent as the admin Bearer token."
}

variable "scope" {
  type    = string
  default = "rcportal"
}
