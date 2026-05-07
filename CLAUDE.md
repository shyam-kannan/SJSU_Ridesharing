# LessGo - Claude Context

This file provides context for Claude Code to understand the project quickly without wasting tokens exploring the repository.

## Quick Context

**Project:** SJSU Ridesharing - A ridesharing application for San Jose State University students

**Architecture:**
- iOS frontend (Swift/SwiftUI) in `LessGo/` directory
- Backend microservices (TypeScript/Node.js) in `services/` directory
- PostgreSQL database hosted on Supabase (project: bdefyxdpojqxxvaybfwk)
- ML matching pipeline using RShareForm embeddings

**Current Work:** Posted Rides Feature (Phase 2 Complete ✅)

## Memory System

The project has a memory system at `memory/` that stores important context. When starting a new session, Claude should:

1. **Load memory:** Read `memory/MEMORY.md` to get the index
2. **Load relevant memory files:** Based on the task, load specific memory files
3. **Update memory:** After each phase, update memory with new findings

**Available Memory Files:**
- `memory/repo_overview.md` - Comprehensive repository overview

## Key Information for New Sessions

### Database
- **Supabase Project ID:** `bdefyxdpojqxxvaybfwk`
- **Region:** us-east-1
- **Migration Process:** `npm run bootstrap:db`
- **Latest Migration:** `020_enhance_trip_booking_flow.sql` (Phase 1)

### Backend Services
- **API Gateway:** Port 3000
- **Auth Service:** Port 3001
- **User Service:** Port 3002
- **Trip Service:** Port 3003
- **Booking Service:** Port 3004
- **Payment Service:** Port 3005
- **Notification Service:** Port 3006
- **Cost Calculation Service:** Port 3009

### New Features (Phase 1 & 2)
- **BookingState enum:** pending, approved, rejected, cancelled, completed
- **New API endpoints:**
  - `PATCH /api/bookings/:id/approve` - Driver approves booking
  - `PATCH /api/bookings/:id/reject` - Driver rejects booking
- **Enhanced search:** Pagination with limit/offset parameters
- **SJSU validation:** Trips must connect to SJSU (37.3352, -122.8811, ~0.5 mile radius)
- **iOS Rider UI:** RiderSearchResultsView and TripDetailView for posted rides search
- **Booking polling:** Auto-refresh booking state every 3 seconds

### iOS App Structure
- **RiderHomeView:** Map with TO/FROM SJSU selection, "Search Rides" button
- **RiderSearchResultsView:** List of matching posted trips with pagination (NEW - Phase 2)
- **TripDetailView:** Trip details with booking functionality and status polling (NEW - Phase 2)
- **DriverHomeView:** Availability toggle, posted rides list
- **CreateTripView:** Multi-step trip creation (already exists)
- **DriverTripDetailView:** Already exists in Lists tab (needs updates for Phase 3)

### Testing
- **Run tests:** `npm run test`
- **Specific tests:** `npm run test tests/unit/booking-approval-flow.test.ts`
- **Bootstrap DB:** `npm run bootstrap:db`

### Common Patterns
- **Authentication:** JWT tokens via Authorization header
- **Error handling:** AppError class with status codes
- **Geospatial queries:** PostGIS with ST_DWithin, ST_Distance
- **Notifications:** In-app + email via notification service

## How to Use This File

When starting a new session:

1. **Read this file** to get quick context
2. **Load memory files** based on the task:
   - For repo overview: `memory/repo_overview.md`
3. **Update memory** after each phase with new findings

## Session Start Checklist

When starting a new session on this project:

1. Load `memory/MEMORY.md` to see available memory
2. Load `memory/repo_overview.md` for repository context
3. Check `POSTED_RIDES_IMPLEMENTATION_PLAN.md` for current implementation status
4. Check `SETUP.md` for setup instructions
5. Check git status to see what's changed

## Important Notes

- **Supabase:** Database is hosted on Supabase, not local
- **ML Matching:** Uses RShareForm embeddings for trip ranking
- **Chat:** Already implemented, reuse for rider-driver communication
- **SJSU Requirement:** All trips must connect to SJSU campus
- **On-Demand Matching:** Still exists for backward compatibility, being deprecated

## Recent Changes (Phase 1)

### Database
- Added `featured`, `max_riders` columns to trips table
- Added `booking_state` column to bookings table
- Created index on booking_state

### Backend
- Enhanced trip search with pagination
- Added booking approval/reject endpoints
- Added SJSU location validation
- Updated booking creation to set pending state

### Tests
- Added tests for booking approval flow
- Added tests for enhanced search endpoint
