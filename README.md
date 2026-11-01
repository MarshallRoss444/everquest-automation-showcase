# EverQuest automation showcase

I'm Marshall Ross. EverQuest is one of the places where I build things for the fun of it: coordinating a raid, reducing repetitive setup, and turning game state into useful decisions.

This is a curated selection from my personal MacroQuest workspace. It includes Lua scripts for coordinating a 54-character example roster, distributing supplies, managing an encounter, and collecting and scoring equipment data. I use coding agents in my engineering workflow; the game environment gives me a concrete way to try ideas and see where they break.

**Start with [raid coordination](lua/raidinvite.lua), [the encounter state machine](lua/empadd.lua), or [gear reporting](lua/gearlog.lua).** These scripts use deterministic logic and the MacroQuest runtime. They do not call an LLM.

## What to explore

| Component | Implementation | What it does |
| --- | --- | --- |
| Raid formation | [raidinvite.lua](lua/raidinvite.lua) | Sequences disbanding, group invitations, raid invitations, and leader promotion across clients through DanNet. |
| Split raids | [splitraid.lua](lua/splitraid.lua) | Reorganizes an example roster into two raids with separate leaders. |
| Encounter control | [empadd.lua](lua/empadd.lua) | Uses SEARCH, PULL, DRAG, and FIGHT states to handle encounter adds and respond to lost aggro. |
| Inventory top-off | [PotionDistribute.lua](lua/PotionDistribute.lua) | Queries peer inventory, calculates the amount needed, and handles trade-window failures. |
| Food distribution | [FoodDistribute.lua](lua/FoodDistribute.lua) | Distributes a requested quantity to nearby peers. |
| Gear collection | [gearlog.lua](lua/gearlog.lua) | Collects equipment, augment, and focus-effect data from clients into a local CSV. |
| Gear scoring | [score.lua](lua/score.lua), [weights.lua](lua/lib/weights.lua) | Applies class-specific weights to the collected data and summarizes results. Optional Discord delivery is disabled without a local environment variable. |
| Small utilities | [bindarmy.lua](lua/bindarmy.lua), [stripbuffs.lua](lua/stripbuffs.lua) | Coordinate bind setup and remove buffs with a bounded retry loop. |

## Reading and running

You can read every file here without installing anything. Running the scripts requires your own compatible EverQuest/MacroQuest environment. The `mq` module is provided by MacroQuest; these are not standalone Lua programs.

1. Review the script before running it. Several scripts issue commands to connected clients, disband groups, change combat state, or trade inventory.
2. Install MacroQuest and the plugins used by the script. DanNet supplies remote commands and queries; inventory/group workflows use AutoAccept. The encounter script also uses navigation and movement commands.
3. Copy the `lua/` contents into your MacroQuest Lua directory, preserving `lib/weights.lua`.
4. Replace the fictional `Example...` character names with your own local roster. Keep those local settings out of commits. No live roster or plugin configuration is included.
5. Check your server's rules and try a small controlled group first.

Examples, after local setup:

```text
/lua run raidinvite
/lua run PotionDistribute
/lua run FoodDistribute 20
/lua run gearlog
/lua run score
```

Run raid formation from the configured inviter. Gear collection writes `MyGearLog.csv` in MacroQuest's Logs directory; scoring reads that file. Discord output is opt-in via `/lua run score discord` and the local `EQ_DISCORD_WEBHOOK_URL` environment variable. Never commit that value.

## Engineering notes

The interesting part is coordinating work across clients whose state changes independently. The code combines peer discovery, command sequencing, inventory queries, UI-state checks, and encounter state transitions. [Architecture and trade-offs](docs/architecture.md) explains the design and limitations.

This is a hobby-code snapshot, not a claim of production reliability. Fixed delays, client/version assumptions, and incomplete acknowledgements remain. The sanitized version has not been exercised in a live game session. Runtime logs and CSVs can contain character names and should remain local.

## Publication scope

This repository starts with fresh history. It contains selected scripts with fictional character identifiers. Account notes, personal documents, live configuration, logs, backups, and the private repository's history are not included. Bundled community packages from the working environment are also omitted.

MacroQuest, DanNet, EverQuest, and other dependencies belong to their respective maintainers. This repository presents my selected scripting work within that ecosystem; it does not claim authorship of those platforms or bundle a game client.

[Marshall's portfolio](https://marshallross.ai/)
