# LessGo - Carpooling Backend

A microservices-based backend system for the LessGo carpooling platform.

## Architecture

This project uses a microservices architecture with the following services:

- **API Gateway**: Main entry point for all client requests
- **Auth Service**: Handles authentication and authorization
- **User Service**: Manages user profiles and preferences
- **Trip Service**: Handles trip creation, management, and tracking
- **Booking Service**: Manages booking requests and confirmations
- **Payment Service**: Processes payments and transactions
- **Notification Service**: Sends notifications via email, SMS, and push
- **Grouping Service**: Handles carpool group formation and optimization
- **Routing Service**: Calculates optimal routes and waypoints
- **Safety Service**: Manages safety features and emergency protocols

## Tech Stack

- **Languages**: Node.js/TypeScript, Python
- **Database**: PostgreSQL with PostGIS
- **Cache**: Redis
- **Message Queue**: Kafka (optional)
- **API Gateway**: Node.js/Express service
- **Authentication**: JWT

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Node.js 22+ and Python 3.10+
- Git

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd lessgo-backend
```

2. Copy the environment file:
```bash
cp .env.example .env
```

3. Update the `.env` file with your actual configuration values.

4. Start Redis locally:
```bash
docker compose up -d
```

5. Set up the database through the bootstrap script:
```bash
# Migrations only
npm run bootstrap:db

# Fresh database only: migrations + seed demo data
npm run bootstrap:db -- --fresh
```

If your Supabase database has already been seeded once, skip the `--fresh` run.

## Project Structure

```
lessgo-backend/
├── docs/                      # Documentation
│   ├── requirements/          # Requirements and specifications
│   └── api/                   # API documentation
├── services/                  # Microservices
│   ├── api-gateway/          # API Gateway service
│   ├── auth-service/         # Authentication service
│   ├── user-service/         # User management service
│   ├── trip-service/         # Trip management service
│   ├── booking-service/      # Booking management service
│   ├── payment-service/      # Payment processing service
│   ├── notification-service/ # Notification service
│   ├── grouping-service/     # Carpool grouping service
│   ├── routing-service/      # Route calculation service
│   └── safety-service/       # Safety features service
├── shared/                    # Shared code and utilities
│   ├── database/             # Database schemas and migrations
│   ├── utils/                # Shared utility functions
│   └── types/                # Shared type definitions
├── scripts/                   # Utility scripts
└── tests/                     # Tests
    ├── integration/          # Integration tests
    └── load/                 # Load tests
```

> Legacy cleanup note: the top-level [db/migrations/](db/migrations/) SQL snapshots are not used by the current npm migration workflow (`shared/database/migrations/` is the source of truth) and can be taken down after you confirm you no longer need the older SQL history.

## Development

Each service is independent and can be developed separately. See individual service README files for specific development instructions.

## Testing

```bash
# Run integration tests
npm run test:integration

# Run load tests
npm run test:load
```

## CI/CD Image Publishing and Deployment

The workflow [`.github/workflows/cd-autopilot.yml`](.github/workflows/cd-autopilot.yml) now:

1. Builds all service images (API gateway + 10 microservices)
2. Pushes images to Google Artifact Registry
3. Tags each image with both the commit SHA and `latest`

Configure these GitHub repository variables:

- `GCP_PROJECT_ID`
- `AR_REPO_NAME`
- `AR_LOCATION`

Configure these GitHub repository secrets:

- `GCP_WIF_PROVIDER`
- `GCP_DEPLOYER_SA`
- `DATABASE_URL`
- `JWT_SECRET`
- `GOOGLE_MAPS_API_KEY`
- `STRIPE_SECRET_KEY`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASS`
- `FROM_EMAIL`

Image naming format:

- `${AR_LOCATION}-docker.pkg.dev/${GCP_PROJECT_ID}/${AR_REPO_NAME}/api-gateway:${GITHUB_SHA}`
- `${AR_LOCATION}-docker.pkg.dev/${GCP_PROJECT_ID}/${AR_REPO_NAME}/auth-service:${GITHUB_SHA}`
- ...and so on for each service.

If you later deploy these images to Kubernetes, create an image pull secret in the target namespace if the repository is private.

## GKE Deployment

The manifests in [k8s-manifests/](k8s-manifests/) now point to the Artifact Registry images and keep service-to-service traffic on Kubernetes DNS names such as `http://auth-service:3001`.

Recommended rollout order:

1. Create the namespace, config map, and secret resources.
2. Apply the service deployments.
3. Expose `api-gateway` through a `LoadBalancer` service and use the assigned external IP directly.

Example:

```bash
kubectl apply -f k8s-manifests/namespace.yaml
kubectl apply -f k8s-manifests/configmap.yaml
# Apply your secret manifest here if you keep one outside the repo
kubectl apply -f k8s-manifests/
kubectl -n lessgo get svc api-gateway -o wide
```

For the iOS app, set `LESSGO_API_BASE_URL` to the public API gateway URL, for example `http://<EXTERNAL-IP>/api`. The app reads that override from `APIConfig` and falls back to `http://127.0.0.1:3000/api` in the simulator.

## Contributing

1. Create a feature branch
2. Make your changes
3. Write tests
4. Submit a pull request

## License

To be determined
