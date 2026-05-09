# Backend API Audit — iOS App vs Backend Implementation

> Generated: 2026-05-08
> Updated: 2026-05-08 (all gaps implemented)
> iOS source: `/Users/siky/code/ios-MistyisletPass/`
> Backend source: `/Users/siky/code/MistyPass/api/`
> Router: `internal/http/router.go`

---

## Summary

| Category | Matched | Missing Route | Path/Method Mismatch | Total Gaps | Status |
|----------|---------|---------------|----------------------|------------|--------|
| Auth | 6 | 0 | 0 | 0 | OK |
| Profile & Me | 2→7 | ~~4~~ 0 | 0 | ~~4~~ 0 | DONE |
| Devices | 0→1 | 0 | ~~1~~ 0 | ~~1~~ 0 | DONE |
| Credentials | 5→7 | ~~2~~ 0 | 0 | ~~2~~ 0 | DONE |
| Doors (legacy) | 7 | 0 | 0 | 0 | OK |
| Doors (place-scoped) | 7→11 | ~~4~~ 0 | 0 | ~~4~~ 0 | DONE |
| Place settings | 0→1 | ~~1~~ 0 | 0 | ~~1~~ 0 | DONE |
| Org settings | 0→2 | ~~2~~ 0 | 0 | ~~2~~ 0 | DONE |
| Admin users | 5→9 | ~~3~~ 0 | ~~1~~ 0 | ~~4~~ 0 | DONE |
| Admin groups | 0→10 | ~~10~~ 0 | 0 | ~~10~~ 0 | DONE |
| Admin teams (sub) | 5→11 | ~~6~~ 0 | 0 | ~~6~~ 0 | DONE |
| Visitor groups | 0→4 | ~~5~~ 0 | 0 | ~~5~~ 0 | DONE |
| Analytics & Reports | 0→3 | ~~3~~ 0 | 0 | ~~3~~ 0 | DONE |
| Hardware rename | 0→3 | ~~3~~ 0 | 0 | ~~3~~ 0 | DONE |
| Others (bookings, alarms, cameras, events, etc.) | 20 | 0 | 0 | 0 | OK |
| **Total** | **57→102** | **~~43~~ 0** | **~~2~~ 0** | **~~45~~ 0** | **ALL DONE** |

---

## P0 — Missing Routes (iOS calls → backend 404)

These endpoints are called by the iOS app but have no matching route in the backend router. They will return 404.

### 1. Profile & Account Management — DONE

| iOS Path | Method | iOS Function | Status |
|----------|--------|-------------|--------|
| `/app/me/avatar` | POST (multipart) | `uploadAvatar(imageData:)` | **DONE** `routes_app_profile.go` |
| `/app/me/change-password` | POST | `changePassword(currentPassword:newPassword:)` | **DONE** `routes_app_profile.go` |
| `/app/me/logins` | GET | `fetchMyLogins()` | **DONE** `routes_app_profile.go` |
| `/app/me/logins/{loginId}` | DELETE | `remoteLogout(loginId:)` | **DONE** `routes_app_profile.go` |
| `/app/me/primary-device` | POST | `setPrimaryDevice()` | **DONE** `routes_app_profile.go` |

### 2. NFC & QR Credentials — DONE

| iOS Path | Method | iOS Function | Status |
|----------|--------|-------------|--------|
| `/app/credentials/nfc` | POST | `bindNFCCard(cardUID:type:label:)` | **DONE** `routes_app_settings_cred.go` |
| `/app/qr-token` | POST | `fetchQRToken()` | **DONE** `routes_app_settings_cred.go` |

### 3. Access Groups — DONE

| iOS Path | Method | iOS Function | Status |
|----------|--------|-------------|--------|
| `/app/places/{placeId}/groups` | GET | `fetchAdminGroups(placeId:)` | **DONE** `routes_app_groups.go` |
| `/app/places/{placeId}/groups` | POST | `createGroup(placeId:name:description:)` | **DONE** `routes_app_groups.go` |
| `/app/places/{placeId}/groups/{groupId}` | PATCH | `updateGroup(...)` | **DONE** `routes_app_groups.go` |
| `/app/places/{placeId}/groups/{groupId}` | DELETE | `deleteGroup(...)` | **DONE** `routes_app_groups.go` |
| `/app/places/{placeId}/groups/{groupId}/members` | GET | `fetchGroupMembers(...)` | **DONE** `routes_app_groups.go` |
| `/app/places/{placeId}/groups/{groupId}/members` | POST | `addGroupMember(...)` | **DONE** `routes_app_groups.go` |
| `/app/places/{placeId}/groups/{groupId}/members/{id}` | DELETE | `removeGroupMember(...)` | **DONE** `routes_app_groups.go` |
| `/app/places/{placeId}/groups/{groupId}/doors` | GET | `fetchGroupDoors(...)` | **DONE** `routes_app_groups.go` |
| `/app/places/{placeId}/groups/{groupId}/doors` | POST | `addGroupDoor(...)` | **DONE** `routes_app_groups.go` |
| `/app/places/{placeId}/groups/{groupId}/doors/{doorId}` | DELETE | `removeGroupDoor(...)` | **DONE** `routes_app_groups.go` |

### 4. Team Members & Access Rights — DONE

| iOS Path | Method | iOS Function | Status |
|----------|--------|-------------|--------|
| `/app/places/{placeId}/teams/{teamId}/members` | GET | `fetchTeamMembers(...)` | **DONE** `routes_app_teams_ext.go` |
| `/app/places/{placeId}/teams/{teamId}/members` | POST | `addTeamMember(...)` | **DONE** `routes_app_teams_ext.go` |
| `/app/places/{placeId}/teams/{teamId}/members/{id}` | DELETE | `removeTeamMember(...)` | **DONE** `routes_app_teams_ext.go` |
| `/app/places/{placeId}/teams/{teamId}/access-rights` | GET | `fetchTeamAccessRights(...)` | **DONE** `routes_app_teams_ext.go` |
| `/app/places/{placeId}/teams/{teamId}/access-rights` | POST | `assignTeamAccessRight(...)` | **DONE** `routes_app_teams_ext.go` |
| `/app/places/{placeId}/teams/{teamId}/access-rights/{id}` | DELETE | `removeTeamAccessRight(...)` | **DONE** `routes_app_teams_ext.go` |

### 5. Visitor Groups — DONE

| iOS Path | Method | iOS Function | Status |
|----------|--------|-------------|--------|
| `/app/places/{placeId}/visitor-groups` | GET | `fetchVisitorGroups(placeId:)` | **DONE** `routes_app_visitor_groups.go` |
| `/app/places/{placeId}/visitor-groups` | POST | `createVisitorGroup(placeId:...)` | **DONE** `routes_app_visitor_groups.go` |
| `/app/places/{placeId}/visitor-groups/{groupId}/members` | GET | `fetchVisitorGroupMembers(...)` | **DONE** `routes_app_visitor_groups.go` |
| `/app/places/{placeId}/visitor-groups/{groupId}/cleanup-expired` | POST | `cleanupExpiredVisitors(...)` | **DONE** `routes_app_visitor_groups.go` |

### 6. Analytics & Reports — DONE

| iOS Path | Method | iOS Function | Status |
|----------|--------|-------------|--------|
| `/app/places/{placeId}/analytics/summary` | GET | `fetchAnalyticsSummary(placeId:days:)` | **DONE** `routes_app_analytics.go` |
| `/app/places/{placeId}/analytics/presence` | GET | `fetchUserPresence(placeId:days:)` | **DONE** `routes_app_analytics.go` |
| `/app/places/{placeId}/reports/export` | POST | `exportReport(placeId:...)` | **DONE** `routes_app_analytics.go` |

### 7. Door-Level Detail Routes — DONE

| iOS Path | Method | iOS Function | Status |
|----------|--------|-------------|--------|
| `/app/places/{placeId}/doors/{doorId}/lockdown` | POST | `enableDoorLockdown(...)` | **DONE** `routes_app_door_detail.go` |
| `/app/places/{placeId}/doors/{doorId}/lockdown` | DELETE | `disableDoorLockdown(...)` | **DONE** `routes_app_door_detail.go` |
| `/app/places/{placeId}/doors/{doorId}/restrictions` | GET | `fetchDoorRestrictions(...)` | **DONE** `routes_app_door_detail.go` |
| `/app/places/{placeId}/doors/{doorId}/schedules` | GET | `fetchDoorSchedules(...)` | **DONE** `routes_app_door_detail.go` |

### 8. Admin User Management Gaps — DONE

| iOS Path | Method | iOS Function | Status |
|----------|--------|-------------|--------|
| `/app/places/{placeId}/users/invite` | POST | `inviteUser(placeId:email:role:)` | **DONE** `routes_app_admin_users.go` |
| `/app/places/{placeId}/users/{userId}` | DELETE | `removeUser(placeId:userId:)` | **DONE** `routes_app_admin_users.go` |
| `/app/places/{placeId}/users/{userId}/sign-out` | POST | `signOutUser(placeId:userId:)` | **DONE** `routes_app_admin_users.go` |

### 9. Settings Routes — DONE

| iOS Path | Method | iOS Function | Status |
|----------|--------|-------------|--------|
| `/app/orgs/{orgId}/settings` | GET | `fetchOrgSettings(orgId:)` | **DONE** `routes_app_settings_cred.go` |
| `/app/orgs/{orgId}/settings` | PUT | `updateOrgSettings(orgId:...)` | **DONE** `routes_app_settings_cred.go` |
| `/app/places/{placeId}/settings` | PUT | `updatePlace(placeId:...)` | **DONE** `routes_app_settings_cred.go` |

### 10. Hardware Rename — DONE

| iOS Path | Method | iOS Function | Status |
|----------|--------|-------------|--------|
| `/app/places/{placeId}/doors/{doorId}` | PATCH | `renameDoor(...)` | **DONE** `routes_app_door_detail.go` |
| `/app/gateways/{gatewayId}` | PATCH | `renameGateway(...)` | **DONE** `routes_app_door_detail.go` |
| `/app/cameras/{cameraId}` | PATCH | `renameCamera(...)` | **DONE** `routes_app_door_detail.go` |

---

## P1 — Path or Method Mismatches — FIXED

| iOS Expectation | Backend Fix | Status |
|----------------|-------------|--------|
| `POST /app/devices/apns` with `{device_token, platform}` | Added `POST /app/devices/apns` route in `routes_app_profile.go` | **FIXED** |
| `PATCH /app/places/{placeId}/users/{userId}/role` | Added `PATCH` handler alongside existing `PUT` in `router.go` | **FIXED** |

---

## P2 — Database Schema Gaps

The backend uses event-sourcing (`mistypass` + `mistypass_change_log` JSONB tables) so many entities are stored as state items rather than dedicated tables. However, these iOS features reference entities with no clear state store backing:

| Entity | iOS Model | DB Table | Notes |
|--------|-----------|----------|-------|
| Visitor Group | `VisitorGroup` | **None** | No table or state key pattern found |
| Visitor Group Member | `VisitorGroupMember` | **None** | No table or state key pattern found |
| Access Group (place-scoped) | `AccessGroup` | `mistypass_access_user_groups` | Exists but has different schema (no `door_count`, `scope`, `place_id`) |
| Group Member | `GroupMember` | **None** | `access_user_groups.members` is JSONB, not a relational table |
| Group Door | `GroupDoor` | **None** | No group-to-door mapping table |
| Team Member | `TeamMember` | **None** | Reference `team_memberships` exist at admin level |
| Access Right Assignment | `AccessRightAssignment` | **None** | Covered partially by `mistypass_access_policies` |
| Door Restriction | `DoorRestriction` | **None** | No geofence/restriction storage |
| Unlock Schedule (door-scoped) | `UnlockSchedule` | **None** | Place-scoped schedules exist in state store |
| Analytics Summary | `AnalyticsSummary` | **None** | Computed from `access_events` — no pre-aggregated table |
| User Presence Record | `UserPresenceRecord` | **None** | `presences` exist at admin level but different schema |
| User Activity | `UserActivity` | **None** | Handler exists but may compute from events |
| Alarm Schedule | `AlarmSchedule` | `mistypass_alarms` | Alarms table exists but no `alarm_schedules` table |
| Alarm Calendar Entry | `AlarmCalendarEntry` | **None** | Computed from schedules |
| Booking | `Booking` | **None** | Service methods exist but no dedicated table — likely in state store |
| Bookable Space | `BookableSpace` | **None** | Service methods exist but no dedicated table — likely in state store |
| Incident | `Incident` | **None** | Computed from alarms/events |
| User Login | `UserLogin` | `mistypass_auth_refresh_sessions` | Exists but schema doesn't include `device_name`, `platform`, `is_current` |
| Card Assignment | `CardAssignment` | **None** | Likely in state store |
| Digital Credential | `DigitalCredential` | **None** | Admin-level credential data in state store |

---

## P3 — Feature-Level Analysis

### Fully Working (iOS ↔ Backend aligned)
- Auth flow (login, refresh, magic link, org lookup, restore password)
- Legacy door listing and unlock (BLE, remote, QR, PIN)
- Place-scoped door listing, search, unlock, favorites
- Place-level lockdown enable/disable
- Visitor pass listing and creation
- Booking spaces, listing, create, cancel, check-in/check-out
- Alarm listing, SSE streaming, status update, schedules, calendar
- Camera listing, video links, snapshots
- Multi-org listing, switching, place listing/search
- Admin: event listing, incident listing, activity, schedules CRUD
- Admin: zone listing, card listing, credential listing, team CRUD
- Admin: user listing, search, get, role update (PUT only)
- Mobile credential register, list, revoke, refresh
- BLE token fetch, access logs
- Guest CRUD (admin-level routes)

### Partially Working → NOW FULLY WORKING
- **Profile**: All endpoints implemented (avatar, change password, sessions, primary device)
- **Admin users**: All endpoints implemented (invite, remove, force sign-out)
- **Teams**: Members and access rights sub-routes added
- **Device registration**: APNS route added at correct path

### Previously Not Working → NOW IMPLEMENTED
- **Access groups**: 10 place-scoped endpoints implemented
- **Visitor groups**: 4 visitor group endpoints implemented
- **Analytics dashboard**: Summary, presence, report export implemented
- **Door-level controls**: Per-door lockdown, restrictions, schedules implemented
- **Hardware rename**: Door, gateway, camera rename implemented
- **NFC card binding**: Mobile route added
- **QR token generation**: Mobile route added
- **Org/place settings**: Mobile routes added

---

## Implementation Status — ALL COMPLETE

### Phase 1 — Critical ✅
1. ~~`POST /app/me/avatar`~~ ✅ `routes_app_profile.go`
2. ~~`POST /app/me/change-password`~~ ✅ `routes_app_profile.go`
3. ~~`GET /app/me/logins` + `DELETE /app/me/logins/{id}`~~ ✅ `routes_app_profile.go`
4. ~~`POST /app/devices/apns`~~ ✅ `routes_app_profile.go`
5. ~~Fix `PATCH` vs `PUT` mismatch~~ ✅ `router.go`

### Phase 2 — Important ✅
6. ~~User invitation~~ ✅ `routes_app_admin_users.go`
7. ~~User removal~~ ✅ `routes_app_admin_users.go`
8. ~~Remote sign-out~~ ✅ `routes_app_admin_users.go`
9. ~~Team members + access rights (6 endpoints)~~ ✅ `routes_app_teams_ext.go`
10. ~~Access groups + members + doors (10 endpoints)~~ ✅ `routes_app_groups.go`

### Phase 3 — Feature completeness ✅
11. ~~Visitor groups (4 endpoints)~~ ✅ `routes_app_visitor_groups.go`
12. ~~Analytics (3 endpoints)~~ ✅ `routes_app_analytics.go`
13. ~~Door-level detail (4 endpoints)~~ ✅ `routes_app_door_detail.go`
14. ~~NFC + QR (2 endpoints)~~ ✅ `routes_app_settings_cred.go`
15. ~~Org/place settings (3 endpoints)~~ ✅ `routes_app_settings_cred.go`
16. ~~Hardware rename (3 endpoints)~~ ✅ `routes_app_door_detail.go`
17. ~~Primary device~~ ✅ `routes_app_profile.go`

---

## File References

### Backend files created/modified
- **Router:** `internal/http/router.go` — 45 new routes wired
- **New handler files created:**
  - `routes_app_profile.go` — avatar, password, sessions, primary device, APNS (6 handlers)
  - `routes_app_groups.go` — access groups CRUD + members + doors (10 handlers)
  - `routes_app_teams_ext.go` — team members + access rights (6 handlers)
  - `routes_app_visitor_groups.go` — visitor group management (4 handlers)
  - `routes_app_analytics.go` — summary, presence, export (3 handlers)
  - `routes_app_door_detail.go` — lockdown, restrictions, schedules, rename (7 handlers)
  - `routes_app_settings_cred.go` — NFC, QR, org/place settings (5 handlers)
- **Existing files extended:**
  - `routes_app_admin_users.go` — invite, remove, sign-out (3 handlers added)

### iOS Constants reference
- `MistyisletPass/Utilities/Constants.swift` — all endpoint paths
- `MistyisletPass/Services/APIService.swift` — all API call implementations
