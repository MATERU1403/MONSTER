# Attack test report: morrowindf (MONSTER) against gotham77r (BasedHub alt), 2026-11-09

Only the attack was exercised (no defense, no void-protect). Build 20261109.1358 and 20261109.1400. Logs: `attack_a1..a5.json`, `attack_L1.json`
(attacker side), `victim_*.json` (gotham's own health / armor / KO log).

## What works (measured)
- **The fake position is real.** The real body of morrowindf stayed 483 studs from the target for the whole run (-735.6, 21.7, 142.3) while the server
  body circled the target at ~35 studs; gotham's own client saw morrowindf 34 studs away. raknet: 952 to 1211 packets sent per run, 0 failed, not denied.
- **No error 260 in any run.** Every raknet position stays inside the decoded format (|coord| < 1024); the body-swap void that writes a position to the
  real body is now clamped (`Void.safe`, NaN 1 / NaN 2 land in the far box instead of 1e29).
- **Void guard counter:** `Void.status().guarded` counts how often a 1e29 constant was turned down.

## What does not work yet
| run | pattern | shots fired | accepted by the server | note |
|---|---|---|---|---|
| a1 | ring (build .1358) | 5 | 1 (the 5th: gotham 100 hp + 130 armor to KO) | the other 4 left the magazine untouched |
| a2 | ring | 2 | 0 | `why` = arriving in 88 of 89 samples |
| a3 | ring, arrival gate follows the ping (build .1400) | 92 | 0 | ammo stayed at 1, no damage |
| a4 | haunt (20 studs behind) | 66 | 0 | |
| a5 | haunt (6 studs behind) | 53 | 0 | |
| L1 | the older BasedHub ragebot + sky void strike | n/a | 0 | the path that landed 22 hits earlier today |

- The server's own `LastGunShotAt` attribute on morrowindf's character still reads the a1 KO shot: **no shot accepted since**, in any mode, including
  the older ragebot. A reload (ammo 1 to 2, spare 14 to 12) proves the server still talks to the character, so the block is on shots, not on the remote.
- Open question: either a server-side flag on morrowindf after the a1 kill and the volley of rejected shots, or something about gotham77r's current state
  (its own client sits at (-613, 22, -325) while the server body that morrowindf sees is at (-257, 23, -83)).
- Resolver (offline, from the recorded runs): no gain over the plain replicated position for static / follow / orbit / void; only jitter improves slightly.

## Fixed in this session
- `src/41_void.lua`: guarded void spots, relabelled the dropdown, `guarded` in status.
- `src/50_ragebot.lua`: `Rage.why` (why it is not firing) in `status()`; the arrival wait now follows the ping (`RAGE_ARRIVE_PAD`, new K number) instead of a fixed 0.25 s that equalled the ring's own hold.
- New live tools: `tools/live/attack.lua`, `attack_legacy.lua`, `victim.lua` (attack, older-ragebot attack, victim log).
