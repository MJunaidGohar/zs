# AI Chatbot Implementation Plan - Zaroori Sawal App

## Executive Summary
**Feature:** AI Educational Assistant (Gemini-powered)  
**Quota:** 15 messages per user per day  
**Fallback:** Daily educational tip + Game suggestion with background music  
**Compliance:** Google Play Store Policy Compliant  
**Status:** Implementation Ready

---

## 1. Architecture Overview

### 1.1 System Flow
```
User opens Chat Screen
    ↓
Display: "Today's quota: 15 messages remaining"
    ↓
Daily Educational Tip (cached, no API call)
    ↓
User sends message
    ↓
Quota Check (local counter)
    ├─ [Has quota] → Call Gemini API → Display response → Counter--
    └─ [No quota] → Show "Quota exhausted" → Suggest Game
    ↓
On exit: Clear conversation (no history stored)
```

### 1.2 Service Layer Structure
```
lib/
  services/
    ai_chat_service.dart          # Gemini API client
    chat_quota_service.dart       # Daily quota tracking (Hive)
    daily_tip_service.dart        # Educational tip management
    content_safety_service.dart   # Input/output filtering
    chat_ui_service.dart          # UI state management
```

### 1.3 State Management
- **Quota tracking:** Hive (local storage) - `ai_quota_box`
- **Daily reset:** Check date on app launch, reset counter if new day
- **No conversation history:** Messages stored in memory only (Provider/Riverpod)

### 1.4 Floating Chat Button Architecture
```
All Screens (except Game, Learning Video)
    ↓
Global Overlay Stack
    ↓
Floating Chat Button (Draggable)
    ├─ Long press + drag → Move anywhere on screen
    └─ Tap → Open Chat Screen (positioned near button)
        ↓
    WhatsApp-style Chat Inbox UI
        ├─ Top: Avatar + "AI Assistant" + quota indicator
        ├─ Middle: Message bubbles (green/grey)
        ├─ Bottom: Input field + send button
        └─ Swipe down or back button → Close
```

### 1.5 Screen Visibility Rules
| Screen | Floating Button | Reason |
|--------|-----------------|--------|
| Main Selection | ✅ Visible | Main navigation hub |
| Learn Screen | ✅ Visible | Learning context helpful |
| Test Screen | ✅ Visible | Can ask questions |
| Profile Screen | ✅ Visible | General assistance |
| Avatar Selection | ✅ Visible | Setup help |
| Onboarding | ❌ Hidden | First-time experience |
| **Game** | ❌ **Hidden** | Fullscreen gameplay, no distractions |
| **Learning Video** | ❌ **Hidden** | Video focus, no overlay |
| Video Player | ❌ Hidden | Video playback |

---

### 2.1 Quota Rules
| Parameter | Value |
|-----------|-------|
| Max messages per user per day | 15 |
| Reset time | 00:00 local time |
| Storage | Hive (offline capable) |
| Counter display | Real-time updates |

### 2.2 Quota States
| State | Display Message | Action |
|-------|-----------------|--------|
| 15/15 | "Today's quota: 15 messages" | Full access |
| 5/15 | "Today's quota: 5 messages left" | Warning |
| 1/15 | "Today's quota: 1 message left" | Final warning |
| 0/15 | "Quota reached. Try tomorrow!" | Disabled + Game suggestion |

### 2.3 Implementation Logic
```dart
// Daily reset check
if (lastUsedDate != today) {
  quotaCounter = 15;
  lastUsedDate = today;
}

// Per-message check
if (quotaCounter > 0) {
  allowMessage();
  quotaCounter--;
} else {
  showQuotaExhaustedUI();
}
```

---

## 3. Daily Educational Tip Feature

### 3.1 Purpose
- Engage users immediately without API cost
- Provide value even when quota exhausted
- Educational alignment with app mission

### 3.2 Tip Categories (Rotate Daily)
| Day | Category | Example |
|-----|----------|---------|
| Mon | English Grammar | "Did you know? 'Effect' is a noun, 'Affect' is a verb" |
| Tue | Computer Basics | "Tip: Ctrl+C copies, Ctrl+V pastes - universal shortcuts!" |
| Wed | Digital Marketing | "Hashtag tip: Use 5-10 relevant hashtags for best reach" |
| Thu | Web Development | "HTML tip: Always use alt text for accessibility" |
| Fri | YouTube Growth | "Thumbnail tip: Faces get 38% more clicks" |
| Sat | Study Technique | "Pomodoro: 25 min study, 5 min break = better retention" |
| Sun | Motivation | "Consistency beats intensity. Small steps daily!" |

### 3.3 Implementation
- Pre-defined list of 50+ tips (assets/tips.json)
- Rotates based on day of week + random for variety
- Cached locally (no network call)
- Displayed in banner at top of chat screen

---

## 4. Game Suggestion Integration

### 4.1 Trigger Points
| Scenario | Suggestion |
|----------|------------|
| Quota exhausted | "Need a break? Play our match-3 game with your favorite music!" |
| After 5 messages | "Take a mental break? Play game with background music" |
| Idle for 2 minutes | "Still here? Relax with a quick game!" |

### 4.2 Implementation Details
- Deep link to existing `game.dart` screen
- Preserve user's selected background music
- Add "Back to Chat" button from game
- Track game session duration (optional analytics)

### 4.3 UI Flow
```
[Chat Screen] 
    ↓ (Quota = 0)
[Show Banner: "Quota reached!"]
    ↓
[Button: "Play Match-3 Game"]
    ↓
[Navigate to Game Screen]
    ↓
[Music auto-plays if enabled]
    ↓
[Game ends / User presses back]
    ↓
[Return to Chat (quota still 0, tip visible)]
```

---

## 5. UI/UX Design Specification

### 5.1 Chat Screen Layout
```
┌─────────────────────────────────────────────┐
│ 🧠 Daily Tip: "Ctrl+C copies, Ctrl+V pastes" │ ← Tip Banner
├─────────────────────────────────────────────┤
│ 💬 Quota: 12/15 messages today              │ ← Quota Banner
├─────────────────────────────────────────────┤
│                                             │
│ [Chat Messages Area]                        │
│                                             │
│ User: What is photosynthesis?               │
│                                             │
│ AI: Photosynthesis is the process...         │
│                                             │
├─────────────────────────────────────────────┤
│ [Type message...                    ] [Send]│ ← Input Area
│                                             │
│ [🎮 Play Game to Relax]                     │ ← Suggestion Chip
└─────────────────────────────────────────────┘
```

### 5.2 Empty State (First Open)
```
┌─────────────────────────────────────────────┐
│ 🧠 Daily Tip: "Today's tip for you!"        │
├─────────────────────────────────────────────┤
│ 💬 Quota: 15/15 messages today              │
├─────────────────────────────────────────────┤
│                                             │
│  👋 Welcome to AI Assistant!                  │
│                                             │
│  Ask me anything about:                     │
│  • English                                  │
│  • Computer                                 │
│  • Digital Marketing                        │
│  • Web Development                          │
│  • YouTube Growth                           │
│                                             │
│  💡 Tip: Be specific for better answers!    │
│                                             │
├─────────────────────────────────────────────┤
│ [Ask anything...                    ] [Send]│
└─────────────────────────────────────────────┘
```

### 5.3 Quota Exhausted State
```
┌─────────────────────────────────────────────┐
│ 🧠 Daily Tip: "Consistency beats intensity"   │
├─────────────────────────────────────────────┤
│ ⚠️ Quota reached for today!                 │
│    Come back tomorrow for 15 more messages  │
├─────────────────────────────────────────────┤
│                                             │
│ [Previous conversation visible]             │
│                                             │
├─────────────────────────────────────────────┤
│ [Input Disabled - Grayed out]                 │
│                                             │
│ 🎮 Need a break?                            │
│    Play our match-3 game with music!      │
│    [Play Game Now]                          │
└─────────────────────────────────────────────┘
```

### 5.4 Visual Design Guidelines
| Element | Style |
|---------|-------|
| Tip Banner | Light blue background, info icon, small text |
| Quota Banner | Green (>5), Yellow (3-5), Red (0), with progress bar |
| Chat Bubbles | User: Primary color right, AI: Gray left |
| Input Field | Rounded, disabled state when quota 0 |
| Game Suggestion | Card with game icon, music note icon |

---

## 5.5 Floating Chat Button Design

### Button Appearance
| Property | Specification |
|----------|---------------|
| **Shape** | Circular (60px diameter) |
| **Icon** | Chat bubble / Robot assistant icon |
| **Color** | Primary app color with white icon |
| **Elevation** | 8dp shadow (floating effect) |
| **Badge** | Small red dot when quota < 5 |
| **Animation** | Subtle pulse when new tip available |

### Button Behavior
| Gesture | Action |
|---------|--------|
| **Tap** | Open chat screen positioned near button |
| **Long Press + Drag** | Move anywhere on screen |
| **Double Tap** | Quick action: Show daily tip popup |
| **Edge Snap** | Auto-snap to nearest edge when released near border |
| **Quota = 0** | **Button disappears completely until next day** |

### Button Visibility Logic
```dart
// Button visibility check
bool get shouldShowButton {
  // Hide if quota exhausted
  if (quotaCounter <= 0) return false;
  
  // Hide on Game screen
  if (currentScreen == 'Game') return false;
  
  // Hide on Learning Video screen
  if (currentScreen == 'LearningVideo') return false;
  
  // Show on all other screens
  return true;
}
```

### Quota Exhausted Flow
```
User sends 15th message
    ↓
Quota counter = 0
    ↓
[Chat screen shows final response]
    ↓
[User closes chat]
    ↓
Floating button fades out animation
    ↓
Button disappears from ALL screens
    ↓
Daily educational tip shows in app (alternative location)
    ↓
Game suggestion card appears in main UI
    ↓
Next day 00:00: Button reappears with quota reset
```

### Position Persistence
- Save button position in Hive (user preference)
- Default: Bottom-right corner (above existing FAB if any)
- Restore position on app restart

---

## 5.6 App Theme Chat Screen

### Screen Entry Animation
```
Floating Button Position
    ↓
Chat screen fades in with scale animation
    ↓
Backdrop fade (semi-transparent scrim behind chat)
    ↓
Full chat interface with app theme colors
```

### Header (App Theme Style)
```
┌─────────────────────────────────────────────┐
│ ← | 🎓 ZS Assistant | � 12/15              │
│     Your Educational Companion              │
├─────────────────────────────────────────────┤
```

| Element | Style |
|---------|-------|
| Back arrow | Left aligned, closes chat |
| Avatar | Circular ZS logo / Graduation cap icon |
| Title | "**ZS Assistant**" + subtitle "Your Educational Companion" |
| Right side | Quota counter badge (e.g., "💬 12/15") |

### Chat Area (App Theme Bubbles)
```
┌─────────────────────────────────────────────┐
│ 🧠 Daily Tip: "Tip text here..."             │
├─────────────────────────────────────────────┤
│                                             │
│    ┌──────────────────┐                     │
│    │ 👋 Hi there!     │ ← ZS Assistant     │
│    │ I'm your ZS      │    (Primary        │
│    │ Assistant...     │     color bubble)  │
│    │          12:30 PM│                     │
│    └──────────────────┘                     │
│                                             │
│                             ┌──────────────┐│
│ What is photosynthesis?  →  │What is       ││
│                             │photosynthesis?││
│                     12:31 PM│         12:31││
│                             └──────────────┘│
│                              User (Surface  │
│                              color bubble)  │
│                                             │
│    ┌──────────────────┐                     │
│    │ Photosynthesis   │ ← ZS Response      │
│    │ is the process...│    Typing shimmer  │
│    │          12:31 PM│    during loading  │
│    └──────────────────┘                     │
│                                             │
└─────────────────────────────────────────────┘
```

### Input Area (Simple Text + Send)
```
┌─────────────────────────────────────────────┐
│ ┌─────────────────────────────────────┐ ┌──┐│
│ │ Type your question...               │ │➤││
│ │                                     │ └──┘│
│ └─────────────────────────────────────┘     │
│                                             │
│ ⚠️ Quota: 12/15 messages today              │
└─────────────────────────────────────────────┘
```

| Element | Function |
|---------|----------|
| Text field | Message input, max 500 chars |
| Send button | Circular, primary color, sends message |
| Quota indicator | Shows remaining messages |

### Chat Bubble Styles (App Theme)
```dart
// ZS Assistant Message (Primary color - Indigo)
Container(
  margin: EdgeInsets.only(right: 60, left: 8, top: 4, bottom: 4),
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: AppColors.gradientPrimary, // Indigo to Violet
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(AppBorderRadius.lg),
      topRight: Radius.circular(AppBorderRadius.lg),
      bottomLeft: Radius.circular(AppBorderRadius.lg),
      bottomRight: Radius.circular(AppBorderRadius.xs),
    ),
    boxShadow: AppShadows.small,
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "ZS Assistant", 
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      SizedBox(height: 4),
      Text(
        message,
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      SizedBox(height: 4),
      Text(
        timestamp,
        style: TextStyle(color: Colors.white60, fontSize: 11),
      ),
    ],
  ),
)

// User Message (Surface color - Light/Dark adaptive)
Container(
  margin: EdgeInsets.only(left: 60, right: 8, top: 4, bottom: 4),
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(AppBorderRadius.lg),
      topRight: Radius.circular(AppBorderRadius.lg),
      bottomLeft: Radius.circular(AppBorderRadius.xs),
      bottomRight: Radius.circular(AppBorderRadius.lg),
    ),
    border: Border.all(
      color: isDarkMode ? AppColors.dividerDark : AppColors.dividerLight,
      width: 1,
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        message,
        style: TextStyle(
          color: isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          fontSize: 14,
        ),
      ),
      SizedBox(height: 4),
      Text(
        timestamp,
        style: TextStyle(
          color: isDarkMode ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
          fontSize: 11,
        ),
      ),
    ],
  ),
)
```

### Close Behavior
| Action | Result |
|--------|--------|
| **Tap floating button again** | Close chat |
| **Tap outside chat area** (on scrim) | Close chat |
| **Tap back arrow** | Close chat |
| **System back button** | Close chat |

### Chat Screen Positioning Logic
```dart
// Position chat screen based on floating button location
void _openChatScreen(Offset buttonPosition) {
  // Calculate screen dimensions
  final screenSize = MediaQuery.of(context).size;
  
  // Fixed chat size (not full screen)
  final chatWidth = min(360, screenSize.width - 32);
  final chatHeight = min(500, screenSize.height - 200);
  
  // Determine if button is in left/right half of screen
  final isLeftSide = buttonPosition.dx < screenSize.width / 2;
  final isTopSide = buttonPosition.dy < screenSize.height / 2;
  
  // Chat should open from where button is, but stay on screen
  final chatPosition = Offset(
    isLeftSide ? 16 : screenSize.width - 16 - chatWidth,
    isTopSide ? buttonPosition.dy + 80 : buttonPosition.dy - chatHeight - 20,
  );
  
  // Ensure chat stays within screen bounds
  final adjustedPosition = Offset(
    chatPosition.dx.clamp(16, screenSize.width - chatWidth - 16),
    chatPosition.dy.clamp(100, screenSize.height - chatHeight - 100),
  );
  
  showChatOverlay(
    position: adjustedPosition,
    width: chatWidth,
    height: chatHeight,
    // Close when tapping outside
    onBackdropTap: () => closeChat(),
  );
}
```

### Visual Design Guidelines (App Theme)
| Element | Light Mode | Dark Mode |
|---------|------------|-----------|
| **Chat Background** | `surfaceLight` white | `surfaceDark` slate |
| **ZS Bubble** | `gradientPrimary` (Indigo) | `gradientPrimary` (Indigo) |
| **User Bubble** | `surfaceLight` + border | `surfaceDark` + border |
| **Header** | `primary` indigo | `surfaceDark` with border |
| **Input Area** | `surfaceLight` | `surfaceDark` |
| **Send Button** | `primary` circular | `primary` circular |
| **Tip Banner** | `infoLight` blue | `info` with opacity |
| **Quota Banner** | Adaptive (green/yellow/red) | Adaptive (green/yellow/red) |
| **Text** | `textPrimaryLight` | `textPrimaryDark` |
| **Shadows** | `cardLight` | `cardDark` |

---

## 6. Google Play Store Compliance

### 6.1 Privacy Policy Updates (Required)
**Add to existing privacy policy:**
```
AI Chatbot Feature:
- We use Google Gemini AI to answer your educational questions
- Conversations are processed in real-time and not stored
- We do not save chat history on our servers or your device
- Daily usage is limited to 15 messages per user
- Your messages are subject to Google's AI safety filters
```

### 6.2 Data Safety Section (Play Console)
| Field | Value |
|-------|-------|
| Data collected | "App interactions, Diagnostics" |
| Data shared | "AI processing (Google Gemini API)" |
| Encryption | "Data encrypted in transit" |
| Retention | "No chat history retained" |

### 6.3 App Store Listing Updates
**Short description add:**
"AI-powered educational assistant - ask anything! (15 messages/day)"

**Full description add:**
```
🤖 AI Educational Assistant
Ask our AI anything about English, Computer, Digital Marketing, Web Development, 
and YouTube growth! Get instant answers powered by Google Gemini AI.

Note: 15 messages per user per day to ensure service quality.
```

### 6.4 In-App Disclaimers (Required)
**On first chat open:**
> "AI responses are generated automatically and may not always be accurate. 
> Please verify important information from official sources."

**Tooltip/info button:**
> "Messages are processed by Google AI. We don't store your conversations."

### 6.5 Content Safety Implementation
| Safety Layer | Implementation |
|--------------|----------------|
| Input filtering | Block profanity list (200+ words) |
| Input length | Max 500 characters |
| Output filtering | Gemini's built-in safety (already active) |
| Blocked topics | Automatically handled by Gemini |

### 6.6 Permissions Required
```xml
<!-- No new permissions needed -->
<!-- Existing INTERNET permission sufficient -->
```

---

## 7. API Integration Specification

### 7.1 Gemini API Setup
**Provider:** Google AI Studio (Gemini Flash 1.5/2.0)  
**Free Tier:** 1,500 requests/day, 1M tokens/min  
**Endpoint:** `generativelanguage.googleapis.com`

### 7.2 API Key Security
**Storage method:** Environment variable + API restrictions
```
1. Create key in Google AI Studio
2. Restrict to Android app (package name + SHA-1)
3. Store in `--dart-define` during build
4. No hardcoding in source
```

### 7.3 Request/Response Format
```dart
// System prompt (educational context)
const String _systemPrompt = '''
You are an educational assistant for the Zaroori Sawal app.
The user is learning: English, Computer, Digital Marketing, Web Development, or YouTube skills.
- Keep responses concise (max 150 words)
- Be encouraging and educational
- If unsure, say "I don't know" rather than guessing
- Never provide harmful, illegal, or inappropriate content
- Focus on the educational topics mentioned above
''';

// Request structure
{
  "contents": [{
    "role": "user",
    "parts": [{"text": "What is photosynthesis?"}]
  }],
  "systemInstruction": {
    "parts": [{"text": _systemPrompt}]
  },
  "safetySettings": [
    {"category": "HARM_CATEGORY_DANGEROUS", "threshold": "BLOCK_MEDIUM_AND_ABOVE"}
  ]
}
```

### 7.4 Rate Limit Handling
| HTTP Status | Action |
|-------------|--------|
| 200 OK | Display response, decrement quota |
| 429 Quota | Show "Service busy, try again" |
| 400 Safety | Show "Cannot answer that type of question" |
| 500 Error | Show "Temporary issue, please retry" |
| Timeout | Show "Slow connection, check internet" |

---

## 8. Error Handling & Edge Cases

### 8.1 Network Failures
| Scenario | UX Response |
|----------|-------------|
| No internet | "Connection required for AI chat. Check your network." |
| Slow connection | Timeout after 15s, "Slow connection, try again" |
| API timeout | Retry once, then "Service temporarily unavailable" |

### 8.2 Quota Edge Cases
| Scenario | Handling |
|----------|----------|
| User changes device date | Server-side validation (if implemented) or accept small abuse |
| App killed mid-conversation | Conversation lost (expected, no history) |
| Multi-device same user | Each device has separate 15 quota (acceptable) |
| Midnight during chat | Next message uses new day's quota |

### 8.3 API Key Issues
| Issue | Detection | Action |
|-------|-----------|--------|
| Invalid key | 403 Forbidden | Log error, show "Feature unavailable" |
| Key revoked | 403 | Same as above |
| Key leaked | Usage spike in console | Rotate key immediately |

### 8.4 Content Safety Edge Cases
| Input Type | Response |
|------------|----------|
| Profanity | "Please keep conversations educational and respectful." |
| Personal info (email/phone) | "Avoid sharing personal information." |
| Off-topic (politics, etc) | "I focus on educational topics. Ask about your learning subjects!" |
| Harmful request | "I cannot answer that. Let's get back to learning!" |

---

## 9. Testing & QA Checklist

### 9.1 Functional Testing
- [ ] Quota initializes to 15 on first use
- [ ] Quota decrements correctly per message
- [ ] Quota resets at midnight
- [ ] Input disabled at 0 quota
- [ ] Game suggestion appears at 0 quota
- [ ] Daily tip rotates correctly
- [ ] Chat clears on exit
- [ ] Back navigation works properly

### 9.2 API Testing
- [ ] Gemini API returns valid responses
- [ ] 429 error handled gracefully
- [ ] Timeout handled after 15s
- [ ] Safety filters block inappropriate content
- [ ] System prompt works (educational responses)

### 9.3 Security Testing
- [ ] API key not in source code
- [ ] API key not in APK strings
- [ ] Quota cannot be manipulated (date change check)
- [ ] No PII in logs

### 9.4 UI/UX Testing
- [ ] Quota display updates in real-time
- [ ] Empty state shows on first open
- [ ] Exhausted state shows correctly
- [ ] Tip banner visible and readable
- [ ] Game deep link works
- [ ] Music continues in game
- [ ] **Floating button disappears when quota reaches 0**
- [ ] **Floating button reappears next day after quota reset**
- [ ] **Floating button visible on all allowed screens (when quota > 0)**
- [ ] **Floating button hidden on Game screen**
- [ ] **Floating button hidden on Learning Video screen**
- [ ] **Drag to move button works smoothly**
- [ ] **Button position persists after app restart**
- [ ] **Tap opens chat near button position**
- [ ] **Tap outside to close chat works**
- [ ] **Tap floating button again to close works**
- [ ] **App Theme bubbles render correctly in light mode**
- [ ] **App Theme bubbles render correctly in dark mode**
- [ ] **ZS Assistant header shows quota badge**
- [ ] **Simple input (text + send) works**
- [ ] **Edge snap behavior works**

### 9.5 Compliance Testing
- [ ] Privacy policy updated
- [ ] Disclaimer shown on first use
- [ ] Data safety section filled
- [ ] No permission changes needed

---

## 10. Monetization & Future Scaling

### 10.1 Current State (Free)
- 15 messages/user/day
- ~100 users/day capacity
- Gemini free tier

### 10.2 Phase 2: Expansion Options
| Option | Implementation | Revenue |
|--------|---------------|---------|
| **Watch ad for +5 messages** | AdMob rewarded ad | Ad revenue |
| **Premium: Unlimited messages** | In-app purchase ($2.99/month) | Direct revenue |
| **Paid API upgrade** | Gemini paid tier ($0.15/million tokens) | Better UX |

### 10.3 Scaling Decision Matrix
| Daily Users | Current Setup | Recommended Action |
|-------------|---------------|-------------------|
| < 100 | 15 msg free | Maintain status quo |
| 100-500 | Hitting limits | Implement rewarded ads |
| 500+ | Severe limits | Premium tier + paid API |

---

## 11. Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create `ai_chat_service.dart` with Gemini integration
- [ ] Create `chat_quota_service.dart` with Hive storage
- [ ] Create `daily_tip_service.dart` with tip rotation
- [ ] Create `floating_button_service.dart` for position persistence
- [ ] Create `floating_chat_button.dart` widget with drag functionality
- [ ] Create `global_chat_overlay.dart` for app-wide availability
- [ ] Create `chat_screen.dart` with App Theme UI
- [ ] Add API key with restrictions

### Phase 2: UI Polish (Week 2)
- [ ] Implement quota banners with color coding
- [ ] Add daily tip banner
- [ ] Implement game suggestion chip
- [ ] Add empty and exhausted states
- [ ] Implement error states
- [ ] Implement App Theme chat bubbles (light & dark mode)
- [ ] Add ZS Assistant header with quota badge
- [ ] Implement simple text input + send button
- [ ] Implement tap-outside-to-close behavior
- [ ] Test floating button on all screens (except Game/Learning Video)

### Phase 3: Compliance (Week 3)
- [ ] Update privacy policy
- [ ] Add in-app disclaimers
- [ ] Implement content safety filtering
- [ ] Fill Data Safety section in Play Console
- [ ] Add app description updates

### Phase 4: Testing (Week 4)
- [ ] Run full QA checklist
- [ ] Test quota edge cases
- [ ] Verify API error handling
- [ ] Check security (no exposed keys)
- [ ] Beta testing with 10 users

### Phase 5: Launch (Week 5)
- [ ] Deploy to Play Store
- [ ] Monitor quota usage in Cloud Console
- [ ] Collect user feedback
- [ ] Iterate based on analytics

---

## 12. Success Metrics

### 12.1 Technical Metrics
| Metric | Target |
|--------|--------|
| API response time | < 3 seconds |
| Error rate | < 5% |
| Daily active chat users | Track growth |
| Messages per user | 8-12 (engagement indicator) |

### 12.2 User Experience Metrics
| Metric | Target |
|--------|--------|
| Game click-through rate | > 20% when quota exhausted |
| Tip engagement | Track if users read tips |
| Return rate next day | > 60% (quota refreshes) |
| User rating impact | Maintain 4.5+ stars |

---

## 13. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| API key leaked | Low | High | Restrict to app package, monitor usage |
| Quota abuse | Medium | Medium | Daily reset logic, accept small abuse |
| Play Store rejection | Low | High | Compliance checklist, safety filters |
| Cost overrun | Low | Medium | Free tier monitoring, hard limits |
| Poor AI responses | Medium | Medium | System prompt tuning, user feedback |

---

## 14. Appendix

### 14.1 Dependencies to Add
```yaml
dependencies:
  google_generative_ai: ^0.4.0  # Gemini SDK
  # Existing dependencies sufficient (hive, http, provider)
```

### 14.2 File Structure
```
lib/
  screens/
    chat_screen.dart              # Main chat UI (App Theme style)
    chat_overlay_screen.dart      # Floating chat overlay container
  services/
    ai_chat_service.dart          # Gemini API
    chat_quota_service.dart       # Quota management
    daily_tip_service.dart        # Tips rotation
    content_safety_service.dart   # Safety filters
    floating_button_service.dart  # Button position persistence
  models/
    chat_message.dart             # Message model (memory only)
    daily_tip.dart                # Tip model
    button_position.dart          # Floating button position
  widgets/
    chat_bubble.dart              # Message bubble (App Theme style)
    quota_banner.dart             # Quota indicator
    tip_banner.dart               # Daily tip display
    floating_chat_button.dart     # Draggable floating button
    chat_header.dart              # ZS Assistant header
    chat_input_area.dart          # Simple text + send input
    global_chat_overlay.dart      # Overlay wrapper for all screens
```

### 14.3 Daily Tips Dataset (Sample)
```json
[
  {"day": "monday", "category": "English", "tip": "Affect = verb (to change), Effect = noun (result)"},
  {"day": "tuesday", "category": "Computer", "tip": "RAM is temporary memory. More RAM = faster multitasking"},
  {"day": "wednesday", "category": "Marketing", "tip": "Post when your audience is online. Check Insights!"},
  {"day": "thursday", "category": "Web Dev", "tip": "Mobile-first design: 60% of users browse on phones"},
  {"day": "friday", "category": "YouTube", "tip": "First 30 seconds are critical. Hook viewers immediately!"},
  {"day": "saturday", "category": "Study", "tip": "Spaced repetition: Review notes after 1 day, 3 days, 7 days"},
  {"day": "sunday", "category": "Motivation", "tip": "Progress, not perfection. Every expert started as a beginner"}
]
```

---

## Document Control
- **Version:** 1.0
- **Date:** February 2026
- **Status:** Implementation Ready
- **Owner:** Zaroori Sawal Development Team
- **Next Review:** Post-launch (4 weeks)
