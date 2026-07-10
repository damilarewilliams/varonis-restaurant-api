# Teardown

Ordered decommissioning with guardrails. Run as your admin AWS identity
(not the CI role). **The guardrail is reading the destroy plan.**

## 1. Remove Kubernetes-created AWS resources first

Terraform can't delete what isn't in its state. If the Load Balancer
Controller ever created an ALB for the Ingress, it will block VPC
deletion:

```bash
kubectl -n argocd delete application varonis-restaurant-api-dev
kubectl -n restaurant-api delete ingress --all --ignore-not-found
# wait for the ALB to disappear from EC2 > Load Balancers
```

## 2. Empty ECR (force_delete=false will refuse otherwise — by design)

```bash
aws ecr batch-delete-image --repository-name varonis-restaurant-api-dev \
  --image-ids "$(aws ecr list-images --repository-name varonis-restaurant-api-dev \
  --query 'imageIds' --output json)"
```

## 3. Destroy — plan first, apply the reviewed plan

```bash
cd terraform/environments/dev
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan | less        # READ IT
terraform apply destroy.tfplan
```

Expected notes: KMS keys enter their 7-day deletion window (recoverable,
unbilled while pending) — not an error. If dev ever re-enabled DynamoDB
deletion protection, flip it off and re-plan.

## 4. Delete the state bucket (last — it ran the destroy)

```bash
aws s3api delete-objects --bucket varonis-restaurant-api-tfstate \
  --delete "$(aws s3api list-object-versions --bucket varonis-restaurant-api-tfstate \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)"
aws s3 rb s3://varonis-restaurant-api-tfstate
```

## 5. GitHub cleanup

Revoke the ARC PAT; delete environments `dev-infra`/`dev-infra-plan` and
the four Actions variables (`gh variable delete ...`).

## 6. Prove it's gone (the default_tags payoff)

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=varonis-restaurant-api --output table
```

Empty output = nothing left billing. Big meters to confirm dead: EKS
(~$73/mo), NAT (~$32/mo), interface endpoints, any ALB.
