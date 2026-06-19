# OpsFlow — Requirements

## Purpose
A PostgreSQL backend that tracks items through a multi-stage workflow,
with device processing, human review, and signed reports.
Reference demo: digital pathology lab.

## Actors (who uses the system)
- **Admin** — manages organizations, users, devices
- **Lab Technician** — registers specimens, prepares slides, operates scanners
- **Pathologist (Reviewer)** — reviews scans, writes and signs reports
- **System (Device)** — scanners and microtomes emitting telemetry events
- **Readonly user** — auditors, support staff

## Core entities (the five primitives)
1. Entity — a specimen/case being tracked
2. Artifact — a slide derived from a specimen
3. Device — a scanner or microtome
4. Job — one run of a device on an artifact
5. Reviewer — a pathologist signing off

## Functional requirements
1. Register a new specimen with patient and requisition info
2. Track every status change of every specimen
3. Cut a specimen into multiple slides (artifacts)
4. Assign a slide to a device for scanning (a job)
5. Log device events (start, progress, errors, completion) as telemetry
6. Assign cases to pathologists from a queue without double-assignment
7. Write a report; create new versions on edit
8. Sign out a report — once signed, it is immutable
9. Audit every change to every business table automatically
10. Isolate each organization's data from every other organization
11. Enforce role-based access (pathologist sees only assigned cases, etc.)
12. Support workflow changes (adding/removing stages) without code changes

## Non-functional requirements
- Must remain fast at 1M+ device_events rows
- Must prevent double-assignment under concurrent load
- Must prevent two reviewers signing the same report simultaneously
- Audit log must be append-only (no deletes, no updates)

## Out of scope
- Frontend / UI
- REST API
- Authentication system (we model users and roles, but login is fake)
- Actual image storage (we store metadata, not the images themselves)