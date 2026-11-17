# Historical snapshots

`phase5/` holds an earlier, read-only version of the design, kept
for reference only.

It is **not** part of the build. `make` compiles only the files in
`rtl/` and `testbench/`. The phase-5 sources predate write-through
support and have a different `cache_top` port list, so they are not
interchangeable with the current RTL.
