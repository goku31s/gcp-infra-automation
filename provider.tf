terraform {
  required_version = ">= 1.4.4"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.69.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.69.0"
    }
  }

  backend "gcs" {
    bucket = "academic-project-469620" 
    prefix = "terraform/state"                 
  }
}

provider "google" {
  project = "academic-project-469620"
  region  = "us-central1"
}

provider "google-beta" {
  project = "academic-project-469620"
  region  = "us-central1"
}
