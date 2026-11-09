# Da Hood suite (source of loader.lua's suite block)
Build: python -I build.py (needs baseline/, lune on PATH for the compile gate). Tests: lune run tests/run (80 passing).
pure/ = offline-tested modules, src/ = runtime, tools/ = live rig (poller, capture, replicate, lag, resolver analysis).
Measured on Volt 1.3.21.2 with two alts: fake position replicates (0.01 studs, 40 off); lag 0.240 s = pings 0.059 + interpolation 0.180.
Not yet measured live: resolver table, server shot rules, physrep ride, cleanup, ragebot hit rates.
Attack test 2026-11-09 (morrowindf vs gotham77r): the fake position works live; the server accepted 1 shot (a knock-out) and none since in any mode. See results/attack_report.md. Void body swaps are clamped (no 1e29 constants, error 260); the arrival wait follows the ping.
Error 260 (server kick, reason 260) hit morrowindf 7 times on 2026-11-09; cause unconfirmed. src/30_net.lua now takes the packet header only from packets it can decode, pauses crafting while the engine sends an unreadable layout, and writes results/net_flight.json (a flight recorder) while a hold is on. results/settings-guide.md lists every setting with a pick and its evidence.
