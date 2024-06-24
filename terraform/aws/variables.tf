variable "number_of_nodes" {
  description = "The number of nodes to create"
  type        = number
  default     = 1

  validation {
    condition     = var.number_of_nodes <= 20
    error_message = "The number of nodes must be between 1 and 20."
  }
}
