# Safety Service

## Purpose

The Safety Service is responsible for monitoring active rides in real time to ensure the safety of riders. It continuously tracks ride progress against the planned route and vehicle speed, detects anomalies, and notifies the relevant parties when something unexpected occurs.

## Core Responsibilities

- Monitor the live location of ongoing rides
- Detect route deviations beyond a fixed distance threshold
- Detect speed anomalies based on road type and posted speed limits
- Send real-time alerts to riders and drivers when anomalies are detected
- Allow riders to acknowledge or dismiss alerts
- Log all anomaly events for auditing and review

---

## Anomaly Detection

### Route Deviation
A route deviation is triggered when a vehicle's current position exceeds a fixed distance threshold from the planned route. The threshold will be configurable per deployment environment (e.g. 50 meters in urban areas).

- The planned route is provided at the start of each ride
- Live GPS coordinates are compared against the planned route at a regular polling interval
- If the vehicle strays beyond the threshold distance, an anomaly event is created

### Speed Anomaly
A speed anomaly is triggered when a vehicle is travelling significantly above the speed limit for the road segment it is currently on.

- Road type and speed limits are determined using a maps/routing API (e.g. Google Maps, HERE, or OpenStreetMap)
- A configurable tolerance buffer is applied (e.g. 15% above the speed limit) to avoid false positives
- Sustained speeding over a defined time window triggers an anomaly event (rather than a momentary spike)

---

## Anomaly Response

When an anomaly is detected, the following actions are taken:

1. **Rider is notified** via push notification describing the anomaly (e.g. "Your driver has deviated from the planned route")
2. **Driver is notified** via push notification so they are aware of the alert
3. An anomaly event is logged with a timestamp, ride ID, anomaly type, and location

### Rider Acknowledgement
Riders can dismiss or acknowledge an alert directly from the notification or in-app. Unacknowledged alerts are tracked and may be escalated in future iterations.

---

## Technology

- **Runtime:** Node.js/TypeScript or Python (TBD)
- **Database:** PostgreSQL for ride records and anomaly logs
- **Cache/Real-time:** Redis for live ride state and location tracking
- **Mapping/Routing:** Maps API for route comparison and road speed limit data (e.g. Google Maps Platform, HERE Maps)
- **Notifications:** Push notification service (e.g. Firebase Cloud Messaging) for rider and driver alerts

---

## Key Data Models

### Ride
| Field | Description |
|---|---|
| `ride_id` | Unique identifier for the ride |
| `planned_route` | Ordered list of coordinates representing the planned route |
| `start_time` | Timestamp when the ride began |
| `status` | Current ride status (active, completed, cancelled) |

### Live Location Update
| Field | Description |
|---|---|
| `ride_id` | Associated ride |
| `coordinates` | Current GPS coordinates |
| `speed` | Current speed of the vehicle |
| `timestamp` | Time of the location update |

### Anomaly Event
| Field | Description |
|---|---|
| `anomaly_id` | Unique identifier |
| `ride_id` | Associated ride |
| `type` | Type of anomaly (`route_deviation` or `speed_anomaly`) |
| `detected_at` | Timestamp of detection |
| `location` | Coordinates where anomaly was detected |
| `acknowledged` | Whether the rider has dismissed/acknowledged the alert |
| `acknowledged_at` | Timestamp of acknowledgement |

---

## API Endpoints

### Ride Monitoring

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/rides/{ride_id}/start` | Begin monitoring a ride |
| `POST` | `/rides/{ride_id}/end` | Stop monitoring a ride |
| `POST` | `/rides/{ride_id}/location` | Receive a live location update for a ride |

### Anomalies

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/rides/{ride_id}/anomalies` | Retrieve all anomaly events for a ride |
| `PATCH` | `/anomalies/{anomaly_id}/acknowledge` | Rider acknowledges or dismisses an anomaly alert |

---

## Configuration

The following parameters will be configurable via environment variables or a config file:

| Parameter | Description | Default |
|---|---|---|
| `ROUTE_DEVIATION_THRESHOLD_METERS` | Distance in meters before a route deviation is flagged | `50` |
| `SPEED_TOLERANCE_PERCENT` | Percentage above the speed limit before flagging | `15` |
| `SPEED_ANOMALY_WINDOW_SECONDS` | Duration of sustained speeding before triggering an alert | `10` |
| `LOCATION_POLL_INTERVAL_SECONDS` | How frequently location updates are processed | `5` |

---

## Future Considerations

- Escalation flow for unacknowledged alerts (e.g. notify emergency contacts)
- Integration with emergency services for critical anomalies
- Machine learning-based anomaly detection for more nuanced patterns
- Passenger SOS button tied into the anomaly pipeline
- Historical anomaly analysis for driver safety scoring
