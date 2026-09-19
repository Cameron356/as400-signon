# as400-signon

IBM **AS/400 / 5250-style Sign On** for the Linux virtual console — a drop-in
replacement for Debian’s stock TTY login presentation (`agetty` / `/etc/issue`).

Built to match the fTower **homelab console dashboard** aesthetic: one phosphor
green, intensity and reverse-video for emphasis, uppercase labels, fixed-column
values, and CL-flavoured wording — not “green hacker text.”

## Goal

When you switch to a getty on tty1–ttyN (or open a new VT), you should see a
**Sign On** screen that feels like OS/400, then authenticate with the real
Linux account (PAM). After a successful login, the session continues normally
(shell, or hand off to an existing dashboard like `hldash` / tmux `dash`).

This project owns the **login presentation + getty integration**. It does not
replace PAM, systemd, or SSH.

## Design rules (5250)

- **One colour** (green). Warn/critical exceptions may use amber/red sparingly;
  never use bright white for “warm” status (reads as broken phosphor).
- **Intensity + reverse video** for emphasis, not rainbow gauges.
- **Uppercase field labels** with dotted leaders to a value column where it helps.
- **ASCII + verified box-drawing** only — console fonts are often 512-glyph PSF
  with no braille; what looks fine over SSH can garbage on the physical VT.
- Prefer OS/400 vocabulary: *Sign On*, *User*, *Password*, *System*, *Subsystem*
  — not “username/login portal.”

## Non-goals (v1)

- Graphical greeters (GDM/LightDM/SDDM)
- Replacing SSH banners (optional later)
- Touch/GUI
- Network authentication UIs beyond what PAM already does

## Target platform

- Debian (and derivatives) using `agetty` + `systemd` getty units
- Linux virtual terminals (`/dev/ttyN`), not only serial
- First deployment target: **fTower** (existing 5250 dashboard on tty1)

## Proposed layout

```
as400-signon/
  README.md                 # this file
  docs/                     # design notes, screenshots, PAM notes
  scripts/                  # install / enable helpers
  issue/                    # /etc/issue-style static art (optional)
  src/ or bin/              # sign-on binary or shell UI (TBD)
```

Exact implementation (pure shell `agetty` issue + `login`, custom wrapper,
`fbterm`, etc.) is chosen in the first implementation pass — correctness and
theme fidelity beat cleverness.

## Status

Scaffolding. Implementation in progress.
