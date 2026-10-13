# CraftStream: Intent

Why this project exists and what "done" means. Source: `Technical_Assignment.pdf` (DevDolphins).

## Product in one paragraph

Artisans sell handmade goods by showing **how** they make them. An artisan uploads a process video (up to 15 minutes, any file size) with a title, description and price. Buyers search by keyword or tag, watch the video smoothly **even on a connection under 50 kbps**, and place an order. The flow ends when the order is placed.

## Users and journeys

| Who | Journey | Ends when |
|---|---|---|
| Artisan | Fill in title, description, price, tags → pick video → upload (survives network drops) → wait for processing | The product shows as **live** |
| Buyer | Search by keyword and/or tag → open a product → watch the process video | The video plays without stalling |
| Buyer | Tap Buy → enter name + quantity → confirm | "Order placed" is shown and the order is stored |

## Requirements and acceptance criteria

| # | Requirement | Accepted when |
|---|---|---|
| R1 | Upload a process video ≤ 15 min, unrestricted size | A large file uploads from Android and Chrome; a dropped connection resumes; a > 15 min video is rejected before upload and capped at 15:00 on the server |
| R2 | Product details: title, description, price | Stored with the product and shown on the product screen |
| R3 | Search by keyword and tag | Keyword and tag filters return only matching **ready** products |
| R4 | Watch the process video | HLS plays on Android and Chrome |
| R5 | Smooth playback under 50 kbps | With a 45 kbps throttle the video starts on the lowest rung and plays without stalling; the lowest rung measures ≤ 50 kbps including overhead |
| R6 | Place an order | The order is validated, its total is computed and it is stored with `status=placed` |
| R7 | Android phone, Android tablet, Chrome | One Flutter codebase; layouts adapt to phone, tablet (portrait + landscape) and desktop |
| R8 | Backend fully on GCP | Cloud Run, Cloud Storage, Transcoder API, Firestore, Eventarc/Pub/Sub, all in one dedicated project |

## Target numbers

- Lowest rung: ≤ 50 kbps total on the wire (~40 kbps target: 144p video + HE-AAC audio)
- Max video length: 900 s (15:00)
- Upload size: no limit (chunked, resumable, straight to GCS)
- Region: `asia-south1`

## Non-goals

- Shipping, delivery and order tracking
- Payments
- Login, accounts and auth (a Buyer/Artisan switch stands in for them)
- Reviews, chat and recommendations
- iOS and desktop native apps

## Deliverables

1. Public GitHub repository with a reviewer-friendly README
2. Video: architecture walkthrough + **live GCP evidence** (Cloud Run, Transcoder jobs, buckets, Firestore)
3. Video: Android demo, throttled below 50 kbps (upload → search → watch → order)
4. Video: Chrome demo, throttled below 50 kbps (same flow)
5. Email to hiring@devdolphins.com, CC boxvamsee@gmail.com, with the repo link and the three videos

## Definition of done

- R1–R8 all pass their acceptance criteria against the **deployed** GCP backend
- `make test` is green, including the convention test and the bitrate-budget test
- All checkboxes in `docs/PLAN.md`, `docs/BACKEND_PLAN.md` and `docs/FRONTEND_PLAN.md` are ticked
- The three videos are recorded and the email is sent
