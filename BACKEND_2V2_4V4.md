# Backend: 2v2 vs 4v4 Match Support

The app sends `playersRequired` (2 or 4) when creating a match. For 2v2 to work, the backend must use this value.

## 1. create_match.php

- **Request body** includes: `playersRequired` = `"2"` or `"4"`.
- **Action:** Store `players_required` (or equivalent) for this match (e.g. in `matches` table).
- When a new player joins, count should be compared against **this** value, not always 4.

## 2. check_match.php

- **Action:** Mark match as **matched** when:
  - `players_count >= players_required`  
  (e.g. 2 players for 2v2, 4 for 4v4).
- Do **not** require 4 players for every match.
- **Response:** Return only the joined players (2 for 2v2, 4 for 4v4) in the `players` array so the app shows the correct number of slots.

## Summary

| Mode | playersRequired | Match "matched" when | Players in response |
|------|-----------------|----------------------|--------------------|
| 2v2  | 2               | 2 players joined     | 2                  |
| 4v4  | 4               | 4 players joined     | 4                  |

If the backend always waits for 4 players, 2v2 will never start. It must treat a match as full when `players_count >= players_required` for that match.
