variable "project_name" {
  description = "Prefix used for resource names."
  type        = string
  default     = "sharedgrocery"
}

variable "tags" {
  description = "Optional resource tags."
  type        = map(string)
  default     = {}
}
