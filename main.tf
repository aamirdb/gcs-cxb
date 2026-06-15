provider "google" {
  project = var.source_project_id
  alias   = "source"
}

provider "google" {
  project = var.destination_project_id
  alias   = "destination"
}

module "gcs_transfer_job" {
  source = "./modules/gcs_transfer"

  providers = {
    google.source      = google.source
    google.destination = google.destination
  }

  source_project_id           = var.source_project_id
  destination_project_id      = var.destination_project_id
  source_bucket_name          = var.source_bucket_name
  destination_bucket_name     = var.destination_bucket_name
  source_bucket_location      = var.source_bucket_location
  destination_bucket_location = var.destination_bucket_location
}
