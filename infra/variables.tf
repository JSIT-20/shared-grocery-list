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

variable "function_app_cors_allowed_origins" {
  description = "Allowed CORS origins for the Azure Function App API."
  type        = list(string)
  default = [
    "https://jsit-20.github.io",
    "http://localhost:5500",
    "http://127.0.0.1:5500",
  ]
}
