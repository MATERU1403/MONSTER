# Da Hood suite (source of loader.lua's suite block)
Build: python -I build.py (needs baseline/, lune on PATH for the compile gate). Tests: lune run tests/run (80 passing).
pure/ = offline-tested modules, src/ = runtime, tools/ = live rig (poller, capture, replicate, lag, resolver analysis).
Measured on Volt 1.3.21.2 with two alts: fake position replicates (0.01 studs, 40 off); lag 0.240 s = pings 0.059 + interpolation 0.180.
Not yet measured live: resolver table, server shot rules, physrep ride, cleanup, ragebot hit rates.
