# HarmonyOS Client (rixingyishan-hm) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native HarmonyOS client in `rixingyishan-hm` that mirrors `rixingyishan-ui` feature parity, with H5 warm theme and stronger home sync (remote pull + LWW merge + auto push).

**Architecture:** Mirror-port H5 layers into ArkTS (`common` / `model` / `services` / `pages` / `components`). Preferences for local-first storage; `@kit.NetworkKit` HTTP with Bearer + refresh; `router` + Tab(首页/设置). Home sync is bidirectional after login.

**Tech Stack:** HarmonyOS API 26 Stage model, ArkTS, preferences, `@kit.NetworkKit`, PhotoAccessHelper/CameraKit for media, Hypium for pure-logic unit tests.

**Spec:** `docs/superpowers/specs/2026-08-21-harmony-client-design.md`

**H5 reference:** `rixingyishan-ui/src/`

---

## File Map

| Path | Responsibility |
|------|----------------|
| `rixingyishan-hm/AppScope/app.json5` | bundleName `cn.qdyhjz.rxys`, app label |
| `rixingyishan-hm/AppScope/resources/base/element/string.json` | `app_name` = 日行一善 |
| `rixingyishan-hm/entry/src/main/module.json5` | permissions: INTERNET, CAMERA, MICROPHONE, READ_MEDIA/WRITE_MEDIA or PHOTO as required by API 26 |
| `rixingyishan-hm/entry/src/main/resources/base/profile/main_pages.json` | all page routes |
| `rixingyishan-hm/entry/src/main/resources/base/element/color.json` | warm theme colors |
| `ets/common/Constants.ets` | API base URL, storage keys, theme hex |
| `ets/common/Theme.ets` | color tokens for pages |
| `ets/model/Types.ets` | Record / Media / UploadTask / Merit / Profile (+ `serverRecordId`, `syncVersion`, `serverUpdatedAt`, `needsAccountBind`) |
| `ets/services/KvStore.ets` | preferences get/set/remove JSON helpers |
| `ets/services/HttpClient.ets` | get/post/put/patch/del + 401 refresh |
| `ets/services/RecordRepository.ets` | local CRUD for records + upload tasks |
| `ets/services/AuthService.ets` | SMS login, tokens, logout, mark bind flags |
| `ets/services/SyncMergeService.ets` | LWW merge + enqueue push candidates |
| `ets/services/RecordApiService.ets` | GET/POST/DELETE records + days |
| `ets/services/UploadQueueService.ets` | policy → upload → metadata sync |
| `ets/services/MeritService.ets` | tags, match, my, ranking, profile |
| `ets/services/MediaCaptureService.ets` | photo / album pick |
| `ets/services/MediaValidationService.ets` | mime/size/duration checks |
| `ets/pages/Index.ets` | home calendar + list + merit + sync onShow |
| `ets/pages/Login.ets` | SMS login + agreement checkbox |
| `ets/pages/Agreement.ets` | static legal text |
| `ets/pages/CreateRecord.ets` | form + save + enqueue |
| `ets/pages/RecordDetail.ets` | detail / retry / delete |
| `ets/pages/Ranking.ets` | total/daily boards |
| `ets/pages/Settings.ets` | prefs / logout / cache / export |
| `ets/components/CalendarMonth.ets` | month grid + dots |
| `ets/components/RecordCard.ets` | list row |
| `ets/entryability/EntryAbility.ets` | load Index; onForeground recover queue |
| `entry/src/test/SyncMergeService.test.ets` | Hypium unit tests for LWW |

---

### Task 1: Project baseline (bundle, theme, routes, Constants)

**Files:**
- Modify: `rixingyishan-hm/AppScope/app.json5`
- Modify: `rixingyishan-hm/AppScope/resources/base/element/string.json`
- Modify: `rixingyishan-hm/entry/src/main/resources/base/element/color.json`
- Modify: `rixingyishan-hm/entry/src/main/resources/base/profile/main_pages.json`
- Modify: `rixingyishan-hm/entry/src/main/module.json5`
- Create: `rixingyishan-hm/entry/src/main/ets/common/Constants.ets`
- Create: `rixingyishan-hm/entry/src/main/ets/common/Theme.ets`

- [ ] **Step 1: Set bundle identity and app name**

In `AppScope/app.json5` set:
```json5
{
  "app": {
    "bundleName": "cn.qdyhjz.rxys",
    "vendor": "qdyhjz",
    "versionCode": 1000000,
    "versionName": "0.2.0",
    "icon": "$media:layered_image",
    "label": "$string:app_name"
  }
}
```

In `AppScope/resources/base/element/string.json` set `app_name` to `日行一善`.

- [ ] **Step 2: Theme colors**

In `entry/src/main/resources/base/element/color.json` add:
```json
{
  "color": [
    { "name": "start_window_background", "value": "#FFF8F0" },
    { "name": "page_background", "value": "#FFF8F0" },
    { "name": "brand_accent", "value": "#E8733A" },
    { "name": "text_primary", "value": "#2C2C2C" },
    { "name": "text_secondary", "value": "#999999" },
    { "name": "card_background", "value": "#FFFFFF" },
    { "name": "divider", "value": "#F0E6DC" }
  ]
}
```

- [ ] **Step 3: Register all pages in `main_pages.json`**

```json
{
  "src": [
    "pages/Index",
    "pages/Login",
    "pages/Agreement",
    "pages/CreateRecord",
    "pages/RecordDetail",
    "pages/Ranking",
    "pages/Settings"
  ]
}
```

- [ ] **Step 4: Declare network + media permissions in `module.json5`**

Under `module`, add (adjust exact permission names to API 26 docs if DevEco warns):
```json5
"requestPermissions": [
  { "name": "ohos.permission.INTERNET" },
  { "name": "ohos.permission.GET_NETWORK_INFO" },
  { "name": "ohos.permission.CAMERA" },
  { "name": "ohos.permission.MICROPHONE" },
  { "name": "ohos.permission.READ_IMAGEVIDEO" },
  { "name": "ohos.permission.WRITE_IMAGEVIDEO" }
]
```

- [ ] **Step 5: Create Constants + Theme**

`ets/common/Constants.ets`:
```typescript
export class Constants {
  static readonly API_BASE: string = 'https://rxys.qdyhjz.cn/rxys/api';
  static readonly KEY_RECORDS: string = 'good_deeds_records';
  static readonly KEY_UPLOAD_TASKS: string = 'good_deeds_upload_tasks';
  static readonly KEY_TEMP_MEDIA: string = 'good_deeds_temp_media';
  static readonly KEY_ACCESS_TOKEN: string = 'accessToken';
  static readonly KEY_REFRESH_TOKEN: string = 'refreshToken';
  static readonly KEY_USER_PHONE: string = 'userPhone';
  static readonly KEY_USER_ID: string = 'userId';
  static readonly KEY_WIFI_ONLY: string = 'settings_wifi_only';
  static readonly KEY_VIDEO_DURATION: string = 'settings_video_duration';
  static readonly DEFAULT_VIDEO_DURATION: number = 30;
  static readonly UPLOAD_MAX_RETRY: number = 3;
  static readonly UPLOAD_RETRY_DELAYS_MS: number[] = [2000, 5000, 10000];
}
```

`ets/common/Theme.ets`:
```typescript
export class Theme {
  static readonly bg: string = '#FFF8F0';
  static readonly accent: string = '#E8733A';
  static readonly text: string = '#2C2C2C';
  static readonly textSecondary: string = '#999999';
  static readonly card: string = '#FFFFFF';
  static readonly divider: string = '#F0E6DC';
}
```

- [ ] **Step 6: Commit**

```bash
git add rixingyishan-hm/AppScope rixingyishan-hm/entry/src/main/module.json5 rixingyishan-hm/entry/src/main/resources rixingyishan-hm/entry/src/main/ets/common
git commit -m "chore(hm): baseline bundle, theme, routes, constants"
```

---

### Task 2: Models + KvStore + RecordRepository

**Files:**
- Create: `ets/model/Types.ets`
- Create: `ets/services/KvStore.ets`
- Create: `ets/services/RecordRepository.ets`
- Create: `entry/src/test/ListLocal.test.ets` (optional smoke) — prefer SyncMerge tests in Task 5; here add a small repository-shaped pure helper test if Hypium cannot easily mock preferences.

- [ ] **Step 1: Define types (include cloud fields from day 1)**

`ets/model/Types.ets`:
```typescript
export type RecordType = 'photo' | 'video' | 'text';
export type SyncStatus = 'draft' | 'queued' | 'uploading' | 'synced' | 'failed';

export interface MediaItem {
  localPath?: string;
  remoteUrl?: string;
  objectKey?: string;
  mimeType: string;
  width?: number;
  height?: number;
  durationMs?: number;
  sizeBytes?: number;
  checksum?: string;
}

export interface GoodDeedRecord {
  id: string;
  userId?: string;
  serverRecordId?: string;
  syncVersion?: number;
  serverUpdatedAt?: string;
  needsAccountBind?: boolean;
  type: RecordType;
  title?: string;
  content: string;
  media: MediaItem[];
  dayKey: string;
  createdAt: string;
  updatedAt: string;
  status: SyncStatus;
  failReason?: string;
  tags?: string[];
  meritTagId?: number;
  meritValue?: number;
}

export interface UploadTask {
  id: string;
  recordId: string;
  mediaIndex: number;
  localPath: string;
  status: 'queued' | 'uploading' | 'success' | 'failed';
  retryCount: number;
  failReason?: string;
  createdAt: string;
  updatedAt: string;
}

export interface MeritTag {
  id: number;
  name: string;
  icon: string;
  meritValue: number;
  keywords: string[];
}

export interface UserMerit {
  totalMerit: number;
  dailyMerit: number;
}

export interface RankingItem {
  rankPosition: number;
  nickname: string;
  avatarSeed: string;
  meritValue: number;
  isMe?: boolean;
}

export interface UserProfile {
  id: number;
  phone: string;
  nickname: string | null;
  avatarSeed: string;
  totalMerit: number;
  showInRanking: boolean;
}

export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}
```

- [ ] **Step 2: Implement KvStore (preferences wrapper)**

`ets/services/KvStore.ets` — use `@kit.ArkData` preferences:
- `init(context: Context)` once from EntryAbility
- `getString(key): string | ''`
- `setString(key, value)`
- `remove(key)`
- `getJson<T>(key, fallback): T`
- `setJson(key, value)`

Store singleton `KvStore` used by all services. Initialize in `EntryAbility.onCreate` with `this.context`.

- [ ] **Step 3: Implement RecordRepository**

Mirror H5 `RecordRepository.ts` methods:
- `getAll / getById / getByDayKey / insert / update / delete`
- upload tasks: `getPendingUploadTasks / getUploadTaskById / saveUploadTask / deleteUploadTasksByRecord / clearUploadTasks`
- `clearTempMedia / clearAllRecords` (settings)
- `sumMeritLocal(): { total: number, daily: number }` for today `dayKey`

DayKey format: `YYYY-MM-DD` local timezone.

- [ ] **Step 4: Commit**

```bash
git add rixingyishan-hm/entry/src/main/ets/model rixingyishan-hm/entry/src/main/ets/services/KvStore.ets rixingyishan-hm/entry/src/main/ets/services/RecordRepository.ets rixingyishan-hm/entry/src/main/ets/entryability
git commit -m "feat(hm): models, KvStore, RecordRepository"
```

---

### Task 3: HttpClient + AuthService + Login + Agreement

**Files:**
- Create: `ets/services/HttpClient.ets`
- Create: `ets/services/AuthService.ets`
- Create: `ets/pages/Login.ets`
- Create: `ets/pages/Agreement.ets`
- Modify: `ets/pages/Index.ets` (temporary stub with “去登录” button OK until Task 6)

- [ ] **Step 1: HttpClient**

Behavior (align `request.ts`):
- Base URL `Constants.API_BASE`
- Methods: `get/post/put/patch/del`
- Options: `skipAuth?: boolean`
- Success: HTTP 2xx and body `code === 0`
- Attach `Authorization: Bearer ${accessToken}` unless skipAuth
- On 401: single-flight refresh via `POST /auth/refresh` with `{ refreshToken }`; update tokens; retry once; on failure clear tokens and `router.pushUrl({ url: 'pages/Login' })`

Use `http.createHttp()` from `@kit.NetworkKit`.

- [ ] **Step 2: AuthService**

```typescript
// API shapes
// POST /auth/sms/send { phone } -> { expiresIn }
// POST /auth/sms/verify { phone, code } -> { accessToken, refreshToken, expiresIn, userId, phone }
// POST /auth/logout
// POST /auth/refresh { refreshToken }
```

Methods:
- `sendSmsCode(phone)`
- `verifySmsCode(phone, code)` — persist tokens + phone + userId; do **not** show merge modal; call `SyncMergeService.enqueueUnboundLocals()` once SyncMerge exists (Task 5). For Task 3, stub: mark nothing yet, leave TODO hook `AuthService.onLoggedIn()` empty callback assigned later.
- `isLoggedIn(): boolean`
- `logout()` — `POST /auth/logout` best-effort; clear tokens; set `needsAccountBind=true` on non-synced records; pause upload queue when it exists
- `getAccessToken / getPhone / getUserId`

- [ ] **Step 3: Agreement page**

Query param `type=user|privacy`. Show static Chinese legal text (port from H5 `agreement.vue`). Warm background.

- [ ] **Step 4: Login page**

UI: phone input, code input, send-code (60s countdown), agreement checkbox + links to Agreement, login button.
Validate phone `/^1[3-9]\d{9}$/`, code 6 digits.
On success: `router.replaceUrl` or `back` to Index.

- [ ] **Step 5: Manual verify M1-auth**

Run on emulator/device:
1. Open Login → send code against real API (or mock if SMS unavailable in env — then verify error toast path)
2. Confirm Agreement navigation works

- [ ] **Step 6: Commit**

```bash
git add rixingyishan-hm/entry/src/main/ets/services/HttpClient.ets rixingyishan-hm/entry/src/main/ets/services/AuthService.ets rixingyishan-hm/entry/src/main/ets/pages/Login.ets rixingyishan-hm/entry/src/main/ets/pages/Agreement.ets
git commit -m "feat(hm): HttpClient, AuthService, Login, Agreement"
```

---

### Task 4: RecordApiService + SyncMergeService (pure LWW) + unit tests

**Files:**
- Create: `ets/services/RecordApiService.ets`
- Create: `ets/services/SyncMergeService.ets`
- Create: `entry/src/test/LocalUnit.test.ets` (or `SyncMergeService.test.ets`) — Hypium tests for pure merge helpers

- [ ] **Step 1: Write failing Hypium tests for LWW helpers**

Extract pure functions in `SyncMergeService.ets` (no preferences required):

```typescript
export function lwwScore(r: GoodDeedRecord): number {
  if (r.syncVersion !== undefined && r.syncVersion !== null) {
    return r.syncVersion;
  }
  const t = r.serverUpdatedAt || r.updatedAt || '';
  return Date.parse(t) || 0;
}

export function pickWinner(local: GoodDeedRecord, remote: GoodDeedRecord): 'local' | 'remote' | 'equal' {
  const ls = lwwScore(local);
  const rs = lwwScore(remote);
  if (ls > rs) return 'local';
  if (rs > ls) return 'remote';
  return 'equal';
}

export interface MergeResult {
  merged: GoodDeedRecord[];
  toPushIds: string[];
}

export function mergeDayRecords(local: GoodDeedRecord[], remote: GoodDeedRecord[]): MergeResult {
  // Match key: serverRecordId if present, else id
  // Rules per spec §4.2
  // Skip overwriting local if status in draft|queued|uploading|failed (keep local, still may toPush)
}
```

Test cases:
1. remote-only → appears in merged, not in toPush
2. local-only → merged keeps local, id in toPush
3. both, local newer syncVersion → local kept, in toPush
4. both, remote newer → remote overwrites, not in toPush
5. local status `uploading` + remote older → keep local

Run Hypium local unit test in DevEco; expect FAIL before implementation, PASS after.

- [ ] **Step 2: Implement merge + RecordApiService**

`RecordApiService`:
- `listByDay(dayKey, page=1, pageSize=50)`
- `listDays(month /* YYYY-MM */)`
- `create(recordPayload)`
- `getById(serverId)`
- `remove(serverId)`

`SyncMergeService.syncHome(dayKey, month)`:
1. If `!AuthService.isLoggedIn()` return local-only
2. Fetch remote day list + days set
3. `mergeDayRecords` against `RecordRepository.getByDayKey` / full local for unbound
4. Persist merged via repository
5. For each `toPushIds`, call upload/create path (text-only create for now; media via UploadQueue in Task 8)
6. Return `{ dayKeysWithRecords: string[], dayRecords: GoodDeedRecord[] }`

Wire `AuthService.verifySmsCode` success → `SyncMergeService.afterLoginAutoPush()` (enqueue all unbound / needsAccountBind).

- [ ] **Step 3: Run tests — expect PASS**

- [ ] **Step 4: Commit**

```bash
git add rixingyishan-hm/entry/src/main/ets/services/RecordApiService.ets rixingyishan-hm/entry/src/main/ets/services/SyncMergeService.ets rixingyishan-hm/entry/src/test
git commit -m "feat(hm): RecordApi + SyncMerge LWW with unit tests"
```

---

### Task 5: Index home UI (calendar, list, merit card, sync onShow)

**Files:**
- Create: `ets/components/CalendarMonth.ets`
- Create: `ets/components/RecordCard.ets`
- Modify: `ets/pages/Index.ets`
- Create stub navigate targets if missing

- [ ] **Step 1: CalendarMonth component**

Props: `year`, `month`, `selectedDayKey`, `dottedDayKeys: string[]`
Events: `onSelect(dayKey)`, `onMonthChange(y,m)`
Style: today / selected use `Theme.accent`; dots under days with records.

- [ ] **Step 2: RecordCard component**

Show type badge, content ellipsis, status text, merit value, up to 3 media thumbs if any.

- [ ] **Step 3: Index page**

Layout (warm bg):
1. Header: title 日行一善 + login/avatar chip + ranking entry
2. Merit card: total + daily (`max(local, remote)` when logged in via MeritService stub returning local until Task 9)
3. CalendarMonth
4. List of RecordCard for selected day
5. FAB / button → CreateRecord
6. Bottom TabBar: 首页 | 设置 (`router` to Settings)

`aboutToAppear` + `onPageShow`:
- load local list
- if logged in → `SyncMergeService.syncHome(selectedDayKey, currentMonth)` then refresh UI
- Toast on network error, keep local

- [ ] **Step 4: Manual M2 check**

1. Unlogged: create not yet (Task 6) — seed one record via temporary debug button OR wait Task 6
2. Login → auto merge/push
3. Second device/H5 create remote → HM home pull shows it

- [ ] **Step 5: Commit**

```bash
git add rixingyishan-hm/entry/src/main/ets/pages/Index.ets rixingyishan-hm/entry/src/main/ets/components
git commit -m "feat(hm): Index home calendar, list, sync onShow"
```

---

### Task 6: CreateRecord + RecordDetail (text path first)

**Files:**
- Create: `ets/pages/CreateRecord.ets`
- Create: `ets/pages/RecordDetail.ets`
- Create: `ets/services/MeritService.ets` (tags + match only for now)

- [ ] **Step 1: MeritService tags/match**

- `GET /merit/tags` (skipAuth ok)
- `POST /merit/match { content }` → suggested tag
- Cache tags in memory

- [ ] **Step 2: CreateRecord page**

Fields: content (required), optional title, merit tag chips, custom tags.
On save:
1. Build `GoodDeedRecord` with new uuid `id`, `dayKey=today`, `status=draft`, `type=text` (or photo/video later)
2. If `!isLoggedIn` → `needsAccountBind=true`
3. `RecordRepository.insert`
4. If logged in → `RecordApiService.create` then set `serverRecordId`, `status=synced`; on fail keep draft/failed
5. `router.back()`

Type rule when media exists later: any video → `video`, else `photo`.

- [ ] **Step 3: RecordDetail page**

Param `id`. Load from repository.
Actions: retry (if failed), delete (confirm → local delete; if `serverRecordId` then `DELETE /records/:id`).
Show status + failReason.

- [ ] **Step 4: Manual M1 complete**

Unlogged create → appears on Index → login → auto push → status synced.

- [ ] **Step 5: Commit**

```bash
git add rixingyishan-hm/entry/src/main/ets/pages/CreateRecord.ets rixingyishan-hm/entry/src/main/ets/pages/RecordDetail.ets rixingyishan-hm/entry/src/main/ets/services/MeritService.ets
git commit -m "feat(hm): CreateRecord and RecordDetail text sync"
```

---

### Task 7: Media capture + validation

**Files:**
- Create: `ets/services/MediaValidationService.ets`
- Create: `ets/services/MediaCaptureService.ets`
- Modify: `ets/pages/CreateRecord.ets`

- [ ] **Step 1: MediaValidationService**

Rules (align H5):
- Image: jpeg/png/webp, ≤ 10MB
- Video: mp4/quicktime, ≤ 50MB, duration ≤ min(settings, platform)

Return `{ ok: boolean, message?: string }`.

- [ ] **Step 2: MediaCaptureService**

- `takePhoto(): Promise<MediaItem>`
- `chooseFromAlbum(mediaType: 'image'|'video'|'mix'): Promise<MediaItem[]>`
Use Harmony PhotoViewPicker / CameraKit; map to `MediaItem.localPath` + mime/size.

- [ ] **Step 3: Wire CreateRecord media buttons**

Add 拍照 / 相册; validate; append to form media list; set record type by scan mime; on save if media.length>0 set `status=queued` and enqueue UploadQueue (Task 8 — for now save local paths only and status queued).

- [ ] **Step 4: Commit**

```bash
git add rixingyishan-hm/entry/src/main/ets/services/MediaValidationService.ets rixingyishan-hm/entry/src/main/ets/services/MediaCaptureService.ets rixingyishan-hm/entry/src/main/ets/pages/CreateRecord.ets
git commit -m "feat(hm): media capture and validation"
```

---

### Task 8: UploadQueueService + EntryAbility recover

**Files:**
- Create: `ets/services/UploadQueueService.ets`
- Modify: `ets/entryability/EntryAbility.ets`
- Modify: `ets/pages/RecordDetail.ets` (retry)
- Modify: `ets/pages/CreateRecord.ets` (enqueue on save)

- [ ] **Step 1: UploadQueueService**

Align H5 pipeline:
1. Respect `settings_wifi_only` via network type API; skip if cellular
2. Concurrency 1
3. For task: status uploading → `POST /upload/policy` with file meta → upload binary to `uploadUrl` with returned headers → write `remoteUrl/objectKey` on media → task success
4. When all media for record success → `POST /records` metadata → record `synced`
5. Retry delays `Constants.UPLOAD_RETRY_DELAYS_MS`, max 3 → `failed`
6. `enqueue(recordId)`, `retryTask(taskId)`, `retryRecord(recordId)`, `recoverPendingTasks()`, `pause()` / `resume()` for logout

- [ ] **Step 2: EntryAbility**

`onForeground` / first window: `UploadQueueService.recoverPendingTasks()` (downgrade uploading→queued).

- [ ] **Step 3: Manual M3**

Create photo record while logged in → observe queued→uploading→synced; kill app mid-upload → relaunch recovers.

- [ ] **Step 4: Commit**

```bash
git add rixingyishan-hm/entry/src/main/ets/services/UploadQueueService.ets rixingyishan-hm/entry/src/main/ets/entryability/EntryAbility.ets
git commit -m "feat(hm): upload queue with policy upload and recover"
```

---

### Task 9: Merit my + Ranking page

**Files:**
- Modify: `ets/services/MeritService.ets`
- Create: `ets/pages/Ranking.ets`
- Modify: `ets/pages/Index.ets` (merit card + nav)

- [ ] **Step 1: Extend MeritService**

- `GET /merit/my` → UserMerit
- `GET /merit/ranking?type=total|daily`
- Index merit: `displayTotal = max(localTotal, remote.totalMerit)` same for daily

- [ ] **Step 2: Ranking page**

Tabs total/daily; list with medals; sticky my rank; if not logged in → redirect Login.
Pull-to-refresh.

- [ ] **Step 3: Commit**

```bash
git add rixingyishan-hm/entry/src/main/ets/services/MeritService.ets rixingyishan-hm/entry/src/main/ets/pages/Ranking.ets rixingyishan-hm/entry/src/main/ets/pages/Index.ets
git commit -m "feat(hm): merit stats and ranking page"
```

---

### Task 10: Settings page (full)

**Files:**
- Create: `ets/pages/Settings.ets`
- Modify: `ets/services/MeritService.ets` (`GET/PATCH /users/profile`)

- [ ] **Step 1: Profile APIs**

- load profile when logged in
- PATCH nickname, showInRanking

- [ ] **Step 2: Settings UI**

- Nickname edit dialog
- Wi-Fi only toggle → KvStore `settings_wifi_only`
- Ranking visibility switch
- Logout (confirm) → AuthService.logout
- Clear cache → clear upload tasks + temp media only (NOT records)
- Delete all local records → strong double confirm → `clearAllRecords`
- Export JSON → copy to pasteboard (`@kit.ArkData` pasteboard)
- Links to Agreement
- About `v0.2.0`

- [ ] **Step 3: Manual M4**

Verify clear cache keeps records; clear data removes; logout keeps local + needsAccountBind; re-login auto push.

- [ ] **Step 4: Commit**

```bash
git add rixingyishan-hm/entry/src/main/ets/pages/Settings.ets rixingyishan-hm/entry/src/main/ets/services
git commit -m "feat(hm): settings profile, cache, logout, export"
```

---

### Task 11: Polish navigation shell + replace Hello World leftovers

**Files:**
- Modify: Index/Settings Tab experience
- Remove any leftover template strings in resources
- Ensure `Index` is launch page in EntryAbility (`pages/Index`)

- [ ] **Step 1: EntryAbility loadContent `'pages/Index'`**

- [ ] **Step 2: Shared TabBar on Index + Settings only**

- [ ] **Step 3: Smoke full path checklist against spec §6 acceptance**

- [ ] **Step 4: Final commit**

```bash
git add rixingyishan-hm
git commit -m "feat(hm): navigation polish and acceptance smoke fixes"
```

---

## Spec Coverage Check

| Spec item | Task |
|-----------|------|
| Bundle / theme / API base | Task 1 |
| Models + local repo | Task 2 |
| Auth / Login / Agreement | Task 3 |
| LWW merge + auto push | Task 4–5 |
| Home calendar/list/merit | Task 5, 9 |
| Create / Detail | Task 6 |
| Media + upload queue | Task 7–8 |
| Ranking | Task 9 |
| Settings / export / cache split | Task 10 |
| EntryAbility recover | Task 8 |
| M1–M4 milestones | Tasks 3/5/6, 4–5, 8, 9–10 |

## Placeholder / consistency notes

- `AuthService.onLoggedIn` hook from Task 3 must be wired in Task 4 to `SyncMergeService.afterLoginAutoPush` — do not leave empty.
- Cloud fields `serverRecordId` / `syncVersion` / `serverUpdatedAt` / `needsAccountBind` defined in Task 2 and used everywhere.
- Delete sync: Detail delete calls API when `serverRecordId` present (Task 6).
