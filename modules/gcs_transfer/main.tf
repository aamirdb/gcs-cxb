terraform {
  required_providers {
    google = {
      source                = "hashicorp/google"
      configuration_aliases = [google.source, google.destination]
    }
  }
}

# 1. Enable Required APIs in Source Project
resource "google_project_service" "storage_transfer_api" {
  provider = google.source
  project  = var.source_project_id
  service  = "storagetransfer.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "pubsub_api" {
  provider = google.source
  project  = var.source_project_id
  service  = "pubsub.googleapis.com"
  disable_on_destroy = false
}

# 2. Fetch Service Agent Emails Dynamically
# Get the Storage Transfer Service Agent
data "google_storage_transfer_project_service_account" "transfer_sa" {
  provider = google.source
  project  = var.source_project_id
}

# Get the GCS Service Agent (needed for Pub/Sub notifications)
data "google_storage_project_service_account" "gcs_sa" {
  provider = google.source
  project  = var.source_project_id
}

# 3. Grant Project-Level Pub/Sub Permissions (Source Project)
resource "google_project_iam_member" "transfer_sa_pubsub_editor" {
  provider = google.source
  project  = var.source_project_id
  role     = "roles/pubsub.editor"
  member   = "serviceAccount:${data.google_storage_transfer_project_service_account.transfer_sa.email}"
}

resource "google_project_iam_member" "gcs_sa_pubsub_publisher" {
  provider = google.source
  project  = var.source_project_id
  role     = "roles/pubsub.publisher"
  member   = "serviceAccount:${data.google_storage_project_service_account.gcs_sa.email_address}"
}

# 4. Source Bucket & Permissions
resource "google_storage_bucket" "source_bucket" {
  provider = google.source
  project  = var.source_project_id
  name     = var.source_bucket_name
  location = var.source_bucket_location
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "source_bucket_permissions" {
  for_each = toset(["roles/storage.objectViewer", "roles/storage.legacyBucketOwner"])
  provider = google.source
  bucket   = google_storage_bucket.source_bucket.name
  role     = each.key
  member   = "serviceAccount:${data.google_storage_transfer_project_service_account.transfer_sa.email}"
}

# 5. Destination Bucket & Permissions
resource "google_storage_bucket" "destination_bucket" {
  provider = google.destination
  project  = var.destination_project_id
  name     = var.destination_bucket_name
  location = var.destination_bucket_location
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "destination_bucket_permissions" {
  for_each = toset(["roles/storage.objectAdmin", "roles/storage.legacyBucketWriter"])
  provider = google.destination
  bucket   = google_storage_bucket.destination_bucket.name
  role     = each.key
  member   = "serviceAccount:${data.google_storage_transfer_project_service_account.transfer_sa.email}"
}

# 6. Storage Transfer Job (Cross-Bucket Replication)
resource "google_storage_transfer_job" "cross_project_transfer" {
  provider    = google.source
  project     = var.source_project_id
  description = "Cross-bucket replication from ${var.source_bucket_name} to ${var.destination_bucket_name}"

  replication_spec {
    gcs_data_source {
      bucket_name = google_storage_bucket.source_bucket.name
    }
    gcs_data_sink {
      bucket_name = google_storage_bucket.destination_bucket.name
    }
    transfer_options {
      overwrite_when = "DIFFERENT"
    }
  }

  status = "ENABLED"

  # Ensure all permissions are live before attempting to create the replication job
  depends_on = [
    google_project_service.pubsub_api,
    google_project_iam_member.transfer_sa_pubsub_editor,
    google_project_iam_member.gcs_sa_pubsub_publisher,
    google_storage_bucket_iam_member.source_bucket_permissions,
    google_storage_bucket_iam_member.destination_bucket_permissions,
  ]
}
