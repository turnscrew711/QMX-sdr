# FT8 Support with QMX – Requirements and Architecture

## What FT8 Needs (Standard WSJT-X–Style)

1. **Radio control (CAT)**
   - Set frequency (VFO) – we have FA/FB, setFrequencyA/B.
   - Set mode to FSK/digi – we have setMode(6) (MD6).
   - PTT: TX for transmit windows, RX otherwise – we have setTransmit(true/false).

2. **Receive path**
   - Audio (or baseband IQ) from the radio at ~48 kHz (or IQ at 48k and we derive audio).
   - Decode FT8 frames (15 s blocks, FSK in 6.25 Hz bins) and display in a decode list.

3. **Transmit path**
   - Encode user message (CQ, reply, etc.) to FT8 symbols.
   - Generate AFSK audio (or equivalent) and send to the radio’s audio input.
   - Key PTT at the start of the TX window and unkey at the end.

## QMX-Specific

- **USB (Mac/PC):** One cable gives CAT (serial) + audio (built-in sound card). So WSJT-X can do full FT8: CAT for frequency/mode/PTT, audio in/out for decode/encode.
- **Bluetooth (this app):** Only CAT is available over BLE. There is **no audio path** to/from the QMX over Bluetooth. So:
  - **RX:** We can decode FT8 from the **IQ stream** when the app has IQ running (e.g. QMX over USB as an IQ source, or another SDR). No QMX audio device is required for RX decode.
  - **TX:** To transmit FT8 from the app we would need to send audio to the QMX. Over BLE we cannot; that would require the QMX to be connected via **USB** and the app to have access to the QMX’s USB audio device (realistic on macOS, not on iOS with BLE-only connection).

## App Architecture (Current and Planned)

- **CAT:** Implemented for frequency, mode (including Digi = FSK), and PTT. Enough for an external FT8 app (e.g. WSJT-X) to drive the QMX; also enough for our app to control the radio when we add FT8.
- **IQ:** When “Start” is used with a USB IQ source (e.g. QMX in IQ mode), we have baseband IQ and a waterfall. We can feed that into an FT8 decoder (future) to populate the decode list.
- **Digi mode UI:** When the user selects **Digi** from the Mode menu, the app switches to FSK (MD6) and **replaces the VFO B waterfall/spectrum** with an **FT8 interface** (decode log, and later message composition and TX controls). VFO A remains the main tuning/waterfall; the FT8 panel uses the current frequency for decode/transmit.

## What’s Implemented vs What’s Left

| Piece | Status |
|-------|--------|
| CAT: frequency, mode (FSK), PTT | Done |
| Mode menu: SSB / CW / Digi | Done |
| When Digi selected → show FT8 panel instead of VFO B | Done (this change) |
| FT8 decode from IQ | Not yet (needs FT8 lib, e.g. C lib bridged to Swift) |
| FT8 encode + audio out to radio | Not yet; requires USB audio path to QMX (Mac) or alternate path |
| Message composition, CQ/reply UI | Placeholder in FT8 view; logic pending decode/encode |

## Summary

- **Full FT8 “in the app”** with a **Bluetooth-connected QMX** is **receive-only** from our side: we can add decode-from-IQ and show decodes; we cannot key the radio with app-generated audio over BLE.
- **Full duplex FT8** (decode + encode) is possible when the QMX is connected via **USB** and the host has access to the QMX sound device (e.g. macOS app with USB audio + CAT). Then we’d still need an FT8 decode/encode pipeline and the UI already prepared in the FT8 panel.

---

## What We Need to Do for Full Duplex FT8

### 1. Receive path (decode)

| Step | What to do |
|------|------------|
| **FT8 decode library** | Integrate a C/C++ FT8 decoder (e.g. [ft8_lib](https://github.com/kgoba/ft8_lib), or code from WSJT-X) via Swift bridging. Input: baseband IQ or audio at 12000 Hz (FT8 bandwidth). Output: decoded messages (callsign, grid, SNR, etc.). |
| **Feed IQ into decoder** | When IQ is running (e.g. QMX over USB in IQ mode), mix down from current VFO to baseband, resample to 12 kHz (or whatever the decoder expects), and run the decoder every 15 s on the relevant sub-band (e.g. 0–3 kHz for FT8). |
| **Decode list UI** | FT8View already has a decode log; populate it from decoder output (time, dB, message, optional “Reply” action). |

### 2. Transmit path (encode + audio out)

| Step | What to do |
|------|------------|
| **FT8 encode library** | Encode a message (e.g. `CQ CALL GRID`) into FT8 symbols, then generate AFSK (e.g. 1200 Hz base, 6.25 Hz FSK). Use same library as decode or WSJT-X–compatible code. |
| **Audio output to QMX** | **Critical:** We must send that audio to the QMX’s **microphone / line input**. That only works when the QMX is connected via **USB** and the OS sees it as an audio device. On **macOS**: use Core Audio to select the QMX as the **output** device and play the encoded buffer during the TX window. On **iOS**: if the QMX is connected via USB-C and appears as a USB audio device, we can try the same; if the app only has BLE to the QMX, there is **no audio path** and TX from the app is not possible. |
| **PTT + timing** | FT8 uses 15 s slots; TX windows are the first ~1.2 s of each slot. Sync to UTC (or use decoder sync). At start of our TX window: setMode(6), setTransmit(true), start playing encoded audio; at end: stop audio, setTransmit(false). CAT is already in place; we need a timer/scheduler that knows the slot boundaries. |

### 3. Connection / platform matrix

| Connection | RX (decode) | TX (encode + PTT) |
|-----------|-------------|--------------------|
| **QMX over USB (Mac)** | Yes: IQ from QMX → decode in app. | Yes: app plays AFSK to QMX USB audio, CAT PTT. |
| **QMX over USB (iOS)** | Yes: if IQ capture works with QMX USB. | Maybe: if iOS exposes QMX as output device over USB-C. |
| **QMX over BLE only** | Yes: decode from IQ if IQ source is something else (e.g. another SDR). | **No:** no audio path to QMX over Bluetooth. |

### 4. Suggested implementation order

1. **RX only:** Add FT8 decode from IQ (bridge C lib, wire IQ → decoder → decode list). Works with USB IQ source; proves the pipeline.
2. **TX audio path:** On macOS, add “use QMX as audio output” and a test tone; confirm we can drive the QMX’s TX with app-generated audio.
3. **TX encode:** Add FT8 encode, then play encoded AFSK during TX window with PTT keyed.
4. **Scheduler:** Add 15 s slot sync and only TX in the correct window.
5. **UI:** Reply-from-decode, cycle indicator, and any settings (e.g. audio device selection).
