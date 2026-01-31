# Camera Capture System

## 1. What This Feature Is
The Camera Capture System is the production-grade recording workspace for Self Tape Studio. It unifies framing, exposure, audio, slate delivery, and take management so you can create audition-ready video and photo assets without leaving the app.

## 2. When You Should Use It
- Before recording: set framing, exposure, focus, and audio levels for a new self-tape, callback, PiP slate, or keyframe photo.
- During setup: load sides/teleprompter, confirm orientation, and lock AE/AF before talent steps in.
- Between takes: review the last take quickly, adjust exposure/focus, and record again.
- Before submission: capture any required slate or pickup shots without rebuilding a project.

## 3. What This Feature Controls (Mental Model)
- **Framing consistency** – orientation locks, guides, and PiP overlays keep the composition stable.
- **Exposure & focus stability** – tap-to-focus, AE/AF lock, and exposure compensation prevent flicker or shifts mid-take.
- **Audio capture** – input selection and live meters ensure clean levels before you roll.
- **Take continuity** – each take is tracked to the active session/scene so exports stay organized.
- **Slate compliance** – slate prompts and PiP slate modes ensure required identifiers are captured.
- **Teleprompter/sides visibility** – in-app sides keep eyes up and performance anchored.

## 4. How It Works (High-Level)
- The camera opens in the context of the current session and scene, inheriting project/session settings (orientation, sides, slate prompts, audio prefs).
- Gesture layer handles focus/exposure: single tap to focus/lock, drag slider to adjust exposure, double tap to reset when needed.
- Recording produces a take tied to the active scene and session; metadata (orientation, ratings, notes) follow the take into Take Review.
- Slate modes (standard or PiP) run inside the same capture surface so you don’t leave the camera to fulfill slate requirements.
- Teleprompter/sides render over the preview without affecting the recorded video.
- Exiting camera hands off to Take Review only after capture teardown completes, keeping state consistent.

## 5. Step-by-Step Usage
1) Open the camera from your project/session (Scenes or Slates entry).  
2) Confirm orientation and frame the shot; enable guides if needed.  
3) Tap the preview to focus and lock AE/AF; use the exposure slider to fine-tune brightness.  
4) Check audio input/meter; adjust distance or gain until peaks sit comfortably below red.  
5) For slates, open slate mode (or PiP slate) and read the displayed prompt.  
6) For teleprompter, load sides and set scroll speed before rolling.  
7) Press record; deliver the take. Stop when finished.  
8) Repeat for pickups or alternates; use quick review between takes if desired.  
9) Exit camera; you’ll land in Take Review with the new take(s) attached to the session/scene.

## 6. Common Mistakes & Misunderstandings
- **Focus shifts mid-take:** Make sure you tap to lock AE/AF before recording; bright backgrounds can cause hunting if left unlocked.
- **Exposure jumps between takes:** Re-lock exposure after significant lighting changes; the slider is per-take, not global.
- **Audio too hot:** Watch the meter before rolling—peaks in red will distort even if the take looks fine.
- **Slate requirements missed:** Use the slate prompt or PiP slate mode instead of improvising; it records the required identifiers into the correct slot.
- **Teleprompter still visible on exit:** Hide or pause the teleprompter before rolling if you don’t want motion in reflections; it doesn’t burn into the video.

## 7. Advanced / Pro Tips
- Build a “reset” ritual: double-tap to clear focus/exposure, then tap to lock on the actor’s eyes before each take.
- Use PiP slate for dual-angle compliance without re-framing; pick portrait/landscape components that match casting specs.
- For fast pickups, keep the same scene active—takes inherit scene/timestamp metadata automatically.

## 8. System Notes (Hidden In-App)
- Teleprompter/sides are overlay-only and never baked into recorded media.
- AE/AF state and exposure compensation reset when leaving the camera or changing major modes; re-lock at the start of each capture block.
- Take metadata (orientation, ratings, slate links) is persisted for downstream export and submission flows.
