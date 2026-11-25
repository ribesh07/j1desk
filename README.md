# J1Desk — Flutter mobile app

Android / iOS client for the Ticket, Project & Task Management System.
It uses the **same REST API** as the Next.js web app (Swagger: `https://tickets.j1soft.org/api/docs`).

- Flutter 3.50 / Dart 3.14 (`material_ui` package for Material widgets)
- State management: **Cubit** (`flutter_bloc`). The code is deliberately simple: screens, cubits, one API class.
- GitHub-style UI, same as the web app: **dark theme by default**, light / system selectable in Settings.
- Left sidebar like the web app: a slide-out drawer on phones, and a permanent sidebar on tablets that can be collapsed to icons.
- Kanban board with **drag & drop** to change status (long-press a card).
- Push notifications with **Firebase Cloud Messaging**.

## Setup

```bash
cd flutterapk
cp .env.example .env      # then fill it in (see below)
flutter pub get
flutter run               # on a connected phone / emulator
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

### `.env`

| Key | Meaning |
| --- | --- |
| `API_BASE_URL` | Server URL, default `https://tickets.j1soft.org` |
| `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_STORAGE_BUCKET` | From the Firebase project |
| `FIREBASE_ANDROID_APP_ID`, `FIREBASE_ANDROID_API_KEY` | From the **Android app** registered in Firebase (package `org.j1soft.tickets`) |
| `FIREBASE_IOS_APP_ID`, `FIREBASE_IOS_API_KEY` | Optional, for iOS |

`.env` is bundled into the app, so it must only contain **public** values. The Firebase
service-account key stays on the server. Leave the Firebase keys empty to run without push.

**Local server:** to point a build at a local server, pass the URL at build time instead of editing `.env`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3443   # Android emulator → host machine
```

Debug builds allow plain `http`; release builds require `https`.

## Push notifications (FCM)

1. Firebase console → Project settings → **Add app → Android**, package `org.j1soft.tickets`.
   Copy the values from the downloaded `google-services.json` into `.env` (the mapping is in `.env.example`).
   You don't need to add `google-services.json` to the project: Firebase is initialised from `.env`.
2. The server must have `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL` and `FIREBASE_PRIVATE_KEY` set
   (same Firebase project).
3. After sign-in the app registers its FCM token with `POST /api/devices` (platform `ANDROID` / `IOS`).
   On sign-out it removes it again (`DELETE /api/devices`).

The server sends notifications with the **FCM HTTP v1 API** (`firebase-admin`).

**On every status change**, including drag & drop on the board, everyone involved in the ticket is notified:

- the assignee, creator and reviewer;
- **all members and the leader of the ticket's team** (or the project's team);
- the project owner and members.

The person who made the change is not notified.

**How notifications appear:**

- **App open:** shown with `flutter_local_notifications`, and the inbox badge updates.
- **App in the background or closed:** shown by Android.
- **Tapping a notification** opens the ticket.

iOS additionally needs an APNs key uploaded in Firebase and the *Push Notifications* capability enabled in Xcode.

## Project structure

```
lib/
  main.dart                 start-up: .env → Firebase → theme → app
  app.dart                  MaterialApp, themes, sign-in gate
  core/
    env.dart                reads .env
    api_client.dart         HTTP + bearer token (secure storage) + error handling
    api.dart                every endpoint used by the app
    push_service.dart       FCM + local notifications
    meta.dart               status/priority/type labels + workflow rules (mirror of the web app)
    theme.dart              GitHub Primer colors, light + dark
    format.dart             dates, sizes, initials
  models/models.dart        JSON → Dart classes
  cubits/                   AuthCubit, ThemeCubit, NavCubit, BoardCubit, TicketListCubit, UnreadCubit, DataCubit<T>
  widgets/                  sidebar/drawer, badges, avatar, cards, dialogs, activity line
  screens/                  login, shell, overview, tickets (list/board), board, projects, ticket detail,
                            ticket/project forms, inbox, team, reports, settings, search
```

## Features

- **Sign in:** with the eye toggle on the password. The session token is kept in secure storage, and an expired session returns you to the login screen.
- **Overview:** counters, my upcoming work, overdue tickets, a status chart, project progress, team workload and recent activity.
- **My Tasks / All Tickets:** search, filters (status, priority, project, assignee, overdue), and a switch between list (infinite scroll) and board.
- **Projects:** project cards; each project has Board, List, Overview and Activity tabs. Create and edit projects if you have permission.
- **Board drag & drop:** long-press a card and drag it to another column. While dragging:
  - columns you may move to are highlighted;
  - the board scrolls sideways at the screen edges;
  - a blue line shows where the card will land.

  Moves follow the web workflow: a reason dialog (reject / hold / pending / request changes / reopen), a confirmation (close / reopen), and the assign sheet when you drop on *Assigned*. The card moves immediately and goes back if the server refuses.
- **Ticket page:** workflow buttons for the actions you're allowed to take, assign / reassign, and editable properties (reviewer, priority, type, due date). Also:
  - relations and links;
  - attachments: upload, download and open;
  - comments (add, edit, delete), activity log and assignment history;
  - edit, archive and restore.
- **Inbox:** notifications with All / Unread, mark all as read, and tap to open the ticket.
- **Team, Reports, Settings:** people and teams with their workload; a report for a date range with charts; theme, push status, password change and sign-out.

## App icon

The icon is the same logo as the web app (`src/app/icon.svg`): three bars and a green dot on the GitHub dark background.

| File | Use |
| --- | --- |
| `store/playstore-icon-512.png` | Play Console → Store listing → **App icon** (512×512 PNG) |
| `assets/icon/icon.png` | 1024×1024 full icon (iOS, older Android, App Store) |
| `assets/icon/foreground.png` | Android adaptive icon foreground (inside the safe zone) |
| `assets/icon/monochrome.png` | Android 13+ themed icon |
| `android/.../drawable-*/ic_notification.png` | White status-bar icon for push notifications |

The images are drawn by `assets/icon/make_icons.py` (Python + Pillow). After changing them, regenerate the launcher icons:

```bash
python3 assets/icon/make_icons.py .
dart run flutter_launcher_icons
```

The settings are in `flutter_launcher_icons.yaml`.
