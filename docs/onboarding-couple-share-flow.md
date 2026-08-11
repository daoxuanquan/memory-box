# MemoryBox — Onboarding & Couple Share Flow Spec (v2)

> **Docs-only spec** — Codex/agent implement theo file này. Không code trong bước viết spec.
>
> **Mục tiêu product (đơn giản):**
> 1. Mở app → **3 lựa chọn**
> 2. **Tự thiết lập dữ liệu** → tạo / dùng không gian riêng mới (hoặc tiếp tục private trống); sau này **có thể share**
> 3. **Tải dữ liệu cũ** → **bắt buộc** load được private data đã có (local và/hoặc iCloud). Fail → lỗi + **Thử lại** / **Quay Welcome**. **Không** vào MainTab “ảo” trống như thành công
> 4. **Nhập từ link được mời** → **chỉ** dùng shared data; fail → lỗi + retry / Quay Welcome; **không fallback** private
> 5. **Đã có dữ liệu + chọn nhập link** → bỏ data cũ trên UI; **bắt buộc** load shared

---

## 0. Quy tắc vàng (data)

| Tình huống | Hành vi bắt buộc |
|------------|------------------|
| User chọn **Tự thiết lập** | `activeDataSource = .ownPrivate`. Tạo CoupleSpace private nếu chưa có. **Không** bắt buộc đã có data cũ. |
| User chọn **Tải dữ liệu cũ** | Vào **restore session** (§2B). **Phải** tìm được data private hợp lệ. Fail → `RestoreDataErrorView` — **không** MainTab. |
| User chọn **Nhập từ link** | Vào **import session** (§3.0). **Cấm** đọc private cho UI chính cho đến khi shared load OK **hoặc** user **Quay Welcome**. |
| User chọn **Nhập từ link** + máy **đã có** local/private data | Confirm abandon (§3.3). Sau confirm: private **ẩn**; **không** hiện lại khi shared fail. |
| Shared zone **chưa sẵn sàng** | **Không** MainTab. **Không** fallback private. `SharedImportErrorView`. |
| Shared zone **OK**, records chưa import | MainTab **shared-only** + banner sync. |
| Restore / Import fail → **Quay Welcome** | Hủy session. User chọn lại 1 trong 3 option. |
| User **Tự thiết lập** xong, sau đó **Share** | Private space → share root. |
| User đang **participant** | Không Welcome lại. Muốn data riêng → **Rời không gian** (Settings). |

**Cấm tuyệt đối:**

- Import path: `if sharedFail { showPrivateData() }`
- Restore path: `if restoreFail { openEmptyMainTab() }` hoặc giả thành công
- Vào MainTab khi `importSessionActive` / `restoreSessionActive` chưa success
- Im lặng fail rồi hiện Home với data sai path

**Không làm trong MVP:** merge private ↔ shared, undo abandon, auto-switch path khi fail.

---

## 1. Ba lựa chọn mở app

### 1.1 Welcome (màn duy nhất trước MainTab)

**File:** `Views/Onboarding/WelcomeView.swift`  
**ViewModel:** `WelcomeViewModel`

```
┌─────────────────────────────────┐
│     [heart animation 72pt]      │
│         Memory Love             │
│   Khoảnh khắc của hai bạn       │
│                                 │
│  ┌───────────────────────────┐  │
│  │  Tự thiết lập dữ liệu     │  │  ← Primary, 52h
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │  Tải dữ liệu cũ           │  │  ← Secondary, 48h
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │  Nhập từ link được mời    │  │  ← Secondary, 48h
│  └───────────────────────────┘  │
│                                 │
│  • Tự thiết lập: bắt đầu mới   │
│    trên máy này, sau đó có thể  │
│    mời người ấy.                │
│  • Tải dữ liệu cũ: khôi phục    │
│    kỷ niệm đã có trên máy /     │
│    iCloud.                      │
│  • Nhập link: dùng không gian   │
│    người ấy đã mời.             │  ← footnote
└─────────────────────────────────┘
```

| Nút | `onboardingChoice` | Đi tiếp |
|-----|-------------------|---------|
| **Tự thiết lập dữ liệu** | `.setupOwn` | §2 |
| **Tải dữ liệu cũ** | `.restoreOwn` | §2B |
| **Nhập từ link được mời** | `.importFromLink` | §3 |

Spacing giữa 3 CTA: **12 pt**. Primary chỉ 1 nút (Tự thiết lập).

### 1.2 Khi nào hiện Welcome

| Điều kiện | Hiện Welcome? |
|-----------|---------------|
| `onboardingCompleted == false` | Có |
| Lần đầu cài, chưa có flag | Có |
| Đã complete + đang dùng own hoặc shared | Không → MainTab |
| OS deliver share accept **trước** khi user chọn | Xử lý §4.2 (ưu tiên import path) |

### 1.3 Layout tokens

| Token | Value |
|-------|-------|
| Horizontal padding | **24 pt** |
| Primary CTA height | **52 pt** |
| Secondary CTA height | **48 pt** |
| Background | `AnimatedLoveBackdrop` |
| Card / field surface | `AppTheme.surface`, corner **16** |

---

## 2. Path — Tự thiết lập dữ liệu

### 2.1 Luồng

```
Welcome [Tự thiết lập]
  → (optional) WhoAmI — chọn first/second
  → (optional) Profile + Start date — skip được
  → Done
  → MainTab (Home) — private (có thể trống)
```

Share **không** nằm trong onboarding. Chỉ trong **Cài đặt → Mời người ấy** hoặc banner Home (§6).

### 2.2 Hành vi

1. User bấm **Tự thiết lập**.
2. Ensure private `CoupleSpace` (tạo mới nếu chưa có).
3. Set `activeDataSource = .ownPrivate`, `spaceMembership = .ownLocal`.
4. Optional setup → Skip được.
5. `onboardingCompleted = true` → MainTab.

**Khác với “Tải dữ liệu cũ”:** path này **không** fail nếu chưa có memories. Empty Home là hợp lệ.

Nếu máy **đã có** private data sẵn (reinstall chưa wipe): vẫn vào MainTab với data đó — không bắt buộc gọi restore session. User muốn **chắc chắn** load từ iCloud thì dùng §2B.

### 2.3 Share sau (happy)

**Settings → Mời người ấy** hoặc Home banner:

1. Check iCloud `.available`.
2. `prepareCoupleShare()` trên private CoupleSpace.
3. Sheet: copy link + ShareLink.
4. `spaceMembership = .ownSharedPendingPartner`.

Partner Accept → participant dùng shared store (§3).

---

## 2B. Path — Tải dữ liệu cũ (restore own — bắt buộc load được)

### 2B.0 Restore session

Khi user bấm **Tải dữ liệu cũ**:

```
restoreSessionActive = true
onboardingChoice = .restoreOwn
activeDataSource = .ownPrivate   // intent — chỉ private
restorePhase = .probing
```

**Kết thúc session chỉ khi:**

| Kết thúc | Điều kiện |
|----------|-----------|
| **Success** | `restorePhase == .ready` — đã load được data hợp lệ → MainTab |
| **User abort** | **Quay lại Welcome** → `restoreSessionActive = false` |
| **Không** | Fail / timeout — **không** coi là success, **không** MainTab |

#### Định nghĩa “load được” (success criteria)

Ít nhất **một** trong các điều kiện:

1. `hasLocalCoupleData == true` (memories OR messages OR specialDays OR profile/startDate đã set trên **private** store), **hoặc**
2. Sau sync iCloud private: `CoupleSpace` + ít nhất 1 record nội dung (memory/message/specialDay/settings profile), **hoặc**
3. Policy MVP chặt: chỉ cần `CoupleSpace` private tồn tại **và** `AppSettings.startDateIsSet == true` **hoặc** có ≥1 memory — **khuyến nghị dùng (1)+(2)**.

**Fail** nếu sau probe/hydrate: không thỏa success criteria.

#### State machine `restorePhase`

```
probing                 // kiểm tra local private ngay
  ↓ có data local đủ
ready                   // → MainTab
  ↓ chưa đủ / cần iCloud
syncingFromCloud        // pull CloudKit private + poll
  ↓ có data
ready
  ↓ timeout / lỗi / không có gì
failed(error)           // RestoreDataErrorView — KHÔNG MainTab
```

### 2B.1 Luồng UI

```
Welcome [Tải dữ liệu cũ]
  → RestoreDataLoadingView
       ├─ success → (optional) WhoAmI nhẹ / Done → MainTab (private data cũ)
       └─ fail    → RestoreDataErrorView (Thử lại / Quay Welcome)
```

### 2B.2 RestoreDataLoadingView

**File:** `RestoreDataLoadingView.swift`

```
┌─────────────────────────────────┐
│     ProgressView + heart        │
│  Đang tải dữ liệu cũ            │
│  Kiểm tra máy và iCloud…        │
│                                 │
│  (substatus)                    │
└─────────────────────────────────┘
```

| Phase | Substatus |
|-------|-----------|
| `probing` | Đang tìm dữ liệu trên máy… |
| `syncingFromCloud` | Đang đồng bộ từ iCloud… |

**Poll policy:**

- Local probe: ngay lập tức
- Cloud sync: interval 1s, max **45s**
- Hết 45s không đủ success criteria → `failed(.restoreNotFound)` hoặc `.hydrationTimeout`

Back gesture: confirm “Hủy tải dữ liệu cũ?” → Quay Welcome.

### 2B.3 RestoreDataErrorView

**File:** `RestoreDataErrorView.swift`

```
┌─────────────────────────────────┐
│  ⚠️                             │
│  Không tải được dữ liệu cũ      │
│                                 │
│  {errorMessage}                 │
│                                 │
│  ┌───────────────────────────┐  │
│  │       Thử lại             │  │  ← Primary
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │   Quay lại Welcome        │  │  ← Secondary
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

| Nút | Hành vi |
|-----|---------|
| **Thử lại** | Chạy lại Loading / probe + sync; session vẫn active |
| **Quay lại Welcome** | `restoreSessionActive = false`; về Welcome chọn option khác |

**Không có** nút “Vào trang chủ trống” / “Bỏ qua”.

#### Error codes → copy

| Code | Message |
|------|---------|
| `restoreNotFound` | Không tìm thấy dữ liệu cũ trên máy hoặc iCloud. Hãy chọn Tự thiết lập hoặc Nhập từ link. |
| `icloudUnavailable` | Cần đăng nhập iCloud để tải dữ liệu đã đồng bộ trước đây. |
| `networkUnavailable` | Cần mạng để đồng bộ dữ liệu cũ từ iCloud. |
| `hydrationTimeout` | Đồng bộ quá lâu. Thử lại hoặc kiểm tra mạng / iCloud. |
| `storeError` | Không đọc được dữ liệu. Thử lại sau. |

### 2B.4 Success

- `restorePhase = .ready`
- `restoreSessionActive = false`
- `activeDataSource = .ownPrivate`
- `spaceMembership = .ownLocal` (hoặc `.owner` nếu đã có share)
- `onboardingCompleted = true`
- MainTab hiển thị **đúng** data private đã load

### 2B.5 Unhappy (tóm tắt — chi tiết §5.19+)

- Không có data + không iCloud → Error + Quay Welcome  
- Có iCloud nhưng zone trống → Error `restoreNotFound`  
- Timeout sync → Error + Thử lại  
- **Cấm** mở MainTab empty như thể đã restore thành công  

---

## 3. Path — Nhập từ link được mời (shared-only)

### 3.0 Import session — cam kết path

Khi user bấm **Nhập từ link được mời** (và qua confirm §3.3 nếu có local data):

```
importSessionActive = true
onboardingChoice = .importFromLink
activeDataSource = .sharedInvite   // intent — chưa được đọc private
importPhase = .awaitingAccept
```

**Import session** kết thúc chỉ khi:

| Kết thúc | Điều kiện |
|----------|-----------|
| **Success** | `importPhase == .sharedReady` → MainTab shared-only |
| **User abort** | Bấm **Quay lại Welcome** → `importSessionActive = false` |
| **Không** | Shared fail, timeout, empty local — **không** được coi là kết thúc session |

#### State machine `importPhase`

```
awaitingAccept          // JoinGuide — chờ user Accept trên OS
  ↓ [Tôi đã Accept — tiếp tục]
accepting               // gọi acceptShareIfPending()
  ↓ success
probingSharedZone       // poll CoupleSpace trong SHARED store
  ↓ found
hydratingSharedData     // zone OK; có thể 0 records — vẫn shared-only
  ↓ zone stable (CoupleSpace tồn tại)
sharedReady             // → MainTab (shared store only)
  ↓ fail ở bất kỳ bước nào
failed(error)           // SharedImportErrorView — KHÔNG MainTab, KHÔNG local
```

#### Phân biệt “fail” vs “đang sync”

| Trạng thái | Shared store có CoupleSpace? | UI | Fallback local? |
|------------|------------------------------|-----|-------------------|
| **Fail** | Không | `SharedImportErrorView` | **Không** |
| **Hydrating** | Có, records = 0 hoặc chưa đủ | MainTab + banner sync **hoặc** `SharedImportLoadingView` full-screen | **Không** |
| **Ready** | Có, có data | MainTab bình thường | **Không** |

**Khuyến nghị MVP:** zone OK nhưng 0 records → vẫn cho MainTab **nếu** `CoupleSpace` đã có trong shared store; banner “Đang đồng bộ…”. Zone **không** có → **không** MainTab.

### 3.1 Luồng tổng

```
Welcome [Nhập từ link]
  → (nếu có local) LocalDataAbandonConfirm
  → importSessionActive = true
  → JoinGuideView
  → (OS Accept)
  → SharedImportLoadingView (poll + hydrate)
       ├─ success → JoinResultView success → optional setup → MainTab (shared ONLY)
       └─ fail    → SharedImportErrorView (retry / Quay Welcome) — NO local
```

### 3.2 JoinGuideView

```
Title: Nhập từ link được mời
Body:
  1. Mở link người ấy gửi (Messages, Zalo, …)
  2. Nhấn Accept / Chấp nhận trên màn hình iOS
  3. Quay lại MemoryBox và nhấn nút bên dưới

[Tôi đã Accept — tiếp tục]     ← Primary 52h → §3.5
[Mở link từ clipboard]         ← optional
[Quay lại]                       ← hủy importSession → Welcome
```

### 3.3 Đã có local data — confirm abandon

(Giữ nguyên copy alert §3.3 cũ.)

Sau **Tiếp tục nhập link**:

- `hasAcknowledgedLocalAbandon = true`
- `importSessionActive = true`
- **Chưa** set `onboardingCompleted = true`
- Local **không** hiển thị từ bước này trở đi cho đến khi user Quay Welcome + chọn Tự thiết lập

### 3.4 SharedImportLoadingView (mới — bắt buộc)

**File:** `SharedImportLoadingView.swift`  
Hiện sau user bấm **Tôi đã Accept — tiếp tục**.

```
┌─────────────────────────────────┐
│     ProgressView + heart        │
│  Đang tải không gian chia sẻ    │
│  Vui lòng giữ mạng ổn định.     │
│                                 │
│  (substatus text thay đổi)      │
└─────────────────────────────────┘
```

Substatus theo phase:

| Phase | Text |
|-------|------|
| `accepting` | Đang xác nhận lời mời… |
| `probingSharedZone` | Đang tìm không gian chia sẻ… |
| `hydratingSharedData` | Đang đồng bộ dữ liệu từ iCloud… |

**Poll policy:**

- Interval: 1s, max **45s** cho probe zone
- Sau 45s không có CoupleSpace → `failed(.sharedZoneNotFound)` → §3.7
- Có zone → `sharedReady` hoặc chuyển MainTab + banner (§5.11)

**Trong lúc loading:** Back gesture disabled hoặc confirm “Hủy nhập link?” → Quay Welcome.

### 3.5 Nút “Tôi đã Accept — tiếp tục”

1. `importPhase = .accepting`
2. Present `SharedImportLoadingView`
3. `acceptShareIfPending()` + `probeSharedCoupleSpace()`
4. **Chỉ** đọc `MemoryStore` APIs scoped **shared store**
5. Success path → §3.6  
6. Fail → §3.7 (**không** đọc private)

### 3.6 JoinResultView — Success

```
Title: Đã tham gia không gian chia sẻ
Body: Dữ liệu của hai bạn sẽ hiển thị từ iCloud.
Primary: Vào trang chủ
```

Set:

- `importPhase = .sharedReady`
- `importSessionActive = false`
- `activeDataSource = .sharedInvite` (enforce trong `CoupleDataRoutingService`)
- `spaceMembership = .participant`
- `onboardingCompleted = true`

**Vào trang chủ:** `MemoryStore.load*` **chỉ** từ shared active store. Verify bằng unit/integration: không gọi private fetch khi `activeDataSource == .sharedInvite`.

### 3.7 SharedImportErrorView (mới — bắt buộc)

**File:** `SharedImportErrorView.swift`

```
┌─────────────────────────────────┐
│  ⚠️ icon                        │
│  Không tải được không gian      │
│  chia sẻ                        │
│                                 │
│  {errorMessage user-friendly}   │
│                                 │
│  ┌───────────────────────────┐  │
│  │       Thử lại             │  │  ← Primary — quay lại §3.5
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │   Quay lại Welcome        │  │  ← Secondary — abort session
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

| Nút | Hành vi |
|-----|---------|
| **Thử lại** | `importPhase = .awaitingAccept` hoặc `.probingSharedZone`; show Loading lại; **vẫn shared-only intent** |
| **Quay lại Welcome** | `importSessionActive = false`; `importPhase = .idle`; về Welcome — user **chủ động** chọn Tự thiết lập nếu muốn local |

**Không có** nút:

- “Dùng dữ liệu trên máy”
- “Bỏ qua” vào MainTab
- Auto redirect Home với local data

#### Error codes → copy

| Code | Message |
|------|---------|
| `sharedZoneNotFound` | Chưa thấy không gian chia sẻ. Hãy mở lại link, nhấn Accept, rồi thử lại. |
| `acceptFailed` | Không xác nhận được lời mời. Kiểm tra iCloud và thử lại. |
| `networkUnavailable` | Cần kết nối mạng để tải không gian chia sẻ. |
| `icloudUnavailable` | Cần đăng nhập iCloud để tham gia link mời. |
| `shareRevoked` | Link không còn hiệu lực. Nhờ người ấy gửi link mới. |
| `hydrationTimeout` | Đồng bộ quá lâu. Thử lại hoặc kiểm tra mạng. |

### 3.8 JoinResultView — Failure (deprecated)

Thay bằng **`SharedImportErrorView`** thống nhất. Không dùng flow failure riêng có nút “Tự thiết lập” ngầm.

---

## 4. Root coordinator

```
MemoryBoxApp
 └─ RootCoordinatorView
      ├─ if !onboardingCompleted → Welcome + path subflow
      ├─ else if pendingJoinResult → JoinResultView (modal)
      └─ else → MainTabView
```

### 4.1 State lưu trữ

| Field | Type | Ghi chú |
|-------|------|---------|
| `onboardingCompleted` | Bool | Gate MainTab |
| `onboardingChoice` | `.setupOwn` \| `.restoreOwn` \| `.importFromLink` | Lần chọn Welcome |
| `importSessionActive` | Bool | **true** = path nhập link; cấm private UI |
| `restoreSessionActive` | Bool | **true** = path tải dữ liệu cũ; chưa success thì cấm MainTab |
| `importPhase` | enum §3.0 | Track accept/probe/hydrate/fail |
| `restorePhase` | enum §2B.0 | Track probe/sync/ready/fail |
| `activeDataSource` | `.ownPrivate` \| `.sharedInvite` | Store UI đang đọc |
| `spaceMembership` | `.ownLocal` \| `.ownSharedPendingPartner` \| `.owner` \| `.participant` | Trạng thái share |
| `myRole` | `.first` \| `.second` | User chọn |
| `hasAcknowledgedLocalAbandon` | Bool | User đã confirm §3.3 |

**Enforcement:** `CoupleDataRoutingService.loadMemories()` (và mọi load) **assert** hoặc guard:

```swift
if importSessionActive || activeDataSource == .sharedInvite {
  return sharedStoreOnly(...)   // never private fallback
}
if restoreSessionActive && restorePhase != .ready {
  // do not serve MainTab loads; coordinator shows Loading/Error
}
if activeDataSource == .ownPrivate { return privateStoreOnly(...) }
```

Persist: `UserDefaults` (device) + mirror `AppSettings` khi có CoupleSpace (chỉ field không gây conflict cross-device).

### 4.2 Share accept xen giữa lúc mở app

| Lúc | Hành vi |
|-----|---------|
| Chưa chọn Welcome, OS gọi accept | Coi như user chọn **importFromLink**; nếu có local data → show §3.3 confirm **trước** khi finalize |
| Đang JoinGuide | Tiếp tục poll → Result |
| Đã MainTab + own data | §5.8 — confirm abandon local |

---

## 5. Unhappy cases (bắt buộc implement)

Mỗi case: **Trigger → UI → Hành vi hệ thống → Copy gợi ý**.

### 5.1 iCloud chưa đăng nhập / không available

| | |
|--|--|
| **Trigger** | User **Nhập từ link** hoặc Owner bấm **Mời** trong Settings |
| **UI** | Sheet full hoặc alert |
| **Title** | Cần đăng nhập iCloud |
| **Body** | MemoryBox cần iCloud để đồng bộ và tham gia link mời. |
| **Primary** | Mở Cài đặt |
| **Secondary** | Đóng / Quay lại |
| **System** | Không gọi `prepareCoupleShare` / không finalize accept |
| **Tự thiết lập** | **Vẫn cho** vào app offline/local (không cần iCloud) |

### 5.2 Tạo link share thất bại (Owner)

| | |
|--|--|
| **Trigger** | `prepareCoupleShare` error / timeout / hang |
| **UI** | Inline error trong Invite sheet + nút **Thử lại** |
| **System** | `spaceMembership` giữ `.ownLocal`; user vẫn dùng data riêng |
| **Không** | Block toàn app |

### 5.3 Accept xong nhưng chưa thấy shared zone (CoupleSpace)

| | |
|--|--|
| **Trigger** | Probe 45s không có `CoupleSpace` trong **shared store** |
| **UI** | `SharedImportErrorView` — **không** alert rồi về Home |
| **Title** | Không tải được không gian chia sẻ |
| **Body** | Chưa thấy dữ liệu được mời. Mở lại link, nhấn Accept, rồi Thử lại. |
| **Primary** | Thử lại |
| **Secondary** | Quay lại Welcome |
| **System** | `importSessionActive` vẫn true cho đến Quay Welcome; **không** `onboardingCompleted`; **không** đọc private |
| **Cấm** | Fallback local; vào MainTab trống bằng private data |

### 5.4 Accept thất bại (CloudKit error)

| | |
|--|--|
| **Trigger** | `acceptShareInvitation` error |
| **UI** | `SharedImportErrorView` |
| **Primary** | Thử lại |
| **Secondary** | Quay lại Welcome |
| **System** | Giữ import session; local vẫn ẩn nếu đã confirm abandon |
| **Cấm** | Nút “Tự thiết lập” trên màn lỗi (tránh fallback ngầm). User phải về Welcome **chủ động** chọn. |

### 5.5 Link hết hạn / sharing stopped

| | |
|--|--|
| **Trigger** | CloudKit share revoked / invalid URL |
| **UI** | `SharedImportErrorView`, code `shareRevoked` |
| **Body** | Link không còn hiệu lực. Nhờ người ấy gửi link mới. |
| **Primary** | Quay lại Welcome |
| **Secondary** | Thử lại (optional) |
| **Cấm** | Fallback local |

### 5.6 User có local data, chọn Nhập link, bấm Hủy ở confirm

| | |
|--|--|
| **Trigger** | Alert §3.3 → **Quay lại** |
| **UI** | Về Welcome |
| **System** | Không đổi `activeDataSource`; local vẫn nguyên |

### 5.7 User chọn Tự thiết lập

| | |
|--|--|
| **Trigger** | `choice == setupOwn` |
| **UI** | Optional setup → MainTab (có thể trống) |
| **System** | `activeDataSource = .ownPrivate` — **không** fail nếu chưa có data |

### 5.19 Tải dữ liệu cũ — không tìm thấy

| | |
|--|--|
| **Trigger** | Probe + sync 45s không đủ success criteria §2B.0 |
| **UI** | `RestoreDataErrorView` code `restoreNotFound` |
| **Primary** | Thử lại |
| **Secondary** | Quay lại Welcome |
| **System** | `onboardingCompleted` vẫn false; **không** MainTab |
| **Cấm** | Mở Home trống như thành công |

### 5.20 Tải dữ liệu cũ — iCloud / mạng lỗi

| | |
|--|--|
| **Trigger** | Cần CloudKit private nhưng account/network fail |
| **UI** | `RestoreDataErrorView` (`icloudUnavailable` / `networkUnavailable`) |
| **Primary** | Thử lại |
| **Secondary** | Quay lại Welcome (rồi có thể chọn Tự thiết lập offline) |
| **System** | Không fallback silent sang empty MainTab |

### 5.21 Tải dữ liệu cũ — timeout hydrate

| | |
|--|--|
| **Trigger** | Sync quá 45s chưa có data hợp lệ |
| **UI** | `RestoreDataErrorView` `hydrationTimeout` |
| **Primary** | Thử lại |
| **Secondary** | Quay lại Welcome |

### 5.22 Tải dữ liệu cũ — user hủy giữa loading

| | |
|--|--|
| **Trigger** | Confirm hủy trên Loading |
| **UI** | Welcome |
| **System** | `restoreSessionActive = false` |

### 5.8 Đã dùng own data (onboarding xong), sau đó Accept link mới

| | |
|--|--|
| **Trigger** | User đã MainTab với own data; mở link partner |
| **UI** | **Cùng** confirm §3.3 (abandon local) |
| **Confirm** | Chuyển `activeDataSource = .sharedInvite`; local abandoned |
| **Cancel** | Ở lại own data; ignore share metadata |

### 5.9 Đã participant, mở link khác / bấm Tự thiết lập

| | |
|--|--|
| **Trigger** | `spaceMembership == .participant` |
| **UI** | Alert |
| **Title** | Bạn đang trong không gian chia sẻ |
| **Body** | Rời không gian hiện tại trong Cài đặt trước khi dùng dữ liệu khác. |
| **Primary** | Mở Cài đặt |
| **System** | Không switch store silently |

### 5.10 Owner đã có share, partner chưa join — user bấm Nhập link (nhầm vai)

| | |
|--|--|
| **Trigger** | Owner device, user chọn Nhập link (sai flow) |
| **UI** | Alert |
| **Body** | Bạn đang là người tạo không gian. Hãy mời người ấy bằng link trong Cài đặt, không cần nhập link. |
| **Primary** | Mở mời |
| **Secondary** | Đóng |

### 5.11 Shared zone OK nhưng records chưa về (hydrating)

| | |
|--|--|
| **Trigger** | `CoupleSpace` có trong shared store; memories/messages count = 0 |
| **UI** | **MainTab allowed** — đây là shared empty, **không phải fail** |
| **Banner** | “Đang đồng bộ dữ liệu từ iCloud…” + pull-to-refresh |
| **System** | `activeDataSource = .sharedInvite` **bắt buộc**; reload on remote change |
| **Timeout 3 phút** | Chuyển `SharedImportErrorView` code `hydrationTimeout` — **vẫn không** fallback local |
| **Retry từ timeout** | Poll shared lại; **không** chuyển store |

### 5.11b User thấy data “cũ” sau khi chọn import — bug class

| | |
|--|--|
| **Trigger** | QA thấy local memories sau import path |
| **Root cause thường gặp** | `activeCoupleStore()` fallback private khi shared empty |
| **Fix bắt buộc** | Khi `activeDataSource == .sharedInvite`, **never** query private store for UI |
| **Acceptance** | Automated test: import path + empty shared → UI shows 0 items, not local count |

### 5.12 Không mạng

| | |
|--|--|
| **Tự thiết lập** | Cho dùng local bình thường |
| **Nhập link / Mời** | Block với alert “Cần kết nối mạng để tham gia / chia sẻ.” |

### 5.13 User thoát giữa onboarding

| | |
|--|--|
| **Trigger** | Kill app trước Done |
| **System** | Lần mở sau: `onboardingCompleted == false` → Welcome lại |
| **Nếu đã chọn path** | Có thể restore `onboardingChoice` draft (optional) |

### 5.14 Reinstall / máy mới — participant

| | |
|--|--|
| **Trigger** | Cài lại app, cùng Apple ID đã từng Accept |
| **UI** | Welcome → user chọn **Nhập từ link** hoặc detect shared zone restore |
| **System** | CloudKit restore shared store; không cần local cũ |
| **Happy** | JoinGuide → “Tôi đã Accept” hoặc auto-detect shared CoupleSpace |

### 5.15 Reinstall — owner

| | |
|--|--|
| **Trigger** | Cài lại, private data restore từ iCloud |
| **User chọn Tự thiết lập** | §5.7 — dùng data restore |
| **User chọn Nhập link** | §3.3 confirm nếu có restored private data |

### 5.16 Clipboard không phải link hợp lệ

| | |
|--|--|
| **Trigger** | “Mở link từ clipboard” |
| **UI** | Toast: “Không tìm thấy link mời hợp lệ.” |

### 5.17 Hai người cùng chọn một `myRole`

| | |
|--|--|
| **Trigger** | Sync xong, cả 2 device `myRole == .first` (hoặc `.second`) |
| **UI** | Banner Settings (non-blocking) |
| **Body** | Hai bạn đang cùng một vai. Đổi trong Cài đặt để tin nhắn hiển thị đúng. |

### 5.18 Rời không gian (participant) — unhappy

| | |
|--|--|
| **Trigger** | Rời thất bại (network) |
| **UI** | Alert + retry |
| **Success** | `activeDataSource = .ownPrivate`; local abandoned/shared cleared khỏi UI; Welcome **không** bắt buộc hiện lại — vào MainTab own trống hoặc local cũ nếu còn |

---

## 6. Post-onboarding UI

### 6.1 Settings — Đồng bộ

| Trạng thái | Hiển thị |
|------------|----------|
| `.ownLocal` | “Dữ liệu trên máy này” + **Mời người ấy** |
| `.ownSharedPendingPartner` / `.owner` | “Đang chờ người ấy tham gia” + copy link |
| `.participant` | “Đã tham gia không gian chia sẻ” + **Rời không gian** (không có Mời) |

### 6.2 Home banner (own, chưa mời)

Chỉ khi `spaceMembership == .ownLocal` và chưa dismiss:

```
Mời người ấy đồng bộ kỷ niệm   [Mời ngay] [✕]
```

---

## 7. Decision matrix (QA nhanh)

| User chọn | Load kết quả | UI |
|-----------|--------------|-----|
| Tự thiết lập | (không bắt buộc có data) | MainTab private (có thể trống) |
| Tải dữ liệu cũ | Tìm thấy data | MainTab private với data cũ |
| Tải dữ liệu cũ | Không tìm thấy / timeout / lỗi | **RestoreDataErrorView** — retry / Welcome — **NOT MainTab** |
| Nhập link | Zone OK | Shared only |
| Nhập link | Zone fail | **SharedImportErrorView** — **NOT private** |
| Nhập link | Zone OK, records 0 | Shared empty + banner |
| Restore/Import fail → Quay Welcome → chọn lại | — | Path mới |

### Anti-patterns (test phải FAIL)

- [ ] Import fail → Home hiện private memories
- [ ] Restore fail → Home trống với `onboardingCompleted = true`
- [ ] Restore fail → tự chuyển sang Tự thiết lập không hỏi
- [ ] Error screen có nút “Vào trang chủ” bỏ qua load
- [ ] Import: `activeCoupleStore()` trả private khi shared empty

---

## 8. File map (implement sau)

```
Views/Onboarding/
  WelcomeView.swift
  RestoreDataLoadingView.swift       // NEW — tải dữ liệu cũ
  RestoreDataErrorView.swift         // NEW — retry / Quay Welcome
  JoinGuideView.swift
  SharedImportLoadingView.swift
  SharedImportErrorView.swift
  JoinResultView.swift
  LocalDataAbandonConfirmView.swift
  OnboardingOptionalSetupView.swift

Services/
  CoupleDataRoutingService.swift
  OnboardingStore.swift
  CoupleShareService.swift
  CoupleRestoreService.swift         // probe local + CloudKit private restore
```

---

## 9. Implementation order (Codex)

1. `OnboardingStore` + `CoupleDataRoutingService` (§0)
2. Welcome **3 nút** + RootCoordinator gate
3. Path **Tự thiết lập** (§2)
4. Path **Tải dữ liệu cũ** — Loading + Error (§2B) — **no MainTab on fail**
5. Path **Nhập link** — Loading + Error shared-only (§3)
6. Settings invite + §6
7. Unhappy §5 còn lại

---

## 10. Copy chuẩn (tiếng Việt)

| Key | Text |
|-----|------|
| welcome_primary | **Tự thiết lập dữ liệu** |
| welcome_restore | **Tải dữ liệu cũ** |
| welcome_secondary | **Nhập từ link được mời** |
| abandon_local_title | **Dữ liệu trên máy này sẽ không dùng nữa** |
| abandon_local_continue | **Tiếp tục nhập link** |
| join_success_title | **Đã tham gia không gian chia sẻ** |
| join_fail_title | **Không tải được không gian chia sẻ** |
| restore_loading_title | **Đang tải dữ liệu cũ** |
| restore_fail_title | **Không tải được dữ liệu cũ** |
| import_loading_title | **Đang tải không gian chia sẻ** |
| import_retry | **Thử lại** |
| import_back_welcome | **Quay lại Welcome** |

---

## 11. Acceptance criteria

- [ ] Welcome có **đúng 3 lựa chọn**
- [ ] Tự thiết lập → MainTab private (trống OK)
- [ ] Tải dữ liệu cũ + có data → MainTab với data cũ
- [ ] Tải dữ liệu cũ + fail → **RestoreDataErrorView**, **không** MainTab; Thử lại / Quay Welcome
- [ ] Nhập link fail → **SharedImportErrorView**, **không** private
- [ ] Nhập link success → chỉ shared
- [ ] Quay Welcome từ lỗi → chọn được option khác
- [ ] Settings **Mời** sau khi own/restore success
- [ ] Participant: Rời không gian; không Mời
