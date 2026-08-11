# MemoryBox — Onboarding & Couple Share Flow Spec

> Spec cho AI/agent implement. Mọi màn hình, nút, kích thước, trạng thái, và chuyển bước phải tuân theo file này trừ khi product đổi spec.
>
> **Mục tiêu:** lần mở app đầu tiên luôn rõ “tôi tạo không gian mới” hay “tôi tham gia bằng link”, không để user tự tìm Settings để share.

---

## 0. Tóm tắt vấn đề hiện tại

| Vấn đề | Hậu quả |
|--------|---------|
| Không có onboarding | User vào Home trống, không biết phải mời partner |
| Share chôn trong Settings | Tỷ lệ couple sync thấp |
| Accept link im lặng | Partner không biết đã join thành công / thất bại |
| Role = heuristic store | `.first`/`.second` sai nếu cả 2 từng có data riêng |
| Không leave / stop share | Không quản lý được couple space |
| `ContentView` + `MemoryStore` static | Logic share/onboarding không có owner rõ ràng |

---

## 1. Khái niệm domain (bắt buộc hiểu trước khi code)

### 1.1 Couple Space

- 1 không gian dữ liệu cho 2 người: kỷ niệm, tin nhắn, ngày đặc biệt, hồ sơ, ngày bắt đầu.
- CloudKit root: `CoupleSpace` (`id == "main"` hoặc UUID ổn định sau migrate).
- **Owner:** tạo space ở private store, tạo `CKShare`, gửi link.
- **Participant:** accept share → data nằm shared store.

### 1.2 Identity (vai trò)

Không còn suy luận chỉ từ “có shared store hay không”.

Lưu rõ trong `AppSettings` / `OnboardingState`:

| Field | Ý nghĩa |
|-------|---------|
| `myRole` | `.first` hoặc `.second` (user tự chọn lúc onboarding) |
| `partnerRole` | role còn lại |
| `spaceMembership` | `.soloPendingInvite` \| `.owner` \| `.participant` \| `.localOnly` |
| `onboardingCompleted` | `Bool` — gate root UI |
| `hasChosenPath` | đã chọn Create / Join |

### 1.3 Ba đường vào app

```
A. Create couple space (Owner)
B. Join via invite link (Participant)
C. Continue alone (Local / invite later)
```

Path C vẫn có thể mời partner sau từ Home/Settings.

---

## 2. Root gate (App launch)

```
MemoryBoxApp
  └─ RootCoordinatorView
       ├─ if !onboardingCompleted → OnboardingFlowView
       ├─ else if pendingShareAccept → JoinResultOverlay
       └─ else → MainTabView (Home / Kỷ niệm / Tin nhắn / Ngày)
```

### 2.1 Khi nào hiện Onboarding

Hiện **full-screen onboarding** nếu:

- `onboardingCompleted == false`, **hoặc**
- lần đầu cài (không có `AppSettings` / flag local), **hoặc**
- vừa wipe data / reinstall mà chưa restore được space membership.

**Không** hiện lại onboarding nếu user đã complete, kể cả profile còn trống (dùng soft nudge trên Home).

### 2.2 Deep link / CloudKit accept xen giữa

Nếu OS gọi `userDidAcceptCloudKitShareWith` trong lúc onboarding chưa xong:

1. Pause wizard tại step hiện tại (giữ state).
2. Chạy accept → hiện `JoinResultView`.
3. Nếu success: set `spaceMembership = .participant`, `onboardingCompleted = true`, nhảy soft vào “Chọn bạn là ai” nếu chưa có `myRole`.
4. Nếu fail: alert + quay lại step đang đứng (thường Welcome / Join).

---

## 3. Visual system (áp dụng mọi màn onboarding)

### 3.1 Layout khung

| Token | Value |
|-------|-------|
| Horizontal padding | **24 pt** |
| Top safe area content inset | **16 pt** dưới notch |
| Bottom CTA inset | **16 pt** trên home indicator |
| Max content width | **390 pt** (center trên iPad) |
| Screen background | `AnimatedLoveBackdrop` full bleed |
| Card surface | `AppTheme.surface`, corner **16**, padding trong **16–20** |

### 3.2 Typography

| Role | Font |
|------|------|
| Brand / hero title | `.largeTitle.bold()` hoặc rounded **34** |
| Step title | `.title2.bold()` |
| Body | `.body` / `.subheadline` secondary |
| CTA primary | `.headline` white on pink |
| CTA secondary | `.subheadline.weight(.semibold)` pink/primary |
| Footnote | `.footnote` secondary |

### 3.3 Buttons

| Style | Size | Spec |
|-------|------|------|
| **Primary CTA** | height **52**, full width trong padding 24 | `.borderedProminent`, tint pink, corner 14 |
| **Secondary CTA** | height **48**, full width | `.bordered` hoặc plain text button |
| **Tertiary / skip** | height **44**, text only | secondary color, center |
| **Icon circle** | **56×56** | dùng cho avatar pick trên onboarding |
| **Back** | toolbar leading chevron | chỉ hiện từ step ≥ 2 |

Primary luôn **1 nút** / màn. Secondary optional. Không đặt 2 primary cạnh nhau.

### 3.4 Progress

- Top: `OnboardingProgressBar` — height **4**, track gray 0.2, fill pink.
- Steps Create path: Welcome → WhoAmI → Profile → StartDate → InvitePartner → Done
- Steps Join path: Welcome → JoinExplain → (system accept) → WhoAmI → Profile → Done
- Steps Solo path: Welcome → WhoAmI → Profile → StartDate → Done (Invite later)

Progress chỉ đếm steps của path đang chọn.

### 3.5 Motion

- Step transition: `.push` horizontal hoặc opacity 0.2s.
- Success: heart scale spring 1 lần.
- Không spam particle trên mọi step — chỉ Welcome + Done.

---

## 4. Flow A — Create couple space (Owner)

### Step A0 — Welcome

**File:** `Views/Onboarding/WelcomeView.swift`  
**ViewModel:** `WelcomeViewModel`

#### UI

```
┌─────────────────────────────────┐
│         [progress none]         │
│                                 │
│     [heart animation 72pt]      │
│                                 │
│         Memory Love             │  ← brand, largeTitle
│   Khoảnh khắc của hai bạn       │  ← subheadline secondary
│                                 │
│  ┌───────────────────────────┐  │
│  │  Tạo không gian cặp đôi   │  │  ← Primary 52h
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │  Tôi có link mời          │  │  ← Secondary 48h
│  └───────────────────────────┘  │
│                                 │
│     Tiếp tục một mình trước     │  ← Tertiary text
│                                 │
│  Cần iCloud đã đăng nhập để     │
│  đồng bộ với người ấy.          │  ← footnote
└─────────────────────────────────┘
```

#### Actions

| Control | Action |
|---------|--------|
| **Tạo không gian cặp đôi** | `path = .create` → check iCloud → nếu OK đi A1; nếu fail → `iCloudRequiredSheet` |
| **Tôi có link mời** | `path = .join` → B1 |
| **Tiếp tục một mình trước** | confirm alert nhẹ → `path = .solo` → A1 (skip Invite) |

#### iCloudRequiredSheet

- Title: “Cần iCloud”
- Body: giải thích MemoryBox đồng bộ qua iCloud.
- Primary: “Mở Cài đặt iCloud” → `UIApplication.openSettingsURLString`
- Secondary: “Để sau” → vẫn cho vào Solo path.

#### Validation trước Create

```
CKContainer.accountStatus
  .available → tiếp
  còn lại → sheet, không tạo CKShare
```

---

### Step A1 — Who am I? (chọn vai)

**File:** `WhoAmIView.swift` / `WhoAmIViewModel`

#### UI

```
┌─────────────────────────────────┐
│  ▓▓▓░░░░  step 1/n              │
│  ← Back                         │
│                                 │
│  Bạn là ai trong câu chuyện?    │
│  Chọn một bên — có thể đổi tên  │
│  ở bước sau.                    │
│                                 │
│  ┌─────────┐   ♥   ┌─────────┐  │
│  │ Avatar  │       │ Avatar  │  │  ← 88×88 circles
│  │  Người  │       │  Người  │  │
│  │ thứ nhất│       │ thứ hai │  │
│  │ [radio] │       │ [radio] │  │
│  └─────────┘       └─────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │         Tiếp tục          │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

#### Spec ô chọn

- Card size: width `(screen - 48 - 16) / 2`, min height **140**
- Selected: stroke pink **2.5**, shadow pink 0.2
- Unselected: stroke separator 1
- Tap card = chọn role; Primary disabled đến khi có selection

#### Actions

| Control | Action |
|---------|--------|
| Card left/right | set `myRole` |
| Tiếp tục | save `myRole` → A2 |
| Back | Welcome |

---

### Step A2 — Hồ sơ của bạn

**File:** `OnboardingProfileView.swift`  
Chỉ edit **myRole** (không bắt buộc edit partner ở bước này).

#### UI

```
┌─────────────────────────────────┐
│  progress                       │
│  ←                              │
│  Hồ sơ của bạn                  │
│  Thêm ảnh và tên để partner     │
│  nhận ra bạn.                   │
│                                 │
│         (  avatar 108  )        │
│         [Đổi ảnh]               │
│                                 │
│  Tên                            │
│  ┌───────────────────────────┐  │
│  │ TextField height 48        │  │
│  └───────────────────────────┘  │
│                                 │
│  Màu / icon (optional row)      │
│                                 │
│  ┌───────────────────────────┐  │
│  │         Tiếp tục          │  │
│  └───────────────────────────┘  │
│         Bỏ qua bước này         │
└─────────────────────────────────┘
```

#### Rules

- Tên: trim, max 40 ký tự; **không bắt buộc** (Skip được).
- Ảnh: PhotosPicker, compress như `EditProfileView` hiện tại.
- Skip → giữ empty name, vẫn đi tiếp.
- Tiếp tục với tên rỗng → OK (soft).

---

### Step A3 — Ngày bắt đầu

**File:** `OnboardingStartDateView.swift`

#### UI

- Title: “Ngày bắt đầu của hai bạn”
- `DatePicker` graphical, tint pink, trong card corner 16
- Primary: “Lưu ngày”
- Tertiary: “Để sau”

#### Actions

| Control | Action |
|---------|--------|
| Lưu ngày | `save(startDate, isSet: true)` → A4 hoặc Done nếu Solo |
| Để sau | `isSet = false` → tiếp |

---

### Step A4 — Mời partner (Owner only)

**File:** `OnboardingInviteView.swift` / `InvitePartnerViewModel`

Đây là bước **quan trọng nhất** thay Settings-only invite.

#### UI

```
┌─────────────────────────────────┐
│  progress                       │
│  Mời người ấy                   │
│  Gửi link để cùng một không     │
│  gian kỷ niệm trên iCloud.      │
│                                 │
│  ┌───────────────────────────┐  │
│  │  status icon 40           │  │
│  │  Đang tạo link… / Ready   │  │
│  │  hoặc lỗi + Thử lại       │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │  Chia sẻ link             │  │  ← Primary, ShareLink / sheet
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │  Sao chép link            │  │  ← Secondary
│  └───────────────────────────┘  │
│                                 │
│  Partner cần:                   │
│  • iPhone + MemoryBox           │
│  • iCloud đã đăng nhập          │
│  • Mở link và nhấn Accept       │
│                                 │
│  ┌───────────────────────────┐  │
│  │   Vào trang chủ           │  │  ← sau khi có link hoặc skip
│  └───────────────────────────┘  │
│     Mời sau trong Cài đặt       │
└─────────────────────────────────┘
```

#### State machine UI

| State | UI |
|-------|-----|
| `preparing` | ProgressView + “Đang tạo link…”; disable share/copy |
| `ready(url)` | hiện 2 nút share/copy; Primary “Vào trang chủ” enabled |
| `failed(message)` | error text + “Thử lại” |
| `skipped` | membership `.soloPendingInvite` |

#### Behavior

1. `onAppear` / `.task` → `prepareCoupleShare()` (reuse logic Persistence).
2. Success → `spaceMembership = .owner`, lưu URL cache local để Settings hiện lại.
3. ShareLink dùng system share sheet (Messages, etc.).
4. Copy → `UIPasteboard` + toast “Đã sao chép” 1.5s.
5. “Vào trang chủ” → `onboardingCompleted = true` → MainTab.
6. “Mời sau” → complete onboarding, badge/dot trên Settings & Home banner “Chưa mời partner”.

#### Không làm

- Không dùng `UICloudSharingController` (đã lỗi trước đó).
- Không block vào Home nếu tạo link fail — cho skip + retry trong Settings.

---

### Step A5 — Done (Owner / Solo)

**File:** `OnboardingDoneView.swift`

```
┌─────────────────────────────────┐
│     ♥ success animation         │
│     Tất cả đã sẵn sàng          │
│     short subtitle theo path    │
│  ┌───────────────────────────┐  │
│  │     Bắt đầu               │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

- Owner subtitle: “Khi người ấy Accept, dữ liệu sẽ đồng bộ.”
- Solo: “Bạn có thể mời partner bất cứ lúc nào trong Cài đặt.”
- Tap Bắt đầu → MainTab Home.

---

## 5. Flow B — Join via invite link (Participant)

### Step B1 — Join explain

**File:** `JoinExplainView.swift`

#### UI

```
Title: Tham gia không gian có sẵn
Body: Mở link mời từ Messages / Notes.
      Nếu bạn vừa bấm link và Accept,
      kéo xuống để làm mới hoặc chờ vài giây.

[Tôi đã Accept — kiểm tra]
[Mở hướng dẫn]
[Quay lại]
```

#### “Tôi đã Accept — kiểm tra”

1. Show loading.
2. `MemoryStore.refreshMembership()` / fetch shared CoupleSpace.
3. Nếu thấy shared space → B2 success path.
4. Nếu chưa → alert “Chưa thấy không gian chia sẻ. Hãy mở lại link mời và Accept, đảm bảo cùng Apple ID đã Accept.”

### Step B2 — System accept (OS)

Không có UI in-app cho CloudKit accept sheet — đó là UI hệ thống.

App phải:

1. Implement `AppDelegate` + `SceneDelegate` accept (đã có).
2. Sau accept success → post notification `.coupleShareDidAccept(success:error:)`.
3. `OnboardingCoordinator` / `RootCoordinator` subscribe → present `JoinResultView`.

### Step B3 — JoinResultView (bắt buộc có)

**File:** `JoinResultView.swift`

#### Success

```
Title: Đã tham gia!
Body: Bạn đang ở không gian chia sẻ với người ấy.
Primary: Tiếp tục thiết lập hồ sơ → WhoAmI (nếu chưa) → Profile → Done
```

Set:

- `spaceMembership = .participant`
- `onboardingCompleted` chỉ true sau WhoAmI tối thiểu (role bắt buộc)

#### Failure

```
Title: Không tham gia được
Body: {localized error}
Primary: Thử mở lại link
Secondary: Tiếp tục một mình
```

### Step B4 — WhoAmI + Profile (Participant)

Giống A1–A2 nhưng copy khác:

- “Trong không gian này, bạn là…”
- Default gợi ý: nếu Owner thường là `.first`, Participant chọn `.second` — **vẫn cho đổi**, không lock.

**Conflict rule:** nếu cả 2 chọn cùng role → tin nhắn “của tôi” có thể lệch. Mitigate:

- Lần sync đầu: nếu phát hiện 2 device cùng `myRole`, hiện banner Settings “Hai bạn đang cùng một vai — đổi trong Cài đặt”.

### Step B5 — Done (Participant)

Không hiện Invite step. Subtitle: “Kỷ niệm và tin nhắn sẽ đồng bộ qua iCloud.”

---

## 6. Flow C — Solo / invite later

1. Welcome → tertiary.
2. Alert:

```
Title: Dùng một mình trước?
Body: Bạn vẫn tạo kỷ niệm trên máy này.
      Khi sẵn sàng, mời partner trong Cài đặt.
[Tiếp tục một mình] [Hủy]
```

3. WhoAmI → Profile → StartDate → Done (skip Invite).
4. `spaceMembership = .soloPendingInvite` hoặc `.localOnly`.
5. Home hiện `InvitePartnerBanner` (dismissible, không hiện lại trong 7 ngày nếu dismiss).

---

## 7. Post-onboarding surfaces

### 7.1 Home — InvitePartnerBanner

Chỉ khi `spaceMembership == .soloPendingInvite || (.owner && !partnerHasJoinedHeuristic)`.

```
┌─────────────────────────────────────┐
│ ♥  Mời người ấy đồng bộ kỷ niệm     │
│     [Mời ngay]            [Đóng]    │
└─────────────────────────────────────┘
```

- Height ~ **72**, margin horizontal 24, corner 12.
- **Mời ngay** → present `InvitePartnerSheet` (reuse OnboardingInvite content).
- Partner joined heuristic: shared participants count > 1 **hoặc** có message/memory từ role kia.

### 7.2 Settings — Đồng bộ cặp đôi (viết lại)

Section bắt buộc có:

| Row | Owner | Participant |
|-----|-------|-------------|
| Trạng thái | “Bạn là chủ không gian” | “Đã tham gia không gian chia sẻ” |
| iCloud | status text | status text |
| Mời / Sao chép link | hiện | **ẩn** hoặc disabled + footnote |
| Thành viên | list CKShare participants nếu fetch được | “Bạn + Owner” |
| Rời không gian | N/A hoặc Stop Sharing | **Rời khỏi chia sẻ** |
| Vai trò của tôi | picker First/Second | picker |

**Leave share (Participant):**

1. Confirm destructive alert.
2. Remove share / purge local shared store membership theo API CloudKit phù hợp.
3. Reset `onboardingCompleted`? → **Không**. Chỉ set `spaceMembership = .localOnly`, clear shared data local theo policy (xem §9).

**Stop sharing (Owner):**

1. Confirm: partner mất quyền truy cập.
2. `CKModifyRecords` / unshare CoupleSpace.
3. Data owner giữ ở private.

### 7.3 Accept khi đã ở MainTab

Nếu user đã onboarding xong rồi mới Accept link:

- Present modal `JoinResultView`.
- Nếu đang `.owner` / đã có private data: hiện **conflict sheet** §8.

---

## 8. Conflict: đã có data riêng rồi join shared

**File:** `ShareConflictView.swift`

```
Title: Bạn đang có dữ liệu riêng
Body: Tham gia link sẽ dùng không gian chia sẻ.
      Dữ liệu chỉ có trên máy này có thể không
      gộp tự động.

[Dùng không gian chia sẻ]   ← primary
[Giữ dữ liệu máy này]       ← cancel accept / ignore share
```

Phase 1 (MVP): **không merge**. Chọn shared → active store = shared; private data giữ im (không xóa), không hiện trên UI chính.

Phase 2 (sau): optional “Mang kỷ niệm sang không gian chia sẻ”.

---

## 9. Data policies

| Event | Policy |
|-------|--------|
| Owner tạo share | Private CoupleSpace là root share; backfill children |
| Participant accept | Shared store active; role participant |
| Solo | Private only; có thể tạo share sau |
| Leave share | Shared UI data ẩn; không xóa private cũ |
| Reinstall | Rely CloudKit restore; onboardingCompleted sync qua `AppSettings` nếu có field; fallback local UserDefaults key `memoryBox.onboardingCompleted` |

**Onboarding flag storage:**

- Primary: `AppSettings.onboardingCompleted` (sync được giữa device **cùng** space — cẩn thận: participant device khác nhau).
- Device-local mirror: `UserDefaults` `memoryBox.onboardingCompleted` để gate UI trước khi CloudKit về.

Rule: **OR** của hai nguồn khi đọc; khi complete → ghi cả hai.

---

## 10. Coordinator & ViewModel map (implement)

```
Views/Onboarding/
  OnboardingCoordinatorView.swift      // owns path + step
  WelcomeView.swift
  WhoAmIView.swift
  OnboardingProfileView.swift
  OnboardingStartDateView.swift
  OnboardingInviteView.swift
  OnboardingDoneView.swift
  JoinExplainView.swift
  JoinResultView.swift
  ShareConflictView.swift
  Components/
    OnboardingProgressBar.swift
    OnboardingCTAButton.swift
    RolePickCard.swift

ViewModels/Onboarding/
  OnboardingCoordinatorViewModel.swift
  WelcomeViewModel.swift
  WhoAmIViewModel.swift
  OnboardingProfileViewModel.swift
  OnboardingStartDateViewModel.swift
  InvitePartnerViewModel.swift
  JoinFlowViewModel.swift

Domain/Services/
  CoupleShareService.swift             // wrap prepare/accept/leave (tách khỏi Persistence God-file dần)
  OnboardingStore.swift                // flags + path persistence
```

`ContentView` **không** chứa onboarding logic. Root:

```swift
RootView {
  if vm.showOnboarding { OnboardingCoordinatorView(...) }
  else { MainTabView(...) }
}
```

---

## 11. Analytics / logging (dev)

Mỗi bước log `MemoryLog.share`:

- `onboarding_path_selected`
- `icloud_status`
- `share_prepare_success/fail`
- `share_accept_success/fail`
- `onboarding_completed`

Không gửi PII (tên, ảnh).

---

## 12. Acceptance criteria (QA)

### Create path

- [ ] User mới thấy Welcome, không vào Home trước.
- [ ] Create bị chặn nếu không iCloud, có sheet hướng dẫn.
- [ ] Chọn role bắt buộc.
- [ ] Invite tạo được URL, copy/share hoạt động.
- [ ] Skip invite → Home + banner mời.
- [ ] Settings vẫn mời lại được.

### Join path

- [ ] Accept link hiện JoinResult success/fail (không im lặng).
- [ ] Participant không thấy nút “Mời…” như Owner.
- [ ] Sau join, memories/messages của Owner xuất hiện sau sync (có loading empty state rõ).

### Solo

- [ ] Vào được app không cần share.
- [ ] Banner mời có thể dismiss và mời sau.

### Regression

- [ ] Dark/Light theo Settings appearance vẫn đúng.
- [ ] Không regress collage timeline / delete memory trên detail.

---

## 13. Implementation order (cho AI)

1. **Scaffold** folder Onboarding + ViewModels + `OnboardingStore` flags (chưa nối CloudKit mới).
2. **Root gate** — Welcome → Solo path end-to-end (không share).
3. **WhoAmI + Profile + StartDate** wire `MemoryStore`.
4. **Invite step** reuse `prepareCoupleShare` + ShareInviteSheet UI.
5. **JoinResult** + wire accept notifications.
6. **Settings rewrite** membership / leave.
7. **Conflict sheet** + Home banner.
8. **Cleanup** tách `CoupleShareService` khỏi `PersistenceController` dần (không big-bang).

Mỗi PR nhỏ, đúng Karpathy guidelines: không đụng code ngoài scope.

---

## 14. Copy tiếng Việt (chuẩn)

Dùng đúng các câu trong spec này để UI đồng nhất. Không viết lại marketing copy trừ khi được hỏi.

Welcome primary: **Tạo không gian cặp đôi**  
Welcome secondary: **Tôi có link mời**  
Welcome tertiary: **Tiếp tục một mình trước**  
Invite primary share: **Chia sẻ link**  
Invite copy: **Sao chép link**  
Done owner: **Khi người ấy Accept, dữ liệu sẽ đồng bộ.**  
Join success: **Đã tham gia!**
