terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.7.0"
    }
  }
}

provider "docker" {}

resource "docker_network" "lab" {
  name   = var.network_name
  driver = "bridge"

  labels {
    label = "course"
    value = "ict-infrastructures"
  }

  labels {
    label = "managed-by"
    value = "terraform"
  }
}
