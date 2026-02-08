# Proposed UI Changes (QMX-SDR)

Based on Groups.io research. Items marked **Implemented** are done; others remain optional for future iterations.

---

## 1. **RIT on the main screen** — **Implemented**

- **Current:** RIT is only in **Menu → RIT control** (on/off, clear, ±100 Hz).
- **Proposal:** Add a compact RIT row or a single “RIT” control on the main screen (e.g. next to the frequency bar or in the bottom bar): small “RIT” label, +/- step buttons, and optionally an “RIT on” indicator or toggle. Tapping could open the full RIT menu or cycle on/clear/off.
- **Rationale:** Many operators use RIT frequently; reducing taps (menu → RIT → adjust) would help.

---

## 2. **SWR / protection warning (when CAT supports it)**

- **Current:** About & limitations explains that SWR and “SWR protection tripped” are not available via CAT.
- **Proposal:** If QMX firmware later adds a CAT command for SWR protection status (or similar):
  - Show a clear indicator when protection has tripped (e.g. “SWR protection” or “TX disabled”).
  - Optionally disable or warn before TX from the app, or show a one-time tip that the user should check the radio’s LCD.
- **Rationale:** Requested on Groups.io for “operating without the LCD”; improves safety when using the app as the main interface.

---

## 3. **Tune button (optional)**

- **Current:** No Tune control in the app (removed earlier). About text explains CAT doesn’t support full CW keying.
- **Proposal:** Add a **Tune** control in the menu (e.g. under Tools or RIT): one button that sends TX for ~0.5 s then RX, for antenna tuning. Keep it out of the main bar to avoid clutter.
- **Rationale:** Some users still want a quick way to key the rig for tuning from the app without touching the radio.

---

## 4. **Frequency bar: show RIT offset**

- **Current:** Frequency bar shows main frequency and mode only.
- **Proposal:** When RIT is on and offset ≠ 0, show a small “RIT +200” or “RIT −100” (or “RIT 0”) next to the frequency or below it, so the operator sees the effective receive frequency at a glance.
- **Rationale:** Requires RIT offset in CAT (e.g. a read command if QMX adds one); until then, we could show “RIT on” when `ritEnabled` is true and leave offset as “?” or hide it.

---

## 5. **IQ / USB status on the main screen**

- **Current:** No explicit “IQ connected” or “USB audio” indicator on the main view.
- **Proposal:** When IQ is running, show a small indicator (e.g. “IQ” or a dot) near the Start/Stop button or in the top bar; if the capture service reports “no USB input,” show a short message or tooltip: “Enable IQ mode on QMX and connect USB.”
- **Rationale:** Aligns with Groups.io guidance (enable IQ in menu, connect USB); reduces confusion when the waterfall is empty.

---

## 6. **Band / mode from CAT after connect**

- **Current:** Band is inferred from frequency and `selectedBandId`; mode comes from CAT.
- **Proposal:** On first connect (or when opening the app with an already-connected radio), optionally request FA/FB/MD and set `selectedBandId` from the current frequency so the band selector and SSB LSB/USB logic match the radio immediately.
- **Rationale:** Improves “software as front-end” experience when the user has already set band/mode on the radio.

---

## 7. **Presets: show mode and optional RIT**

- **Current:** Presets save/recall frequency and mode.
- **Proposal:** In the presets list, show mode (and optionally “RIT on” if we ever store/recall RIT). When recalling, optionally “clear RIT” or “set RIT off” so the operator starts from a known state.
- **Rationale:** Makes presets more predictable and easier to use with RIT.

---

## 8. **Accessibility and layout**

- **Proposal:** Review VoiceOver labels for all interactive elements (waterfall, spectrum, scale, Mode, Band, VFO, Menu, RIT, SWR meter, presets). Ensure minimum touch targets (e.g. 44 pt) for RIT and other small controls. Consider a “Compact” vs “Spacious” layout option if users report crowding on small phones.
- **Rationale:** Broader usability and alignment with platform guidelines.

---

## Summary of implementation (sync + proposed UI)

- **Sync on connect:** When Bluetooth connects, the app calls `requestFullState()` (FA, FB, MD, RT), then after 0.6 s sets `selectedBandId` from the radio frequency and `selectedVFO = .a`.
- **CATClient:** `onConnectionChanged` callback; `requestFullState()`. RIT clear, on/off, request status; RU/RD variable-length; RT parsed.
- **Main screen:** RIT bar (RIT label, −100 / +100); frequency bar shows "RIT on" when RIT enabled; top bar shows "IQ" or "IQ (no USB)" when IQ is running.
- **Menu:** Tools → **Tune** (TX 0.5 s); Presets list shows mode; on recall, clear RIT and set RIT off.
- **Accessibility:** Labels/hints for frequency, Mode, Band, VFO, Menu, RIT buttons, S-meter, VFO panels.
