# StayFinder — Flutter mobile app

Map-based property discovery for hostels, flats, houses, shops, offices and land.
One app, two modes (Seeker / Owner), built from `StayFinder_Property_App_Specification.pdf`.

## Run it

```bash
flutter pub get
flutter run            # Android emulator/device or iOS simulator
flutter test           # unit tests for radius maths, search rules, listing rules
```

Demo login: any mobile number, OTP **123456**.

The app runs fully offline from the backend: a built-in mock backend (`lib/data/mock/`) holds
~195 realistic listings across Lahore, Islamabad, Karachi, Dubai and London, and simulates the other
side of the marketplace (owners reply to chats and accept visits, admin approves documents and listings,
a demo seeker sends an inquiry to your new listing). Demo helpers ("simulate drive", "sample photos",
"sample documents") are shown only in demo mode; build with `--dart-define=DEMO=false` to hide them.

## What is implemented (Phase 1 + parts of Phase 2)

**Seeker**
- OTP login (rate-limited), profile setup, location permission with manual fallback
- Search form: type (single or multi), country, city, radius slider + number box (admin min/max per city, km/miles per country), search centre (GPS, address search, saved places, tap on map), filters
- Map results: exact radius circle, typed pins, Verified/Featured badges, clustering, real-time pin updates, instant redraw on radius change
- Pin popup, synced results list (sort: nearest, price, rating, newest, seats), empty state with "increase radius"
- Detail page: gallery, price & terms, price guidance, seats counter, girls-hostel safety card, what's included/extras, dynamic type-specific details, rules, nearby, location map, owner card (phone hidden), reviews with category bars, similar nearby, scam warning, report listing
- Go There: road route + ETA (OSRM), notify owner / share live location, share trip link, SOS sheet, arrival detection (100 m), 4-digit visit code, outcome, review (one per confirmed visit)
- Favourites, compare up to 3, visit requests (accept reschedules/cancel), saved searches with alerts, chat (quick replies, photos, location, block/report), masked calling, notification centre with categories and deep links, support centre (FAQ + tickets), saved places, emergency contact, referral code, account deletion

**Owner**
- Verification with document upload and status tracking
- Dashboard: stats, stale-listing "still available?" reminders, pending requests
- 8-step listing wizard with **dynamic forms per property type** (from config), map pin with geo-fence check and reverse geocoding, GPS-mismatch warning, photos, preview, validation, save draft
- My listings by status, seats counter (auto FULL at 0), pause/reactivate/mark rented-sold/renew/delete, price update
- Visit requests (accept / new time / decline / no-show, visit code), inquiries, performance analytics

## Architecture

```
lib/
  core/        theme, router (go_router), geo & formatting utils, shared widgets (map pins, cards)
  data/
    models/        domain models (match spec section 18; Property has toJson/fromJson)
    config/        countries, cities, radius limits, units, property types + fields  ← from backend later
    repositories/  interfaces the UI depends on
    mock/          in-memory implementation + seed data
    services/      location (geolocator), geocoding (Nominatim), routing (OSRM)
    providers.dart Riverpod wiring — swap mock for real backend here
  features/    auth, seeker/*, owner/*, chat, notifications, profile, shell
```

State: Riverpod 3. Navigation: go_router with separate tab shells for Seeker and Owner mode.
Maps: flutter_map + OpenStreetMap (no API key needed).

## Free setup (current)

No paid services are used:

- **Notifications** appear as an in-app popup banner at the top of the screen (5 s, tap to open,
  swipe up or ✕ to dismiss) and in the notification centre (bell). They show while the app is open;
  when the app is closed, unread ones wait behind the bell badge. No Firebase.
- **Login** uses the built-in demo OTP (123456), so no SMS provider.
- **Calling** is off: owners and seekers talk through in-app chat, and phone numbers are never shown.
  To turn on masked calling later: `--dart-define=MASKED_CALLING=true` (needs a provider).
- **Maps, routing, address search**: free OpenStreetMap / OSRM / Nominatim servers
  (fine for development and small tests; they have fair-use limits).
- SOS calls the country's real emergency number; the "safety team" line appears only if you set
  `--dart-define=SAFETY_PHONE=+92...`.

## Later, when you want to go live

| Item | Why |
|---|---|
| Backend server (e.g. NestJS/FastAPI + PostgreSQL/PostGIS) | Real shared data between users; implement `lib/data/repositories/repositories.dart` and swap providers in `providers.dart` |
| Push notifications (Firebase FCM, free tier) | Alerts while the app is closed |
| SMS OTP provider | Real phone verification |
| Own map tile / routing provider | Public OSM servers are not for production traffic |
| Masked calling provider | Optional phone calls without exposing numbers |
| Image storage | Upload photos/documents instead of local paths |
| App icon, splash, store signing | Store release |
| Admin web dashboard | Separate product (spec section 16) |

Phase 2/3 items not built yet: payments & plans, featured purchase, booking tokens, Make an Offer,
multi-language (UI strings are English; language picker shows upcoming languages), heat maps.
