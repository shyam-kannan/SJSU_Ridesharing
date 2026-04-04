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

4. Start the infrastructure services:
```bash
# Start PostgreSQL and Redis
docker compose up -d

# Start with Kafka (optional)
docker compose --profile kafka up -d
```

5. Set up the database:
```bash
# Apply migrations
npm run migrate:up

# Optional: seed demo data on a fresh/empty DB only
# Warning: this seed clears existing app data in key tables first
npm run seed
```

If your Supabase database has already been seeded once, skip `npm run seed`.

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
2. Pushes images to your dedicated container image repository
3. Deploys the SHA-tagged images to GKE Autopilot

Configure these GitHub repository variables:

- `IMAGE_REGISTRY` (example: `ghcr.io`)
- `IMAGE_REPOSITORY` (example: `your-org/lessgo-images`)
- `GCP_PROJECT_ID`
- `GKE_CLUSTER`
- `GKE_LOCATION`

Configure these GitHub repository secrets:

- `IMAGE_REGISTRY_USERNAME`
- `IMAGE_REGISTRY_TOKEN`
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

- `${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/api-gateway:${GITHUB_SHA}`
- `${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/auth-service:${GITHUB_SHA}`
- ...and so on for each service.

If your image repository is private, create a Kubernetes image pull secret in your cluster namespace and attach it to the service accounts used by your deployments.

## Contributing

1. Create a feature branch
2. Make your changes
3. Write tests
4. Submit a pull request

## License

To be determined
