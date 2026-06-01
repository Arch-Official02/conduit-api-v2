# Conduit API — DevOps Pipeline

> A production-grade Node.js REST API with a fully automated CI/CD pipeline, Infrastructure as Code, and real-time observability — built as a work/internship DevOps engineering project.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Getting Started](#getting-started)
- [Running Tests](#running-tests)
- [Docker](#docker)
- [CI/CD Pipeline](#cicd-pipeline)
- [Infrastructure (Terraform)](#infrastructure-terraform)
- [Monitoring](#monitoring)
- [API Endpoints](#api-endpoints)
- [Project Structure](#project-structure)
- [Author](#author)

---

## Project Overview

This project takes the [RealWorld Conduit API](https://github.com/gothinkster/realworld) — a feature-complete REST API spec modelling a blogging platform similar to Medium — and wraps it in a full DevOps pipeline from local development to live AWS deployment.

The application exposes endpoints for:
- User registration and JWT authentication
- Article creation, editing, and deletion
- Comments and favorites
- User profiles and following
- Tag aggregation

The DevOps work covers five phases:

| Phase | Focus |
|-------|-------|
| 1 | Application modernisation and testing |
| 2 | Containerisation with Docker |
| 3 | CI/CD pipeline with GitHub Actions |
| 4 | Infrastructure as Code with Terraform |
| 5 | Monitoring with Prometheus and Grafana |

---

## Architecture

```
Internet
    │
    ▼
Application Load Balancer (port 80)
    │
    ▼
EC2 t3.medium — us-east-1 (Docker host)
    ├── conduit-api:latest   (port 3000)  ← Node.js REST API
    ├── mongo:4.4            (port 27017) ← MongoDB database
    ├── prometheus           (port 9090)  ← metrics collection
    └── grafana              (port 3001)  ← dashboards
```

### AWS Resources (provisioned via Terraform)

- VPC with public subnets across 2 availability zones
- Internet Gateway and route tables
- Application Load Balancer with health checks on `/api/tags`
- EC2 instance with IAM role for ECR access (no hardcoded credentials)
- Security groups following least-privilege principle
- Amazon ECR repository for Docker images

---

## Technology Stack

| Category | Technology |
|----------|-----------|
| Runtime | Node.js 20 LTS |
| Framework | Express 4.x |
| Database | MongoDB 4.4 + Mongoose 4.4 |
| Testing | Jest 30 + Supertest 7 |
| Containerisation | Docker + Docker Compose |
| Container Registry | Amazon ECR |
| CI/CD | GitHub Actions |
| Infrastructure as Code | Terraform 1.14 |
| Cloud | AWS (EC2, ALB, VPC, ECR, IAM) |
| Metrics | Prometheus + prom-client |
| Dashboards | Grafana |

---

## Getting Started

### Prerequisites

- Node.js 20+
- Docker Desktop
- Git

### Clone and Install

```bash
git clone https://github.com/Arch-Official02/conduit-api.git
cd conduit-api
npm install
```

### Environment Variables

Create a `.env` file in the root directory:

```env
MONGODB_URI=mongodb://localhost/conduit
PORT=3000
NODE_ENV=development
```

### Start MongoDB

```bash
docker run --name realworld-mongo -p 27017:27017 -d mongo:4.4
```

> **Note:** MongoDB must be pinned to version 4.4. The application uses Mongoose 4.4 which is incompatible with MongoDB 5+.

### Start the Application

```bash
npm start
```

The API will be available at `http://localhost:3000`

Test it:

```bash
curl http://localhost:3000/api/tags
# returns: {"tags":[]}
```

---

## Running Tests

The test suite uses Jest and Supertest with 22 test cases covering all API endpoints.

```bash
# Make sure MongoDB is running first
npm test
```

Expected output:

```
PASS  tests/jest/app.test.js
  Tags
    ✓ GET /api/tags — returns 200 and tags array
  Auth
    ✓ POST /api/users — register a new user
    ✓ POST /api/users/login — login and receive token
    ...
Tests: 22 passed, 22 total
```

> Tests use a timestamp-based unique user on every run (`testuser${Date.now()}`) so no database cleanup is needed between runs.

---

## Docker

### Build and Run with Docker Compose

```bash
docker-compose up --build
```

This starts two containers:
- `app` — the Node.js API on port 3000
- `mongo` — MongoDB 4.4 on port 27017

### Verify

```bash
curl http://localhost:3000/api/tags
curl http://localhost:3000/api/articles
```

### Stop

```bash
docker-compose down
```

---

## CI/CD Pipeline

The GitHub Actions pipeline (`.github/workflows/ci.yml`) triggers on every push to `main` and runs three jobs in sequence:

```
Push to main
      │
      ▼
Job 1: Run Jest Tests (22 tests against MongoDB 4.4)
      │  fails here → pipeline stops, nothing deploys
      ▼
Job 2: Build and Push to ECR
      │  tags image with :SHA and :latest
      ▼
Job 3: Deploy to EC2
       finds instance by Name tag → reboots it
       EC2 pulls new :latest image on startup
```

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |

### Image Tagging Strategy

Every successful build pushes two tags to ECR:

- `:d3e31efc22...` — immutable SHA tag, traceable to the exact commit
- `:latest` — always points to the newest build, used by EC2 on startup

---

## Infrastructure (Terraform)

All AWS infrastructure is defined as code in the `terraform/` directory.

### Structure

```
terraform/
  main.tf              # root module
  variables.tf         # input variables
  outputs.tf           # ALB DNS, EC2 IP, instance ID
  terraform.tfvars     # actual values (gitignored)
  modules/
    vpc/               # VPC, subnets, IGW, route tables
    security-groups/   # ALB and EC2 security groups
    alb/               # load balancer, target group, listener
    ec2/               # IAM role, instance, userdata bootstrap
```

### Deploy Infrastructure

```bash
# Configure AWS credentials
aws configure

# Initialise Terraform
cd terraform
terraform init

# Preview changes
terraform plan

# Apply
terraform apply
```

### Outputs

```
alb_dns_name    = "conduit-alb-xxx.us-east-1.elb.amazonaws.com"
ec2_instance_id = "i-xxxxxxxxxxxxxxxxx"
ec2_public_ip   = "x.x.x.x"
```

### Destroy

```bash
terraform destroy
```

> Always run `terraform destroy` when done to avoid unnecessary AWS charges.

### terraform.tfvars (required, not committed)

```hcl
aws_region   = "us-east-1"
project_name = "conduit"
vpc_cidr     = "10.0.0.0/16"
ecr_repo_url = "707417410763.dkr.ecr.us-east-1.amazonaws.com/conduit-api"
secret       = "your-jwt-secret"
key_name     = "conduit-key"
```

---

## Monitoring

Prometheus and Grafana run alongside the application on the same EC2 instance.

### Access

| Tool | URL |
|------|-----|
| Prometheus | `http://<EC2_PUBLIC_IP>:9090` |
| Grafana | `http://<EC2_PUBLIC_IP>:3001` |

Grafana credentials: `admin / conduit123`

### Metrics Exposed

The application exposes a `/metrics` endpoint via `prom-client`:

```bash
curl http://localhost:3000/metrics
```

Prometheus scrapes this endpoint every 15 seconds. Key metrics:

| Metric | Description |
|--------|-------------|
| `http_request_duration_ms` | Request duration histogram by method, route, status |
| `process_cpu_seconds_total` | CPU usage |
| `process_resident_memory_bytes` | Memory usage |
| `nodejs_eventloop_lag_seconds` | Event loop lag |

### Grafana Dashboard Queries

| Panel | Query |
|-------|-------|
| Request Rate | `rate(http_request_duration_ms_count{job="conduit-api"}[1m])` |
| 95th Percentile Response Time | `histogram_quantile(0.95, rate(http_request_duration_ms_bucket[5m]))` |
| CPU Usage | `rate(process_cpu_seconds_total{job="conduit-api"}[1m]) * 100` |
| Error Rate | `rate(http_request_duration_ms_count{status=~"4..\|5.."}[1m])` |

---

## API Endpoints

### Public (no token required)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tags` | Get all tags |
| GET | `/api/articles` | List all articles |
| GET | `/api/articles/:slug` | Get single article |
| GET | `/api/profiles/:username` | Get user profile |

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/users` | Register new user |
| POST | `/api/users/login` | Login and get JWT token |

### Protected (token required)

Add header: `Authorization: Token <your_token>`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/user` | Get current user |
| PUT | `/api/user` | Update current user |
| POST | `/api/articles` | Create article |
| PUT | `/api/articles/:slug` | Update article |
| DELETE | `/api/articles/:slug` | Delete article |
| POST | `/api/articles/:slug/favorite` | Favorite article |
| DELETE | `/api/articles/:slug/favorite` | Unfavorite article |
| GET | `/api/articles/:slug/comments` | Get comments |
| POST | `/api/articles/:slug/comments` | Add comment |
| DELETE | `/api/articles/:slug/comments/:id` | Delete comment |
| POST | `/api/profiles/:username/follow` | Follow user |
| DELETE | `/api/profiles/:username/follow` | Unfollow user |
| GET | `/api/articles/feed` | Get followed users' articles |

### Example: Full Flow

```bash
# Register
curl -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"user":{"username":"stephen","email":"stephen@example.com","password":"password123"}}'

# Login
curl -X POST http://localhost:3000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"stephen@example.com","password":"password123"}}'

# Create article (replace TOKEN with value from login response)
curl -X POST http://localhost:3000/api/articles \
  -H "Content-Type: application/json" \
  -H "Authorization: Token TOKEN" \
  -d '{"article":{"title":"My Article","description":"About DevOps","body":"Content here","tagList":["devops","aws"]}}'

# Get all articles
curl http://localhost:3000/api/articles
```

---

## Project Structure

```
conduit-api/
  app.js                          # Express app entry point
  package.json                    # dependencies and scripts
  Dockerfile                      # Docker image definition
  docker-compose.yml              # local development stack
  .dockerignore                   # Docker build exclusions
  .gitignore
  config/
    index.js                      # JWT secret config
    passport.js                   # passport authentication
  models/
    User.js                       # user schema + auth methods
    Article.js                    # article schema
    Comment.js                    # comment schema
  routes/
    index.js                      # route registration
    auth.js                       # JWT middleware
    api/
      users.js                    # auth endpoints
      articles.js                 # article endpoints
      profiles.js                 # profile endpoints
      tags.js                     # tags endpoint
  tests/
    jest/
      app.test.js                 # 22 Jest + Supertest tests
  terraform/
    main.tf
    variables.tf
    outputs.tf
    terraform.tfvars              # gitignored
    modules/
      vpc/
      security-groups/
      alb/
      ec2/
        main.tf
        userdata.sh               # EC2 bootstrap script
  .github/
    workflows/
      ci.yml                      # GitHub Actions pipeline
```

---

## Author

**Feyijimi Stephen O**
GitHub: [@Arch-Official02](https://github.com/Arch-Official02)
Project: [conduit-api](https://github.com/Arch-Official02/conduit-api)

---

> Built as a DevOps engineering work project — May 2026
