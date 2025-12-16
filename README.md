# LessGo 🚗

**Smart Carpooling Platform for University Students**

[![License](https://img.shields.io/badge/License-All%20Rights%20Reserved-red.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-In%20Development-yellow.svg)]()
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-blue.svg)]()

> A safe, intelligent, and cost-effective carpooling solution designed specifically for SJSU students, addressing parking congestion and transportation challenges through ML-enhanced matching and transparent pricing.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Team](#team)
- [Documentation](#documentation)

---

## 🎯 Overview

LessGo tackles the growing transportation challenges at San Jose State University by providing a student-centered ridesharing platform. With increased enrollment leading to overcrowded parking and mounting frustration, LessGo offers an efficient, community-based solution that:

- **Reduces parking congestion** by optimizing vehicle occupancy
- **Saves money** through transparent, fair cost-sharing
- **Ensures safety** with real-time trip monitoring and anomaly detection
- **Builds community** by connecting students with similar schedules and routes

### The Problem

- 🚗 **Overcrowded parking** during peak hours
- 💰 **Expensive rideshare services** with surge pricing
- 🚌 **Unreliable public transit** with limited routes
- ⏰ **Scheduling conflicts** for commuter students

### Our Solution

An intelligent carpooling platform that:
- Matches students based on class schedules and route overlaps
- Implements ML-enhanced grouping for optimal ride matching
- Provides transparent, detour-aware pricing
- Monitors trips in real-time for safety

---

## ✨ Features

### 🎯 Core Features

**For Riders:**
- Smart ride matching based on class schedules
- Real-time ride tracking and ETA updates
- Upfront fare quotes that only decrease as seats fill
- Safety features with emergency contact integration
- Driver rating and review system

**For Drivers:**
- Flexible schedule management
- Automated route optimization
- Fair compensation with minimum guaranteed payout
- Real-time rider notifications
- Trip history and earnings tracking

### 🔒 Safety & Privacy

- **Real-time Safety Monitoring** - Anomaly detection for route deviations
- **Silent Safety Checks** - Discrete rider verification during trips
- **Emergency Alerts** - Automatic contact notification if needed
- **Homomorphic Encryption** - Privacy-preserving route calculations
- **University Verification** - SJSU authentication required

### 🧠 ML-Enhanced Matching

- Machine learning models reduce candidate sets for faster matching
- Representation learning embeds user preferences and constraints
- Reinforcement learning optimizes system-level assignments
- Schedule-aware grouping based on class timetables

### 💰 Fair Cost Allocation

- **Quote Never Increases** - Riders see maximum price upfront
- **Detour-Aware Pricing** - Fair allocation based on actual route impact
- **Transparent Calculations** - Clear breakdown of cost factors
- **Driver Minimum Guarantee** - Stable earnings for drivers

---

## 🏗️ Architecture

LessGo uses a **microservice architecture** for scalability and independence across features.

![System Architecture](docs/images/architecture.png)

### Core Services

| Service | Technology | Purpose |
|---------|-----------|---------|
| **API Gateway** | Node.js, Express | Central entry point, request routing |
| **Authentication** | SJSU SSO Integration | User verification, session management |
| **Grouping Service** | Python, ML Models | Intelligent rider-driver matching |
| **Route Optimization** | Python, OR-Tools | A* and Dijkstra-based route planning |
| **Cost Calculation** | Node.js | Detour-aware, monotonic pricing |
| **Safety Service** | Python | Anomaly detection, silent alerts |
| **Payment Service** | Stripe, PayPal | Secure fund transfers |
| **Notification Service** | Firebase, Twilio | Real-time push and SMS |

### Data Layer

- **PostgreSQL** - User data, trips, bookings, payments
- **MongoDB** - Geospatial data, route information
- **Redis** - Session caching, real-time data
- **Kafka** - Event streaming between services

---

## 🛠️ Tech Stack

### Mobile Applications

**iOS (Swift)**
```
- SwiftUI for modern, declarative UI
- Combine for reactive programming
- CoreLocation for GPS tracking
- MapKit for route visualization
```

**Android (Kotlin)**
```
- Jetpack Compose for UI
- Coroutines for async operations
- Google Maps SDK
- Room for local persistence
```

### Backend Services

```javascript
// Node.js Services
- Express.js - REST API framework
- JWT - Authentication
- Prisma - ORM for PostgreSQL
- Socket.io - Real-time communication

// Python Services
- FastAPI - High-performance API
- PyTorch - ML model serving
- OR-Tools - Route optimization
- Scikit-learn - Data preprocessing
```

### Infrastructure

```yaml
Cloud: AWS (ECS, RDS, ElastiCache)
Containerization: Docker
Orchestration: Kubernetes
CI/CD: GitHub Actions
Monitoring: CloudWatch, Datadog
```

---

## 🚀 Getting Started

### Prerequisites

```bash
- Node.js >= 18.x
- Python >= 3.9
- PostgreSQL >= 14
- Redis >= 6.2
- Docker & Docker Compose
- Xcode (for iOS development)
- Android Studio (for Android development)
```

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/shyam-kannan/SJSU_Ridesharing.git
cd SJSU_Ridesharing
```

2. **Set up environment variables**
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. **Install dependencies**
```bash
# Backend services
cd backend
npm install

# Python services
cd ../services/optimizer
pip install -r requirements.txt --break-system-packages
```

4. **Start services with Docker**
```bash
docker-compose up -d
```

5. **Run database migrations**
```bash
npm run migrate
```

6. **Start development servers**
```bash
# Backend
npm run dev

# iOS App
cd ios && open LessGo.xcworkspace

# Android App
cd android && ./gradlew assembleDebug
```

---

## 📁 Project Structure

```
SJSU_Ridesharing/
├── backend/
│   ├── api-gateway/         # Central API gateway
│   ├── auth-service/        # Authentication
│   ├── grouping-service/    # Matching logic
│   ├── cost-service/        # Pricing algorithms
│   ├── payment-service/     # Payment processing
│   └── notification-service/# Push notifications
├── services/
│   ├── optimizer/           # Route optimization (Python)
│   └── safety/              # Safety monitoring (Python)
├── mobile/
│   ├── ios/                 # Swift iOS app
│   └── android/             # Kotlin Android app
├── shared/
│   ├── types/               # Shared TypeScript types
│   └── proto/               # Protocol buffers
├── docs/
│   ├── api/                 # API documentation
│   ├── architecture/        # System design docs
│   └── images/              # Diagrams and screenshots
├── infrastructure/
│   ├── docker/              # Docker configurations
│   ├── k8s/                 # Kubernetes manifests
│   └── terraform/           # Infrastructure as Code
└── tests/
    ├── unit/
    ├── integration/
    └── e2e/
```

---

## 👥 Team

**SJSU Master's in Software Engineering - CMPE 295**

| Name | Role | GitHub | Email |
|------|------|--------|-------|
| Shyam Kannan | Mobile Frontend Lead | [@shyam-kannan](https://github.com/shyam-kannan) | shyam.kannan@sjsu.edu |
| Spencer Davis | Backend Architecture | - | spencer.davis@sjsu.edu |
| Sri Ram Mannam | ML/Data Engineering | - | sriram.mannam@sjsu.edu |
| Johnny To | Full-Stack Development | - | johnny.to@sjsu.edu |

**Advisor:** Dr. Younghee Park

---

## 📚 Documentation

- [📖 Full Project Report](docs/Final_Report.pdf)
- [📋 Project Workbook](docs/Project_Workbook.pdf)
- [🏗️ Architecture Design](docs/architecture/)
- [🔌 API Documentation](docs/api/)
- [🧪 Testing Strategy](docs/testing/)
- [🚀 Deployment Guide](docs/deployment/)

### Key Academic Contributions

1. **ML-Enhanced Grouping** - Reducing candidate sets while maintaining match quality
2. **Detour-Aware Pricing** - Monotonic cost allocation ensuring quote transparency
3. **Safety Validation** - Real-time anomaly detection and privacy-preserving monitoring
4. **Campus-Specific Optimization** - Tailored for university commute patterns

### Research References

This project builds upon research in:
- Dynamic carpooling systems and matching algorithms
- Fair cost-sharing mechanisms for ride-sharing
- Privacy-preserving mobility services using homomorphic encryption
- Reinforcement learning for sequential assignment decisions

See [References](docs/references.md) for full academic citations.

---

<p align="center">
  <i>Building smarter, safer, and more sustainable campus transportation</i>
</p>
