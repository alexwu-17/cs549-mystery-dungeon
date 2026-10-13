# Simple skeleton stress test

Run `scenes/main/limit_testing_main.tscn` with F6.

- The fixed 30x22 map has four flat rooms and narrow connecting corridors.
- Use **+5** and **-5** to select a skeleton count, then click **Reset Test**. Count buttons alone change nothing in the active test.
- The panel shows the requested count, actual count, and capacity (382 room tiles). Requests above capacity are clamped.
- Spawns are reproducible: a 40-skeleton test preserves the first 20 starting positions of a 20-skeleton test.
- Use ordinary movement and Space attacks. Reset Test restores the same map and starting position.
- Read FPS, internal render resolution, and average frame interval from the existing F3 overlay. F3 hides/shows that overlay.

Try 20, 40, 80, and increasing counts, repeating the same route/actions at 1920x1080. Limit Testing retains its 60 FPS cap and configured invincibility. Loading/introductions are transient; assess performance during gameplay.

There are no separate scenarios, CSV exports, extra timing statistics, or advance-turn key. The benchmark stays on one floor. Disable `benchmark_enabled` in the Limit Testing scene to return to its configured procedural floors. Infinite and Demo modes remain unchanged.
