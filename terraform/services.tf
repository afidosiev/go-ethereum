provider "kubernetes" {
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks.name]
  }
}

resource "kubernetes_namespace_v1" "geth_namespace" {
  metadata {
    name = "geth-devnet"
    labels = {
      app = "geth-devnet"
    }
  }

}

resource "kubernetes_stateful_set_v1" "geth_sts" {
  depends_on = [kubernetes_namespace_v1.geth_namespace]

  metadata {
    name = "geth-devnet"
    labels = {
      app = "geth-devnet"
    }
    namespace = "geth-devnet"
  }

  spec {
    service_name = "geth-devnet"
    replicas     = 1

    selector {
      match_labels = {
        app = "geth-devnet"
      }
    }
    template {
      metadata {
        labels = {
          app = "geth-devnet"
        }
      }
      spec {
        node_selector = {
          "eks.amazonaws.com/nodegroup" : aws_eks_node_group.services_node_group.node_group_name
        }

        init_container {
          name = "init-copy-data"
          image = "afidosiev/geth:latest_contracts"
          image_pull_policy = "IfNotPresent"
          command = ["/bin/sh", "-c"]
          args = [ "cp -r /root/.ethereum/* /geth-data/ && echo 'Data copied'" ]

          volume_mount {
            name       = "geth-data"
            mount_path = "/geth-data"
          }
        }

        container {
          name              = "geth"
          image             = "afidosiev/geth:latest_contracts"
          image_pull_policy = "IfNotPresent"
          args = [
            "--dev",
            "--http",
            "--http.addr",
            "0.0.0.0",
            "--datadir",
            "/root/.ethereum",
            "--dev.period",
            "12"
          ]
          resources {
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
            limits = {
              memory = "512Mi"
            }
          }
          port {
            container_port = 8545
          }

          volume_mount {
            name       = "geth-data"
            mount_path = "/root/.ethereum"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "geth-data"
        labels = {
          app = "geth-devnet"
        }
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = "8Gi"
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "geth_headless" {
  depends_on = [
    kubernetes_namespace_v1.geth_namespace,
    kubernetes_storage_class_v1.gp3_sc
  ]
  metadata {
    name = "geth-devnet"
    labels = {
      app = "geth-devnet"
    }
    namespace = "geth-devnet"
  }
  spec {
    cluster_ip = "None"
    selector = {
      app = "geth-devnet"
    }
    port {
      port        = 8545
      target_port = 8545
    }
  }
}
