terraform {
  backend "s3" {
    bucket       = "terraform-state-demo-eks"
    key          = "terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
