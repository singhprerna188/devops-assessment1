# DevOps Assessment: Terraform + Database Reliability

Hotel bookings platform: AWS infrastructure design in Terraform (ALB → ECS/Fargate → RDS,
private RDS, dev/prod environments) plus a local PostgreSQL setup for schema, seed data,
query optimization, and backup/restore.

> Actual AWS deployment is **not** required and was not performed. Terraform is validated
> via `fmt` / `init` / `validate` / `plan` only. Database tasks run fully locally via Docker
> Compose.

## Repository layout

```
infra/
  modules/
    network/   # VPC, public+private subnets, IGW, NAT, ALB/ECS/RDS security groups
    ecs/       # ALB, target group, ECS cluster, Fargate task definition + service, IAM roles
    rds/       # RDS instance (private, encrypted) + subnet group
  envs/
    dev/       # small instance, 3-day backups, deletion protection off
    prod/      # larger instance, 30-day backups, deletion protection on, multi-AZ
.github/workflows/terraform.yml   # fmt/init/validate/plan on PRs, posts plan as PR comment
docker-compose.yml                 # local Postgres for Part 4-6
db/migrations/001_init.sql         # schema + indexes
db/seed/seed.sql                   # seed data (140 bookings, 6 cities, 6 orgs, 5 statuses)
scripts/backup.sh                  # timestamped pg_dump
scripts/restore.sh                 # restore into a fresh database + verification
```

---

## Part 1-2: Terraform infrastructure

Architecture: `Internet → ALB (public subnets) → ECS/Fargate (private subnets) → RDS (private subnets)`.

- **Network module**: VPC with public + private subnets across multiple AZs, one Internet
  Gateway, one NAT Gateway (for ECS tasks to reach ECR/the internet from private subnets),
  and three security groups:
  - `alb-sg`: allows 80/443 from `0.0.0.0/0`.
  - `ecs-sg`: allows the container port **only** from `alb-sg`.
  - `rds-sg`: allows the DB port **only** from `ecs-sg`. RDS has `publicly_accessible = false`
    and sits in the private subnets — it is not reachable from the internet or from anything
    other than the ECS tasks.
- **RDS module**: single instance, encrypted storage, environment-driven backup retention,
  deletion protection, and Multi-AZ.
- **ECS module**: ALB + target group + HTTP listener, ECS cluster (Container Insights on),
  Fargate task definition/service in `awsvpc` mode with `assign_public_ip = false`, task
  execution role (ECR pulls + CloudWatch Logs) and a separate (currently empty-permission)
  task role for the app itself. Container image defaults to `nginx:latest` as a placeholder.

Two environments share the same modules, differing only in sizing/policy via `*.tfvars`:

| Setting | dev | prod |
|---|---|---|
| DB instance class | `db.t3.micro` | `db.r6g.large` |
| DB backup retention | 3 days | 30 days |
| Deletion protection | `false` | `true` |
| Multi-AZ | `false` | `true` |
| ECS desired count | 1 | 3 |
| Task CPU/memory | 256/512 | 1024/2048 |

Each environment also has its own `backend.tf` (separate S3 key + DynamoDB lock table per
environment) so dev and prod state can never collide.

### Validating locally

```bash
cd infra/envs/dev
terraform init -backend=false     # skip remote state; enough for fmt/validate/plan review
terraform fmt -check -recursive ../../..
terraform validate
terraform plan -var-file="dev.tfvars" -var="db_password=local-plan-only"
```

Repeat in `infra/envs/prod` with `prod.tfvars` (prod's `db_password` has no default on
purpose — it must be supplied via `TF_VAR_db_password` or a secrets manager, never
committed).

## Part 3: Terraform plan in CI (optional — implemented)

`.github/workflows/terraform.yml` runs on every PR that touches `infra/**`, as a matrix over
`dev` and `prod`. For each environment it runs `fmt -check`, `init -backend=false` (so the
workflow needs no real AWS credentials), `validate`, and `plan -var-file=<env>.tfvars`, then
posts the plan output as a PR comment and uploads it as a workflow artifact. The job fails if
`validate` or `plan` fails.

---

## Part 4: Local database

```bash
docker compose up -d
docker compose ps          # wait for db to report "healthy"
```

Postgres 16 starts with `hotel_bookings` already created, and automatically runs
`db/migrations/001_init.sql` then `db/seed/seed.sql` on first boot (via
`docker-entrypoint-initdb.d`), so the database is fully seeded as soon as the container is
healthy — no extra step needed.

Connection details: `localhost:5432`, db `hotel_bookings`, user `app_admin`, password
`app_password` (local dev only — see `docker-compose.yml`).

To connect directly:
```bash
docker exec -it hotel-bookings-db psql -U app_admin -d hotel_bookings
```

## Part 5: Seed data and indexing

`db/seed/seed.sql` inserts **140** rows into `hotel_bookings` (over the required 100) across:
- 6 cities: `delhi, mumbai, bengaluru, hyderabad, chennai, pune`
- 6 organizations (`org_id`)
- 5 statuses: `confirmed, cancelled, pending, completed, refunded`
- ~60% of rows have `created_at` within the last 30 days (so the target query has a
  meaningful, non-trivial result set), the rest older, so the index is actually doing
  filtering work rather than matching everything.
- `booking_events` rows for ~40% of bookings (1-3 events each).

### Query to optimize

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

### Index added

```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

**Why this shape:**
- `city` leads the index because it's an **equality** predicate — Postgres can jump straight
  to the `'delhi'` entries with a B-tree lookup.
- `created_at` is second because it's a **range** predicate (`>= NOW() - INTERVAL '30 days'`).
  Once positioned at `city = 'delhi'`, Postgres can scan a contiguous range of the index
  ordered by `created_at` instead of scanning every `delhi` row ever created.
- `org_id`, `status`, and `amount` are added via `INCLUDE` (not as extra key columns) because
  the query only needs them for `GROUP BY`/aggregation, not for filtering or ordering.
  Including them lets Postgres answer the query as an **index-only scan** — it never has to
  visit the heap (the table itself) for a matching row, as long as the visibility map is
  up to date (`VACUUM` keeps this true in normal operation).
- Without this index, Postgres has to do a **sequential scan** of `hotel_bookings`, evaluating
  `city` and `created_at` on every row, which gets linearly worse as the table grows.

### Verifying it locally

```bash
docker exec -it hotel-bookings-db psql -U app_admin -d hotel_bookings -c \
  "EXPLAIN ANALYZE
   SELECT org_id, status, COUNT(*), SUM(amount)
   FROM hotel_bookings
   WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
   GROUP BY org_id, status;"
```

To see the *before* picture for comparison, temporarily disable the index and re-run:
```sql
DROP INDEX idx_hotel_bookings_city_created_at;
-- re-run the EXPLAIN ANALYZE above: expect "Seq Scan on hotel_bookings"
-- then recreate it:
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
-- re-run again: expect "Index Only Scan using idx_hotel_bookings_city_created_at"
```
With this seed size (140 rows) both plans will be fast in absolute terms — the point is the
plan *shape* (`Seq Scan` vs `Index Only Scan`) and how that gap widens as row count grows
into the thousands/millions in production.

---

## Part 6: Backup and restore

```bash
# Create a timestamped dump of the running database
./scripts/backup.sh
# -> writes ./backups/hotel_bookings_<YYYYMMDD_HHMMSS>.dump (pg_dump custom format)

# Restore that dump into a brand-new database (does not touch the original)
./scripts/restore.sh ./backups/hotel_bookings_20260726_101500.dump
# -> creates/recreates 'hotel_bookings_restore_test' and restores into it
```

### Verifying the restore worked

`restore.sh` automatically prints row counts for both tables after restoring. To verify
manually / more thoroughly:

```bash
# 1. Row counts match the source database
docker exec -it hotel-bookings-db psql -U app_admin -d hotel_bookings -c \
  "SELECT count(*) FROM hotel_bookings;"       # expect 140
docker exec -it hotel-bookings-db psql -U app_admin -d hotel_bookings_restore_test -c \
  "SELECT count(*) FROM hotel_bookings;"       # should match

# 2. Spot-check a specific row's data
docker exec -it hotel-bookings-db psql -U app_admin -d hotel_bookings_restore_test -c \
  "SELECT * FROM hotel_bookings ORDER BY created_at DESC LIMIT 3;"

# 3. Indexes came back too
docker exec -it hotel-bookings-db psql -U app_admin -d hotel_bookings_restore_test -c \
  "\di"   # should list idx_hotel_bookings_city_created_at, idx_booking_events_booking_id

# 4. Foreign key still enforced (booking_events -> hotel_bookings)
docker exec -it hotel-bookings-db psql -U app_admin -d hotel_bookings_restore_test -c \
  "SELECT count(*) FROM booking_events;"
```

If all counts match the source and the query from Part 5 returns identical results against
`hotel_bookings_restore_test`, the restore is verified.

---

## Assumptions / notes

- Real AWS credentials, an S3 backend bucket, and a DynamoDB lock table are **not**
  provisioned here — `backend.tf` documents the expected bucket/table naming per environment,
  and both local validation and CI use `terraform init -backend=false` so `plan` works without
  them.
- `db_password` is never hard-coded for prod (no default — must come from
  `TF_VAR_db_password` / a secrets manager); dev has a placeholder default purely so
  `terraform plan` runs out of the box for local review.
- The ECS container image is a placeholder (`nginx:latest`) per the assignment; swap
  `container_image` in `*.tfvars` for a real application image when deploying for real.
