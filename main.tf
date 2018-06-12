variable region {
  default = "us-east1"
}

variable zone {
  default = "us-east1-b"
}

provider google {
  region = "${var.region}"
}

variable num_nodes {
  default = 3
}

variable cluster_name {
  default = "jamie-terraform"
}

variable k8s_version {
  default = "1.10.4"
}

variable network_name {
  default = "jamie-terraform"
}

# resource "google_compute_network" "default" {
#   name                    = "${var.network_name}"
#   auto_create_subnetworks = "false"
# }

# resource "google_compute_subnetwork" "default" {
#   name                     = "${var.network_name}"
#   ip_cidr_range            = "10.128.0.0/20"
#   network                  = "${google_compute_network.default.self_link}"
#   region                   = "${var.region}"
#   private_ip_google_access = true
# }

module "k8s" {
  source  = "modules/k8s-gce"
  name    = "${var.cluster_name}"
  network = "default"

  region = "${var.region}"

  zone             = "${var.zone}"
  k8s_version      = "${var.k8s_version}"
  compute_image    = "ubuntu-kata"
  access_config    = []
  add_tags         = ["nat-${var.region}"]
  pod_network_type = "calico"
  calico_version   = "2.6"
  cni_version      = "1.1.0"
  num_nodes        = "${var.num_nodes}"
  depends_id       = "${join(",", list(module.nat.depends_id, null_resource.route_cleanup.id))}"
}

module "nat" {
  source  = "github.com/GoogleCloudPlatform/terraform-google-nat-gateway"
  region  = "${var.region}"
  zone    = "${var.zone}"
  network = "default"
}

resource "null_resource" "route_cleanup" {
  // Cleanup the routes after the managed instance groups have been deleted.
  provisioner "local-exec" {
    when    = "destroy"
    command = "gcloud compute routes list --filter='name~k8s-${var.cluster_name}.*' --format='get(name)' | tr '\n' ' ' | xargs -I {} sh -c 'echo Y|gcloud compute routes delete {}' || true"
  }
}
