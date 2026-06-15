variable "source_project_id" {
  description = "The ID of the source project"
  type        = string
}

variable "destination_project_id" {
  description = "The ID of the destination project"
  type        = string
}

variable "source_bucket_name" {
  description = "The name of the source bucket"
  type        = string
}

variable "destination_bucket_name" {
  description = "The name of the destination bucket"
  type        = string
}

variable "location" {
  description = "The location for the buckets"
  type        = string
  default     = "US"
}
variable "source_bucket_location" { type = string }
variable "destination_bucket_location" { type = string }
