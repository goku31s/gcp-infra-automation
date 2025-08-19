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
    bucket = "powerful-bounty-469218-q0-tfstate" 
    prefix = "terraform/state"                 
  }
}

provider "google" {
  project = "powerful-bounty-469218-q0"
  region  = "us-central1"
}

provider "google-beta" {
  project = "powerful-bounty-469218-q0"
  region  = "us-central1"
}
