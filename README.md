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
- **API Gateway**: To be implemented
- **Authentication**: JWT

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Node.js 18+ or Python 3.10+
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
docker-compose up -d

# Start with Kafka (optional)
docker-compose --profile kafka up -d
```

5. Set up the database:
```bash
# Database migrations will be added later
```

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

## Contributing

1. Create a feature branch
2. Make your changes
3. Write tests
4. Submit a pull request

## License

To be determined
