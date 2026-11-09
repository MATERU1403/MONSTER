# MONSTER settings guide: what to run against other exploiters

Built from what is on this machine, so every pick says where it comes from. Read the tags:

- **[D]** a live duel against BasedHub (morrowindf vs gotham77r), scored kills minus deaths, one 120 s duel per batch (`_bsweep_m.jsonl`). One duel is noisy, and the scores top out at 11-12 kills, so "kept" means "not worse", not "proven best".
- **[S]** a server rule measured on the two-alt rig (in the ragebot header and the codec notes): shot origin within 17 studs of the server body; hit point within 22 studs of the part; a hop of more than ~10 studs needs 0.10-0.23 s before shots count; stomp counts 1.5-9.5 studs up, a missed stomp blocks the next for 0.55 s, nothing counts during a reload; lag 0.24 s; a shot closer than 0.14 s to the last one is lost; packets can only carry coordinates under 1024.
- **[C]** a measurement written into the setting's own description in the code.
- **[T]** from the tests this session. **[I]** my inference. **[-]** no data: keep your tuned value.

## Read this first

1. **The only opponent ever measured is BasedHub.** Nothing here was tested against Unnamed Enhancements, Neverlose or any other script. Against a different script the [D] picks are a starting point, not a result.
2. **The attack engine with results is the one on the Ragebot / Maneuvers tabs** (the BasedHub-derived ragebot with the sky-void strike): 22 hits and 0 taken in a 95 s void round earlier today, and 11-12 kills with 0 deaths in the sweep (Nov 3-4). **This session it landed nothing either** (run L1 against gotham77r: 0 hits), and **MONSTER's own Rage tab landed 1 of about 320 salvos**. So something blocked shots after the first knock-out: possibly a server-side flag on morrowindf, not the settings. Treat every pick below as untested until a shot is accepted again.
3. **The resolver does not beat the plain replicated position** in the recorded runs (static, follow, orbit, void: no gain; only jitter improved a little). Do not expect it to find a hidden body.
4. **Error 260 hazard.** morrowindf's Roblox log shows the server kicking it with reason 260 seven times today. The code notes tie 260 to far (past 1024) packets, and your saved Void far / high / jitter are 1e9 / 1e6 / 1e7 studs. After my last fake-position test I found BasedHub's Ragebot on, the real body thousands of studs out, and a steady stream of 52-byte body packets the codec cannot read. That fits the far-packet story but is **not confirmed as the cause**. Safest combination: Fake position with Where = Void and Void position = Sky, Wait in = Sky (not Void), and BasedHub's Ragebot off while you test it.

## Ragebot tab

### Ragebot

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Ragebot | Tap its key: on/off. Hold it: pick who to hunt. | blink | on | on | on | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Mouse reach (20..300) | How near the pointer they must be. | 90 | - | - | 90 | [-] your tuned value (vs-BASED config); no duel batch covers it. |

### Targeting

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Priority | Who goes first of those that can be shot. | smart | threat | closest | closest | [D] R4 kept (10-1 duel, with stance hold / stick off). Threat-first only when several people hunt you. |
| Threat weight (0..10) | Smart: how much a gun out, a shot or aim at you counts. | 1 | 4 | 2 | 2 | [D] R4. Only read when Priority = Smart. |
| Spread weight (0..10) | Smart: how much one not killed lately counts. | 1.5 | 2.5 | 1 | 1 | [D] R4. Only read when Priority = Smart. |
| Stick to target | Keeps on a target once a stay has begun. | on | on | off | off | [D] R4 kept with it off. Turn on in crowds so it does not flip targets. |
| Salvo | Each gun's next shot goes at someone else in reach. | on | on | off | off | [D] R5 kept (12-0). It only matters with 2+ targets, so 1v1 it changes nothing. |
| Salvo wait (0..SALVO_WAIT) | How long a held shot may wait for one that stands. | SALVO_WAIT | - | 0.7 | 0.7 | [D] R5. |
| Pipeline | Shoots another while a body is not ready to stomp. | on | on | off | off | [D] R5 kept (12-0). Only matters with 2+ targets. |
| Walls | Aims just outside a wall at one hiding in it. | on | on | off | off | [D] R5 kept (12-0). |

### Guns

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Guns | All held at once. Fists and wallet are put away. | { "[Rifle]", "[AUG]" } | [Double-Barrel SG], [Rifle] | [Double-Barrel SG], [Rifle] | [Double-Barrel SG], [Rifle] | [D] R6: adding [Drum-Shotgun] together with fire=all, torso, smart reload off, one-tap off, safe armor on went 1-6. Do not undo any of those. |
| Smart reload | Reloads the gun that brings back the most kills first. | on | on | on | on | [D] R6 (turning it off was part of the 1-6 batch). |
| Whole-turn taps | Pounces with a turn the server holds whole: 2 shells at the torso. | off | on | on | on | [D] R6 (turning it off was part of the 1-6 batch). |
| Safe armor | Buys armor when hunters are down, at the pad by home. | off | off | off | off | [D] R6 (turning it on was part of the 1-6 batch). |

### Prediction

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Lead time (0..1) | How far ahead a moving target is aimed. | SEEN_LATE | 0.24 | 0.24 | 0.24 | [S] measured lag = ping 0.059 + interpolation 0.180 = 0.24 s. [D] R7 custom 0.2 / 0.15 / 2.5 with learn and snipe off = 0 kills. |
| Lead base (0..0.5) | The fixed part. Auto uses 0.1. | LEAD_BASE | 0.1 | 0.1 | 0.1 | [D] R7 (see Lead time). |
| Ping multiplier (0..8) | Times your ping. Auto uses 2. | 2 | 2 | 2 | 2 | [D] R7 (see Lead time). |
| Learn | Aims along their real path, curves too, and learns each player's moves. | on | on | on | on | [D] R7 (turning it off was part of the 0-kill batch). |
| Sky sniper | Shoots a bot waiting in the sky where its next spot will be. | on | on | on | on | [D] R7 (turning it off was part of the 0-kill batch). |

### Stomp

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Stomp | Stomps the moment you are over the body, in the air too. A carrier is shot down first. | on | on | on | on | [S] a stomp counts from 1.5 to 9.5 studs over a knocked body. |
| Stomp height (STOMP_LOW..STOMP_UP) | It counts from 1.5 to 9.5 studs up. | 3.5 | - | - | 3.5 | [S] inside the 1.5-9.5 window. [D] R8 (5 studs, retry 0.8, forceHit off) = 1 kill. |
| Stomp retry (STOMP_MISS..2) | A missed stomp blocks the next for 0.55 s. | STOMP_MISS | - | - | 0.55 | [S] a missed stomp blocks the next for 0.55 s; slower only wastes time. [D] R8. |
| Cross fire | A free gun knocks anyone else hunted in reach. | on | on | off | off | [D] R5 kept (12-0). 2+ targets only. |

### Timing

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Arrive delay (ARRIVE..1) | Wait after a long hop before the first shot. | ARRIVE | 0.05 | 0.15 | 0.15 | [S] a hop of more than ~10 studs needs 0.10-0.23 s before shots count, so your saved 0.05 loses shots. [D] R3 kept at 0.15. |
| Bait | With Lure off: stops at home so a follower comes to you. | on | on | off | off | [D] R2 kept off (11-0). |
| Flak | A target that never holds still is shot at the places it has been. | on | on | on | on | [D] R9: flak + ambush + pounce all off = 0 kills. |
| Open flak | Off: flak only from inside a wall. Safer against many. | on | on | off | off | [D] R2 kept off (safer against many, per its own description). |
| Lure | Shows for a blink so a hider or follower comes, then shoots where it does. | on | on | off | off | [D] R1: turning lure + ring lure off took the duel from 1-7 (baseline) to 11-0. The biggest single change in the data. A bot that learns where you show up counters lures. |
| Ring lure | One that keeps a set way off you: climbs past its shots, shoots its ring. | on | on | off | off | [D] R1 (see Lure). |
| Ambush | One that shows itself is shot where it goes next, from far off. | on | on | on | on | [D] R9. |
| Pounce | With a gun that knocks in one shot, it goes in close instead. | on | on | on | on | [D] R9. |
| Press | A hider that keeps coming back to one spot is shot there. Backs off if hurt. | on | on | off | off | [D] R2 kept off. |
| Armor pad trap | One that loses armor is shot on the pad it buys it back at. | on | on | off | off | [D] R2 kept off. |
| Seen time (0..0.5) | How long a target must hold still first. | 0.05 | 0 | 0.1 | 0.1 | [D] R3 kept. |
| Shield lead (0..1) | How early you are in place before a shield ends. | 0.1 | 0.1 | 0.3 | 0.3 | [D] R3 kept. |
| Rate margin (RATE_MARGIN..0.2) |  | RATE_MARGIN | 0.015 | 0.015 | 0.015 | [D] R10: 0.03 with switch gap 0.2 = 8 kills (worse). |
| Switch gap (SWITCH_GAP..0.6) | Closer than 0.14 s and one shot is lost. | SWITCH_GAP | 0.14 | 0.14 | 0.14 | [S] closer than 0.14 s and one shot is lost. [D] R10. |

## Maneuvers tab

### Position

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Hover | Where you shoot from. Orbit to Wave are paths round them. | above | adaptive | adaptive | adaptive | [-] your tuned value; no duel batch covers Maneuvers. |
| Frenzy | Hops between places of that shape and shakes in each. Uses at least 60 studs. | on | on | on | on | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Never twice | A swarm never goes back where it was: flak misses. Wider swarms. | off | on | on | on | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Noclip | Your body passes through walls while it works. | on | on | on | on | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Bunker | Stands inside a wall or floor: their shots hit the wall. | on | on | on | on | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Expose max (0..1) | Then on to a new place. 0 is no limit. | 0 | 0 | 0 | 0 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Radius (3..HOVER_MAX) | For every place but Above. Kept inside your guns' reach. | 6 | 59 | 59 | 59 | [-] kept inside your guns reach (shotgun 120, rifle 250 studs). |
| Jitter | Keeps moving while it is there. | on | on | on | on | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Motion | How it moves about its place. | jitter | - | - | jitter | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Speed (0.5..240) | Turns a second. | 6 | - | - | 6 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Size (0.5..WOBBLE) | Up to 7 studs. More and shots stop counting. | 4 | - | - | 4 | [C] more than 7 studs and shots stop counting. |
| Spin | Off: faces the target. | on | on | on | on | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Facing |  | random | - | - | random | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Yaw speed (0..60) |  | 3 | - | - | 3 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Yaw offset (-180..180) |  | 0 | - | - | 0 | [-] your tuned value (vs-BASED config); no duel batch covers it. |

### Strafe

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Height (0..250) | Over the target. | 14 | 20 | 20 | 20 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Speed (0.1..60) | Turns a second, up to the top speed below. | 1.2 | 60 | 60 | 60 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Top speed (60..2000) | Studs a second. Over 560 it hops: still counts. | STRAFE_FAST | 2000 | 2000 | 2000 | [C] over 560 studs/s the body hops, and the server still counts it. |
| Speed per path | Each path its own speed, times the one above. | off | off | off | off | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| None (0.1..10) |  | 1 | - | - | 1 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Random (0..1) | Turns back and swings out now and then: harder to predict. | 0.35 | 0.75 | 0.75 | 0.75 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Wave (0..80) | Wave only. | 8 | 29 | 29 | 29 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Cycle | Changes Hover every few seconds. | off | off | off | off | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Every (0.2..30) |  | 3 | - | - | 3 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Kinds |  | { "swarm", "orbit", "above" } | - | - | { "swarm", "orbit", "above" } | [-] your tuned value (vs-BASED config); no duel batch covers it. |

### Wait

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Wait in | Sky: bots have to come out to you, and miss. | void | void | void | sky | [I] Void is what you tuned; Sky is the only wait that never needs a coordinate past 1024, so use it while the raknet fake position is on (260 caution above). |
| Cloud size (40..5000) |  | 150 | 1010 | 1010 | 1010 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Cyclone speed (0.2..30) |  | 5 | 5 | 5 | 5 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Sky size (30..160) | The ball's radius. Over 105, bots stop coming. | 95 | 95 | 95 | 95 | [C] over 105 the bots stop coming. |
| Sky height (60..400) | Over where you started. Under 500: on the map. | 300 | 300 | 300 | 300 | [C] under 500 studs it stays on the map. |
| Sky hold (0.04..0.5) | Time in each place. Shorter: other screens skip some. | 0.2 | 0.2 | 0.2 | 0.2 | [C] shorter than this and other screens skip some places. |
| Sky drift (0..200) | How fast the ball moves round. 0: bots swarm one spot. | 0 | 0 | 0 | 0 | [-] your tuned value (vs-BASED config); no duel batch covers it. |

### Swarm speed

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Swarm hold (0.04..0.5) | Time in each place. Under 0.12 s the server may miss it. | SWARM_HOLD | 0.08 | 0.08 | 0.12 | [C] under 0.12 s the server may miss a place. Your saved 0.08 is under it: raise it. |
| Swarm shake (0..6) | Shake in each place. | SWARM_SHAKE | 6 | 6 | 6 | [-] your tuned value (vs-BASED config); no duel batch covers it. |

### Void

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Void | Sends you to the void. Off: back where you stood. | off | off | off | off | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Void roam | A new side of the map every frame, not one corner. | on | on | on | on | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Void far (5000..VOID_MAX) | Held at a billion studs. | 40000 | 1000000000 | 1000000000 | 1000000000 | HAZARD: a billion-stud body swap is what the old code notes tie to disconnects (error 260) once raknet fake position is also on. See the 260 section. |
| Void jitter (500..10000000) | It never stays on one spot there. | 6000 | 10000000 | 10000000 | 10000000 | HAZARD: same as Void far. |
| Void high (VOID_FLOOR..1000000) |  | VOID_FLOOR | 1000000 | 1000000 | 1000000 | HAZARD: same as Void far. |

### Ghost

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Ghost | It walks, runs and jumps as you do. | on | on | on | on | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Walk like you | Your own speed, sprint and jumps. Off: the speed below. | on | on | on | on | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Speed (16..400) | The game walks at 16 and sprints at 22. | 24 | 41 | 41 | 38 | [S] the game speed lock is about 40 studs/s; the code caps the real body at 38. Your 41 is just over it. |
| Ghost fly | Space up, Left Ctrl down, through walls. | off | off | off | off | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| See-through (0..95) | 0: it looks like you. | 0 | 0 | 0 | 0 | [-] your tuned value (vs-BASED config); no duel batch covers it. |

### Void spam

| Setting | Does | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|
| Void spam | Flicks between the void and where you stood. | off | off | off | off | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Spam at (0.02..3) |  | 0.45 | 1 | 1 | 1 | [-] your tuned value (vs-BASED config); no duel batch covers it. |
| Spam void (0.02..3) |  | 0.15 | 0.6 | 0.6 | 0.6 | [-] your tuned value (vs-BASED config); no duel batch covers it. |

## Resolver tab (the 67 numbers it reads and shoots by)

Only two groups of these were ever changed in a winning duel: **core spread** (K2) and **pounce** (K9). Everything else was tried and came out the same or worse, and the Lure / Ring / Press numbers do nothing while those tactics are off. Pick = the vs-BASED value; a 0.2 s ring hold and 34-stud claim spacing etc. stay at the measured numbers.

### core

| Setting | Does | Range | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|---|
| Server lag guess | Used until your own lag has been timed. | 0.05..0.4 s | LAG | 0.05 | 0.05 | 0.05 | [S] real lag measured 0.24 s here (ping 0.059 + interpolation 0.18). |
| Lag ceiling | The most lag it ever allows for. | 0.1..0.8 s | LAG_MOST | 0.1 | 0.1 | 0.1 | [D] K1 tried other values: not better (scores 8-11). Keep the measured number. |
| Retry gap | Time between tries of one shot. | 0.02..0.2 s | RETRY | 0.04 | 0.04 | 0.04 | [D] K1 tried other values: not better (scores 8-11). Keep the measured number. |
| Tries | Tries at a spot before it is given up. | 2..40 | TRIES | 14 | 14 | 14 | [D] K1 tried other values: not better (scores 8-11). Keep the measured number. |
| Origin reach | How far you may drift and still count as there. | 5..17 st | REACH | 15 | 15 | 15 | [S] the server wants the shot origin within 17 studs of where it has the body; 15 leaves room. |
| Hit slack | How far off a part a claimed hit may land. | 5..22 st | HIT_SLACK | 20 | 20 | 20 | [S] the claimed hit must be within 22 studs of the part; 20 leaves room. |
| Origin spread | Studs between the spots one shot comes from. | 10..60 st | APART | 31 | 40 | 40 | [D] K2 kept (12-0 / 12-0). |
| Claim spread | Studs between the places one hit is claimed at. | 15..80 st | MARK_APART | 43 | 55 | 55 | [D] K2 kept (12-0 / 12-0). |
| Claims a shot | Most claims sent with one shot. | 1..16 | CLAIMS | 8 | 12 | 12 | [D] K2 kept (12-0 / 12-0). |
| Path read | Seconds of a target's path it reads. | 0.2..2 s | WINDOW | 0.6 | 0.9 | 0.9 | [D] K2 kept (12-0 / 12-0). |
| Ride speed | Faster than this, it rides along with them. | 20..300 st/s | FOLLOW | 300 | 200 | 200 | [D] K2 kept (12-0 / 12-0). |
| Follower range | This near your trail in the void: a follower. | 30..400 st | CHASE | 160 | 220 | 220 | [D] K2 kept (12-0 / 12-0). |

### lure

| Setting | Does | Range | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|---|
| Show time | How long you show yourself. | 0.05..0.5 s | LURE_SHOW | 0.25 | 0.25 | 0.25 | [D] K3 tried other values: not better (scores 8-11). Keep the measured number. |
| First claim | When the first shot goes, after you show. | 0..1 s | LURE_FROM | 0.3 | 0.3 | 0.3 | [D] K3 tried other values: not better (scores 8-11). Keep the measured number. |
| Fire time | How long it shoots after a lure. | 0.1..2 s | LURE_FIRE | 0.8 | 0.8 | 0.8 | [D] K3 tried other values: not better (scores 8-11). Keep the measured number. |
| Fire time (comers) | The same, for one that comes to lures. | 0.2..3 s | ? | 1.6 | 1.6 | 1.6 | [D] K4 tried other values: not better (scores 8-11). Keep the measured number. |
| Rest | Time in the void between lures. | 0.2..6 s | LURE_REST | 0.6 | 0.6 | 0.6 | [D] K4 tried other values: not better (scores 8-11). Keep the measured number. |
| Height | Studs above home it shows at. | 20..400 st | LURE_HIGH | 90 | 90 | 90 | [D] K3 tried other values: not better (scores 8-11). Keep the measured number. |
| Height spread | Up to this much higher. | 0..300 st | LURE_RISE | 60 | 60 | 60 | [D] K3 tried other values: not better (scores 8-11). Keep the measured number. |
| Spread | How far from home it may show. | 0..800 st | LURE_ROAM | 220 | 220 | 220 | [D] K3 tried other values: not better (scores 8-11). Keep the measured number. |
| Swarm size | How far out it swarms after showing. | 10..150 st | LURE_BALL | 60 | 60 | 60 | [D] K4 tried other values: not better (scores 8-11). Keep the measured number. |
| Hush | Stops luring one that never comes, for this long. | 0..120 s | LURE_HUSH | 5 | 5 | 5 | [D] K4 tried other values: not better (scores 8-11). Keep the measured number. |

### ring

| Setting | Does | Range | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|---|
| Step time | Most time on one step. | 0.05..0.6 s | ? | 0.25 | 0.25 | 0.25 | [D] K5 tried other values: not better (scores 8-11). Keep the measured number. |
| Quick margin | How much quicker than it looks it may be. | 0..0.5 s | ? | 0.21 | 0.21 | 0.21 | [D] K5 tried other values: not better (scores 8-11). Keep the measured number. |
| Climb time | How long a ring lure climbs. | 0.2..3 s | ? | 0.9 | 0.9 | 0.9 | [D] K5 tried other values: not better (scores 8-11). Keep the measured number. |
| Step height | Studs each step goes up. | 10..80 st | ? | 35 | 35 | 35 | [D] K5 tried other values: not better (scores 8-11). Keep the measured number. |
| Claim spacing | Studs between claims round the ring. | 10..80 st | ? | 34 | 34 | 34 | [D] K5 tried other values: not better (scores 8-11). Keep the measured number. |
| Draw lag | How late you see others (0.2 measured). | 0..0.5 s | ? | 0.2 | 0.2 | 0.2 | [D] K6 tried other values: not better (scores 8-11). Keep the measured number. |
| Slack | Timing slack either way. | 0..0.3 s | ? | 0.08 | 0.08 | 0.08 | [D] K6 tried other values: not better (scores 8-11). Keep the measured number. |
| Come-out time | Extra time it may take to come out. | 0..0.6 s | ? | 0.15 | 0.15 | 0.15 | [D] K6 tried other values: not better (scores 8-11). Keep the measured number. |
| Both steps for | Start of a step that still shoots from the last. | 0..0.3 s | ? | 0.06 | 0.06 | 0.06 | [D] K6 tried other values: not better (scores 8-11). Keep the measured number. |
| Sightings | Times seen round lures before it counts. | 2..20 | ? | 4 | 4 | 4 | [D] K5 tried other values: not better (scores 8-11). Keep the measured number. |

### flak

| Setting | Does | Range | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|---|
| Read time | Seconds of its moves read. | 0.5..5 s | HAUNT_SPAN | 1.6 | 1.6 | 1.6 | [D] K7 tried other values: not better (scores 8-11). Keep the measured number. |
| Least read | Seconds needed before it shoots. | 0.1..3 s | HAUNT_LEAST | 0.7 | 0.7 | 0.7 | [D] K7 tried other values: not better (scores 8-11). Keep the measured number. |
| Area | Biggest area it shoots into. | 20..300 st | HAUNT_MOST | 110 | 110 | 110 | [D] K7 tried other values: not better (scores 8-11). Keep the measured number. |
| Memory | Seconds of places it picks from. | 1..20 s | HAUNT_MEMORY | 6 | 6 | 6 | [D] K7 tried other values: not better (scores 8-11). Keep the measured number. |
| Skip newest | Skips places newer than this. | 0..1.5 s | HAUNT_AGO | 0.45 | 0.45 | 0.45 | [D] K7 tried other values: not better (scores 8-11). Keep the measured number. |
| Spacing | Studs between claimed places. | 5..60 st | HAUNT_APART | 20 | 20 | 20 | [D] K7 tried other values: not better (scores 8-11). Keep the measured number. |
| Places a shot | Most places in one shot. | 1..32 | HAUNT_MARKS | 16 | 16 | 16 | [D] K7 tried other values: not better (scores 8-11). Keep the measured number. |
| Places a shell | For a shotgun shell (five calls a place). | 1..16 | HAUNT_SHELLS | 8 | 8 | 8 | [D] K7 tried other values: not better (scores 8-11). Keep the measured number. |

### ambush

| Setting | Does | Range | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|---|
| In time for | Seconds after it shows that a shot still lands. | 0.2..2 s | AMBUSH_SPAN | 0.9 | 0.9 | 0.9 | [D] K8 tried other values: not better (scores 8-11). Keep the measured number. |
| Sightings | Places seen in showings before it ambushes. | 1..30 | AMBUSH_LEAST | 3 | 3 | 3 | [D] K8 tried other values: not better (scores 8-11). Keep the measured number. |
| Spacing | Studs between claims. | 10..60 st | AMBUSH_GRID | 28 | 28 | 28 | [D] K8 tried other values: not better (scores 8-11). Keep the measured number. |
| Places a shot | Most places in one claim. | 1..48 | AMBUSH_MARKS | 24 | 24 | 24 | [D] K8 tried other values: not better (scores 8-11). Keep the measured number. |
| Gun reach | Only guns that reach this far. | 50..300 st | AMBUSH_RANGE | 180 | 180 | 180 | [D] K8 tried other values: not better (scores 8-11). Keep the measured number. |
| Stay | Most time where it shoots from. | 0.1..1.5 s | AMBUSH_STAY | 0.33 | 0.33 | 0.33 | [D] K8 tried other values: not better (scores 8-11). Keep the measured number. |

### pounce

| Setting | Does | Range | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|---|
| Floor | Studs over the spot the room starts. | 0..100 st | POUNCE_LOW | 24 | 10 | 10 | [D] K9 kept (12-0 / 12-0). |
| Roof | Studs over the spot the room ends. | 30..250 st | POUNCE_HIGH | 200 | 116 | 116 | [D] K9 kept (12-0 / 12-0). |
| Reach | How far out the room reaches. | 10..150 st | POUNCE_OUT | 150 | 49 | 49 | [D] K9 kept (12-0 / 12-0). |
| Stay | Time at the spot it shoots from. | 0.1..1.5 s | POUNCE_STAY | 0.5 | 0.3 | 0.3 | [D] K9 kept (12-0 / 12-0). |
| Places a try | Places claimed each try. | 1..30 | POUNCE_MARKS | 24 | 14 | 14 | [D] K9 kept (12-0 / 12-0). |

### press

| Setting | Does | Range | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|---|
| Comings-out | Times at one spot before it is pressed. | 1..10 | ? | - | - | - | [-] not set and not tested. |
| Spot size | Comings-out this near each other are one spot. | 4..50 st | ? | - | - | - | [-] not set and not tested. |
| Back within | It must come back this often. | 0.2..5 s | ? | - | - | - | [-] not set and not tested. |
| Retry gap | Time between tries at it. | 0.02..0.3 s | ? | 0.04 | 0.04 | 0.04 | [D] K1 tried other values: not better (scores 8-11). Keep the measured number. |
| Call cap | Most calls a second. | 100..2000/s | ? | - | - | - | [-] not set and not tested. |
| Stay | How long one press lasts with nothing taken. | 0.5..10 s | ? | - | - | - | [-] not set and not tested. |
| Places a try | Places claimed each try. | 1..10 | ? | - | - | - | [-] not set and not tested. |
| Keep out | Studs past its gun's reach you keep. | 0..60 st | ? | - | - | - | [-] not set and not tested. |
| Follower near | This near your trail, over and over: a follower. | 20..150 st | ? | - | - | - | [-] not set and not tested. |
| Follower band | Studs out you keep while shooting a follower. | 20..150 st | ? | - | - | - | [-] not set and not tested. |
| Grid | Studs between points of a region's grid. | 15..80 st | ? | - | - | - | [-] not set and not tested. |
| Back off | Seconds it leaves one alone after a hurt. | 0..60 s | ? | - | - | - | [-] not set and not tested. |

### swarm

| Setting | Does | Range | Shipped | Your best | Your vs-BASED | Pick | Why |
|---|---|---|---|---|---|---|---|
| Least reach | Studs a swarm reaches each way, at the least. | 20..200 st | SWARM_MIN | 60 | 60 | 60 | [D] K12 tried other values: not better (scores 8-11). Keep the measured number. |
| Hop | Studs from each of the last two places. | 10..100 st | SWARM_STEP | 38 | 38 | 38 | [D] K12 tried other values: not better (scores 8-11). Keep the measured number. |
| Clear | Studs from the five places before those. | 5..80 st | SWARM_CLEAR | 27 | 27 | 27 | [D] K12 tried other values: not better (scores 8-11). Keep the measured number. |
| Longest hop | Studs at most from the place before. | 30..300 st | SWARM_FAR | 80 | 80 | 80 | [D] K12 tried other values: not better (scores 8-11). Keep the measured number. |

## MONSTER Rage tab (the suite ragebot), Resolver, Defense, Fake position and Void

| Setting | Does | Default | Pick | Why |
|---|---|---|---|---|
| monster.fakepos.offX | Static / Follow: right (+) or left (-). | 0 | default | [-] |
| monster.fakepos.offY | Static / Follow: up (+) or down (-). | 0 | default | [-] |
| monster.fakepos.offZ | Static / Follow: behind (+) or in front (-). | 30 | default | [-] |
| monster.fakepos.radius | Jitter: how far from you they see you. | 25 | 25 | [-] jitter mode only. |
| monster.fakepos.rate | Jitter: milliseconds between new places. | 120 | 120 | [-] jitter mode only. |
| monster.fakepos.resetOnKO | A knock clears the anchor and the jitter. | on | default | [-] |
| monster.fakepos.backend | Auto: raknet when it works, else the body swap. Velocity is unmeasured. | auto | auto | [I] raknet when it works, else the swap. |
| monster.fakepos.orbitAround | Orbit strafe: the target (you, when nobody is near) or always yourself. | target | target | [-] |
| monster.fakepos.moveReal | Orbit strafe also runs your own body round the target (capped on the ground). | off | off | [-] by the code it also runs your real body round the target at up to 420 studs/s (38 on the ground); not measured. |
| monster.void.position | Sky: a random place high over the map, sent by raknet. Far: a body swap a billio | sky | sky | [S] sky is a random place inside the packet format (thousands sent, no disconnect). Far / NaN were changed to clamped finite values this session because 1e29 ends in 260. |
| monster.void.protect | Go to the void while an armed player is near, come back after a calm hold. | off | off | attack only. |
| monster.void.whenDead | Hide for a few seconds after a knock. | on | on | [-] hides you for 4 s after a knock so the dead player's friends cannot answer. |
| monster.void.whileWaiting | Hide while the ragebot has nothing to shoot or is reloading. | off | off | [I] one more place the void can start on its own. |
| monster.void.respawnRamp | After a death: a long hold, then shorter ones, then out. | on | on | [-] the long hold after a respawn is what keeps you alive in the spawn. |
| monster.physrep.on | Stomp and bag spots move with a moving target. | on | off | [-] the PhysicsRepRootPart ride was never measured to work. |
| monster.rage.on | Fights from the fake position. Off while BasedHub's own ragebot runs. | off | off for real fights | [T] 1 of about 320 salvos accepted in five runs; use the Ragebot tab instead until that is solved. |
| monster.rage.targetMode | Who it picks. | threat | closest-to-me | [D] closest beat threat-first in the duel (R4); [I] same logic here. |
| monster.rage.targets | Names, comma between. Empty: everyone who is not a friend. |  | the one name | [T] single-target tests used one name; empty = everyone not a friend. |
| monster.rage.fov | Degrees off your camera line. | 160 | 180 | [I] the ragebot should not care where the camera points. |
| monster.rage.walls | Skip players behind walls. | on | off | [D] R5 kept walls off. [T] with it on, a wall between you and the fake body blocks every shot. |
| monster.rage.teamCheck | Skip your own team. | off | default | [-] |
| monster.rage.switchWait | Seconds before it changes target. | 0.14 | 0.14 | [S] closer than 0.14 s and a shot is lost. |
| monster.rage.part | Head or torso. | head | head | [D] R6: torso was in the 1-6 batch. |
| monster.rage.weapon | auto, or part of a gun's name ([Rifle], Double). | auto | auto | [I] auto picks the gun with rounds. |
| monster.rage.flame | Use the flamethrower up close (not measured). | off | off | not measured. |
| monster.rage.salvo | Shotguns send all five pellets. | on | on | [S] a shotgun needs all five pellets sent together. |
| monster.rage.pipeline | Send the next shot without waiting for the answer. | on | on | [I] only matters with 2+ targets. |
| monster.rage.oneTap | Head only, then wait for the hit before the next. | off | on | [D] R6. |
| monster.rage.snipe | Far targets only when they stand still. | off | on | [D] R7. |
| monster.rage.autoReload | Reload an empty gun. | on | on | [S] nothing counts during a reload, so it must happen between shots. |
| monster.rage.smartReload | Top the gun up while nobody is in sight. | on | on | [D] R6. |
| monster.rage.strafe | Orbit strafe: the server sees you whirl high over them; each shot brings you bac | off | off | [-] the sky strafe was never measured to land a shot. |
| monster.rage.strafeStyle | Sky stays inside what a packet can carry; Thunder goes 200000 up (body swap). | sky | sky | [S] sky stays inside what a packet carries; 200000-up is a body swap (260 risk). |
| monster.rage.chase | Your own body runs at the target. | off | off | [I] the fake body does the work; running the real body at them only adds risk. |
| monster.rage.walk | Your own body walks up to 15 studs from the target. | off | off | [I] same as Chase. |
| monster.rage.jump | Your own body jumps while closing in. | off | off | [I] same as Chase. |
| monster.rage.stomp | Finish a knocked target from above. | on | on | [S] 1.5-9.5 studs window. |
| monster.rage.pattern | Where the server sees you, round the target. | none | haunt or none | [T] ring hops every 0.25 s, which is why the old fixed arrival wait left no shot window. Use a pattern that holds still (haunt); none = no fake body. |
| monster.rage.safety | Pause when knocked, loading, in a vehicle, or a dangerous player is near. | on | on | [I] it pauses when you are knocked or loading. |
| monster.resolver.on | Aim at where a hiding body really is, not where it shows. | on | on | [T] no gain, no harm in the recorded runs. |
| monster.resolver.skipLow | Below the minimum confidence: no shot. Off: shoot anyway. | on | on | [I] a low-confidence guess is a wasted shot. |
| monster.resolver.learn | A guess that gets hits counts more for that player (this session only). | on | on | [-] not measured. |
| monster.resolver.overlay | A colour per estimator on the target; the winner in green. | off | off | debug only. |
| monster.defense.on | Void when a threat is near, as set below. | off | off | you said attack only; it voids you when a threat is near, which also stops you shooting. |
| monster.defense.antiBag | Knocked, with someone about to pick you up: go to the void. | on | on (if Defense is on) | [-] |
| monster.defense.antiFlame | A flamethrower close or closing: go to the void. | on | on (if Defense is on) | [-] |
| monster.defense.antiBait | An armed player waiting by your way back: stay hidden. | on | on (if Defense is on) | [-] |

### MONSTER number constants (the K table)

| Constant | Does | Default | Pick | Why |
|---|---|---|---|---|
| INTERP | Roblox's interpolation buffer in seconds (lead = ping + this). Measured 2026-11-09 on Volt | 0.18 | 0.18 | [S] measured 0.180 s on Volt. |
| NET_FAIL_COUNT | Send failures inside the window that count as raknet being denied. | 20 | 20 | [-] default. |
| NET_FAIL_WINDOW | Seconds of the send-failure window. | 2 | 2 | [-] default. |
| NET_UNPARSED_QUIET | Fake position pauses (the engine's own packets flow) while the body sends a layout the cod | 0.75 | 0.75 | [T] new this session; pauses crafted packets while the engine sends a layout the codec cannot read. Did not stop the 260. |
| VOID_BAIT | Seconds the body is still shown before it goes (bait delay). | 0.1 | 0.1 | [-] default. |
| VOID_HOLD | Seconds with no threat near before the void is let go. | 0.6 | 0.6 | [-] default. |
| VOID_PEEK | Seconds the body comes back between respawn holds. | 0.12 | 0.12 | [-] default. |
| VOID_RAMP1 | Respawn: first hold (s). | 3.2 | 3.2 | [-] default. |
| VOID_RAMP2 | Respawn: second hold (s). | 0.55 | 0.55 | [-] default. |
| VOID_RAMP3 | Respawn: third hold (s). | 0.25 | 0.25 | [-] default. |
| VOID_RAMP4 | Respawn: last hold (s). | 0.15 | 0.15 | [-] default. |
| VOID_DEAD_HOLD | Seconds to void after the target dies. | 4 | 4 | [-] default. |
| ORBIT_SPEED | Orbit: radians a second. | 28 | 28 | [-] default. |
| ORBIT_RADIUS | Orbit: ring radius in studs. | 135 | 135 | [-] default. |
| ORBIT_H1 | Orbit: height, high flip. | 200000 | 900 | [S] 200000 is a body swap; 900 stays inside the packet. |
| ORBIT_H2 | Orbit: height, low flip. | 199500 | 870 | [S] same. |
| ORBIT_FLIP | Orbit: height flips a second. | 20 | 20 | [-] default. |
| ORBIT_JIT_H | Orbit: horizontal jitter (studs). | 10 | 10 | [-] default. |
| ORBIT_JIT_V | Orbit: vertical jitter (studs). | 5 | 5 | [-] default. |
| ORBIT_JIT_RATE | Orbit: jitter rate (rad/s). | 80 | 80 | [-] default. |
| ORBIT_VEL | Orbit: real-body speed when it is pushed round (studs/s). | 420 | 420 | [-] default. |
| ORBIT_GROUND_CAP | Real-body speed cap on the ground (the game's speed lock is 40). | 38 | 38 | [-] default. |
| PHYS_RANGE | PhysicsRepRootPart ride lets go past this distance (studs). | 60 | 60 | [-] default. |
| PHYS_UP | Default height above the target root while riding (studs). | 3 | 3 | [-] default. |
| RES_WINDOW | Seconds of history each estimator reads. | 1.0 | 1.0 | [-] default. |
| RES_MAX_JUMP | A move this big in one sample is a teleport, not a body (studs). | 30 | 30 | [-] default. |
| RES_MAX_SPEED | Fastest a body can really go (studs/s). | 140 | 140 | [-] default. |
| RES_MIN_CONF | Below this the ragebot skips the shot (or spreads, by setting). | 0.35 | 0.35 | [-] |
| RES_SIGMA | Guesses closer than this agree (studs). | 6 | 6 | [-] default. |
| RES_WATCH | Seconds a shot is watched for damage (hit-confirm learning). | 0.6 | 0.6 | [-] default. |
| DEF_SAFE | An armed player inside this is a threat (studs). | 90 | 90 | [-] |
| DEF_BAG | Someone this close to a knocked body is a bagger (studs). | 12 | 12 | [-] default. |
| DEF_FLAME | A flamethrower reaches this far (studs). | 25 | 25 | [-] default. |
| DEF_GUN | A gun counts out to this range (studs). | 300 | 300 | [-] default. |
| DEF_TELE | A jump this big in a sample is a teleport (studs). | 80 | 80 | [-] default. |
| RAGE_ARRIVE | Longest wait (s) after the server body hops before a shot is sent. The ping plus the pad b | 0.25 | 0.25 | [S] the measured window is 0.10-0.23 s. |
| RAGE_ARRIVE_PAD | Added to the ping for the wait after a hop. Measured: a hop needs 0.10-0.23 s; the 0.25 s  | 0.06 | 0.06 | [T] new this session; the arrival wait is ping + this, capped by RAGE_ARRIVE. |
| RAGE_RANGE | Longest shot (studs) when the weapon does not say. | 250 | 250 | [-] default. |
| RAGE_STOMP | Stomp height above the target (studs). | 3 | 3 | [-] default. |
| RAGE_RELOAD_AT | Reload when the magazine is at or below this (0 = only when empty). | 0 | 0 | [-] default. |

## Desync tab

Where **fake position** and the **void** are measured, the picks come from the 95 s duel and the notes written into the code.

| Setting | Pick | Default / saved | Why |
|---|---|---|---|
| Desync (monster.desync) | off | off | [C] its own text: 150+ studs of "How far" stopped BasedHub firing, so it is a defence trick. Both desync and fake position stop while the swap-path ragebot hunts. |
| How far (monster.desyncRange) | 40 | 40 | [C] 150+ stopped BasedHub firing; that also moves where you can be hit. |
| Fake position (monster.fake) | on while fighting | off |  |
| Where (monster.fakeWhere) | void | decoy | [D] the void round: 22 hits, 0 taken, 95 s, vs BasedHub, with strikes (not reproduced this session). Decoy / Ghost / On target were measured earlier but not as a full duel (ghost: an origin 40 studs under the map was refused 0 of 3, 40 above was taken 3 of 3; decoy: shots refused 0.1-0.2 s after a hop). |
| Void strike (monster.voidStrike) | on | on | [D] the void round used it: a shot brings the body back for a moment. |
| New spot every step (monster.voidSpam) | on | on | [C] nobody can follow you in. |
| Strike spread (monster.strikeSpread) | 12 | 12 | [D] strikes always at your real place lost 1-2 to BasedHub; a new place each time (12) gave 22 hits, 0 taken. |
| Show lures (monster.showLures) | off | on | [D] turning lure + ring lure off was the biggest gain in the sweep (R1). |
| Void strike arrive (monster.voidArrive) | 0.25 | 0.25 | [S] window 0.10-0.23; the raknet path already uses ping + 0.06 (capped 0.08-0.4). |
| Use raknet (monster.rak) | on | on | [S] only the server is told the fake; you never move. |
| Shoot from fake (monster.rakShoot) | on | on | [S] the server refuses shots from anywhere but where it has the body. |
| Keep on with Ragebot (monster.rakRage) | on | on |  |
| Face (monster.rakFace) | as you | as you | [-] not measured. |
| Send rate (monster.rakRate) | 30 | 10 (saved) | [T] 25-30 sent per second held for 40 s runs with 0 failures. Your saved 10 leaves the server body 100 ms stale. |
| Decoy up (monster.decoyUp) | 0 | 0 | [-] |
| Ghost height (monster.ghostHeight) | 120 | 120 | [C] a shot is refused when anything is in the line from the ghost to the target: too high under a roof loses every shot. |
| Ghost dodge (monster.ghostJitter) | 10 | 10 | [C] stays under the 17-stud origin rule, so your shots still land. |
| From target (monster.fakeNear) | 4 | 4 | [-] |
| How far (monster.fakeDistance) | 40 | 40 | [-] only for Below / Behind / Side / Above. |
| Show where they see you (monster.desyncBox) | on | on | debug aid: the red body. |
| Off while holding (monster.desyncTools) | on | on | [-] |
