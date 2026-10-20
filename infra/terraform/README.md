# Infrastructure — Terraform

See [ADR-0006](../../docs/adr/0006-serverless-aws.md) for why Terraform, and
[`docs/DELIVERY_PLAN.md`](../../docs/DELIVERY_PLAN.md) (Track A) for how this
is sequenced.

```
bootstrap/        One-time per AWS account. Creates the S3 state bucket,
                   the DynamoDB lock table, and the GitHub Actions OIDC
                   deploy role. Uses local state (see below).
modules/          Reusable building blocks (dynamodb-table, ...).
environments/     dev/ staging/ prod/ — one directory per environment,
                   each with its own S3 backend key and tfvars. Directories
                   rather than Terraform CLI workspaces, so each
                   environment can later point at a separate AWS account
                   without restructuring, and so prod's state is never one
                   `terraform workspace select` away from an accident.
```

## First-time setup (one AWS account)

1. **Apply bootstrap.** This has no remote backend — it creates the thing
   remote backends depend on — so its state is local only:

   ```sh
   cd infra/terraform/bootstrap
   terraform init
   terraform apply \
     -var="github_repository=<org>/<repo>" \
     -var='github_deploy_branches=["main"]'
   ```

   Save the resulting `terraform.tfstate` somewhere durable and
   access-controlled (it is the only record of these resources' IDs) —
   e.g. encrypt it into a password manager, or move it into a
   separately-created, out-of-band S3 bucket. Do not commit it.

2. **Generate each environment's backend config** from bootstrap's
   outputs:

   ```sh
   terraform output -raw state_bucket   # -> tapid-terraform-state-<account-id>
   terraform output -raw lock_table     # -> tapid-terraform-lock
   ```

   For each of `environments/{dev,staging,prod}/`, create a
   `backend.hcl` (git-ignored — see root `.gitignore`):

   ```hcl
   bucket = "tapid-terraform-state-<account-id>"
   region = "us-east-1"
   ```

3. **Wire up CI.** Set the `github_actions_deploy_role_arn` output as the
   `AWS_DEPLOY_ROLE_ARN` secret (or GitHub Environment secret, once
   per-environment approval gates matter) so Actions can assume it via
   OIDC — no long-lived AWS keys in the repo.

## Working in an environment

```sh
cd infra/terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## CI

`terraform fmt -check`, `terraform validate`, and `terraform test` run
credential-free (module tests use `mock_provider`, so they never touch
real AWS) — see `.github/workflows/terraform.yml`. A real `plan`/`apply`
against an environment requires the deploy role above and currently
happens by hand; wiring that into CI is tracked for a later PR once
there's more than one resource to deploy.
