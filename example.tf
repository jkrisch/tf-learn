#configure to k8s provider
provider "kubernetes" {
    config_context_auth_info = "ops"
    config_context_cluster = "mycluster"
}

resource "kubernetes-namespace" "example" {
    metadata {
        name = "my-first-namespace"
    }
}