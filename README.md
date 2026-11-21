# Barsmith

Set up your WoW Forever action bars, macros and keybinds in the browser, then load them into the game with one string.

**Binding-safety development branch.** Open this checkout's `index.html` and install its `addon/Barsmith` directory to review BP2. The public [upstream planner](https://rubensayshi.github.io/wowforever-barplanner/) and its downloadable addon use BP1.

- An in-game-looking screen: main bar with bars 2, 3 and 6–8 stacked on top, bars 4 and 5 on the right edge, stance bar and pet bar above.
- Pick a class and race (only the combos Forever allows), then drag spells from that class's Forever spellbook: trainer spells, active talents and racials, with spells new in Forever marked ★. A level slider greys out spells you won't have yet.
- Write macros, plan the main bar once per stance or form that swaps it (warrior stances, Cat and Bear Form, Stealth) and on its page 2 (Shift+2), and bind keys in keybind mode (hover a button, press a key).
- Keep as many plans per class as you like. They're saved in your browser; the plan string moves them anywhere else.
- Works with EllesmereUI, Bartender4, Dominos and ElvUI: they show the game's normal bar slots and pass its keybinds on to their own buttons. Those three number bars by action page, so Bar 2 here is their bar 6, Bar 3 is 5, Bar 4 is 3, Bar 5 is 4 and Bars 6–8 are 13–15 (Dominos: 12–14). Some of them also switch the main bar for Shadowform, Moonkin Form or Prowl where the game doesn't, so the addon copies the right buttons onto those pages too.

## Getting it into the game

1. Copy this branch's `addon/Barsmith` directory into `Interface/AddOns`, then reload the game. Open this branch's `index.html` in a browser.
2. In `/barsmith`, **Export setup** copies the current supported slots, macros and bar-planner key assignments into a BP2 plan. Press Ctrl+C and **Load** it on the page. **Census** produces a separate BC1 snapshot. Copy it and **Load** it with that plan open. Both strings can be given to an external planner.
3. Edit bar buttons as usual. Under **Binding instructions and collision preview**, add or delete individual instructions, including secondary keys and commands from addons. Deleting an instruction leaves that relationship unmanaged. To release a key in game, add a **REMOVE** instruction naming its current owner.
4. Copy the plan, paste it into `/barsmith` out of combat, and press **Check**. Review the active account/character scope, slot changes and full scrollable binding report. Resolve blocked commands and check again. **Apply** revalidates the checked binding graph before touching any slots, macros or bindings.
5. Auto-fill still places learned spells into empty planned slots. `/barsmith apply` reopens the last plan for review and another Apply.

The game client is the authority. The web preview uses the snapshot attached to the current plan. Browser storage on this branch imports earlier saved plans and keeps its own copy.

## Files

| File | What it is |
|---|---|
| [index.html](index.html) | The planner, with the spellbook data embedded. Plans are saved in your browser. |
| [backdrops/](backdrops) | One screenshot per race (its starting zone) for the screen's backdrop, 1440x900 WebP. |
| [addon/Barsmith](addon/Barsmith) | The in-game importer (`/barsmith`). |
| [tools/build-spellbook.py](tools/build-spellbook.py) | Rebuilds the spellbook data in index.html from Forever's data: `python3 -I tools/build-spellbook.py index.html [cache-dir]` |
| [tools/fetch-backdrops.py](tools/fetch-backdrops.py) | Downloads the race backdrops from Warcraft Wiki and shrinks them: `python3 -I tools/fetch-backdrops.py backdrops` (needs Pillow) |
| [.github/workflows/pages.yml](.github/workflows/pages.yml) | Publishes the page, the backdrops and Barsmith.zip on every push to `main`. |
| [LICENSE](LICENSE) | MIT license for the code. Ships in both addon zips. |
| [.github/workflows/release.yml](.github/workflows/release.yml), [.pkgmeta](.pkgmeta) | Packages the addon and uploads it to CurseForge and GitHub Releases when a `v*` tag is pushed. |

## Binding plans and compatibility

Both plan versions use a prefix followed by base64-encoded UTF-8. Each decoded line contains tab-separated fields. The original escaping for backslash, tab and newline also applies to BP2 binding fields. SLOT, MACRO, CLASS, NAME and RACE retain their existing syntax. Spells accept names, ranks or `spell:ID`. Items accept names or `item:ID`.

| Prefix and header | Binding records | Behavior |
|---|---|---|
| `BP2:`, `BARPLAN 2` | `ENSURE key command` | Give this key to the command. Preserve the command's other keys. |
| | `REMOVE key expected-command` | Release only that relationship. An already free key is a no-op. A different owner blocks Apply. Explicit removal of the last key is reported. |
| | `ALLOWORPHAN command` | Acknowledge a displacement that leaves this particular command without a usable key. Competing instructions still block Apply. |
| `BP1:`, `BARPLAN 1` | `BIND key command` | For each named command, the listed keys form its exact set. Check lists omitted keys as legacy exact removals. Conflicting claims or unresolved displacements block Apply. |

New plans use BP2. Imported BP1 plans and saved upstream browser plans retain BP1 semantics until **Convert BP1 to preservation-safe BP2** is selected. Conversion changes each BIND to ENSURE. Both versions retain multiple keys for a command. Binding order in the Settings UI is managed by the game. Reapplying a matching plan leaves the current key order alone.

Example decoded BP2 plan, with literal tabs:

```text
BARPLAN	2
ENSURE	R	TOGGLEAUTORUN
ENSURE	B	ACTIONBUTTON4
ENSURE	CTRL-B	TOGGLEBACKPACK
```

If B is Backpack's only key, Check reports the following for the last two assignments:

```text
Displacement: B from TOGGLEBACKPACK to ACTIONBUTTON4
New binding: CTRL-B -> TOGGLEBACKPACK
TOGGLEBACKPACK remains on CTRL-B
```

Leaving out the CTRL-B assignment produces `Orphan: TOGGLEBACKPACK will be unbound.` and blocks Apply. An already-correct R and a preserved NUMLOCK contribute to the summary counts. Shift-click **Check** for the individual keys. The preserved count covers usable, unmentioned keys on commands involved in the plan.

## Census and API limits

**BC1** is a read-only snapshot. Its decoded header is `BINDCENSUS<TAB>1<TAB>set` (1 account, 2 character). Each `CMD` record contains context number, command identifier, localized category when available, display label, control type (`binding` or `custom`), and zero or more keys in API order. Zero keys on an ordinary command means currently unbound. An `OVERRIDE key action` row records a detectable runtime difference on a known key. The planner stores census data separately from executable plan instructions.

The addon visits every `GetNumBindings()` index, requests gamepad keys with `GetBinding(i, true)`, and collects every returned key and every `GetBindingKey` result. This includes registered addon commands and unbound rows. For each planned key, Check queries its current persistent owner and follows that command's keys, even for a dynamically bound `CLICK Frame:Button`. The API exposes no universal iterator for frame-owned overrides or unregistered dynamic command strings. A census can therefore describe the exposed registry in full while a later in-game Check discovers additional owners. A bar addon can also change its overrides after Check.

Management targets ordinary persistent gameplay bindings. Context-specific commands (including gamepad-mode commands) and custom controls appear in the census. Attempts to edit them are blocked. Voice push-to-talk exposes its chord through a separate accessor. A runtime override on a touched key is reported. When all of a displaced command's remaining keys are masked by overrides, Check requires explicit acknowledgment.

Factory defaults are unavailable as a complete read-only binding graph in the inspected Forever client. Its Settings reset calls `LoadBindings(Enum.BindingSet.Default)`, which changes the active table. Barsmith never uses that path or infers defaults from unbound commands. A character's current set may be account-wide. Check labels that scope and Apply saves to precisely that active set.

The capture, simulation and guarded writes live in [Bindings.lua](addon/Barsmith/Bindings.lua). Apply rechecks live ownership, the profile and detected overrides, performs only the reviewed differences, verifies the resulting graph and saves once. A write or save failure triggers best-effort restoration of attempted keys, with a recovery failure reported explicitly. A no-op performs no binding write or save. The transaction covers bindings. Slot placement and macro operations retain their existing per-operation error handling. Successful persistence across a client restart requires an in-game test.

## Verification and upstream sync

From the repository root, run the addon suite with `lua tools/tests/bindings.lua` or `texlua tools/tests/bindings.lua`. The planner suite runs with Node and jsdom 26. The optional HTML argument exercises the original upstream example and browser-storage migration.

```sh
git show 3163d36:index.html > /tmp/barsmith-upstream.html
npm install --prefix /tmp/barsmith-test jsdom@26
NODE_PATH=/tmp/barsmith-test/node_modules node tools/tests/planner.cjs /tmp/barsmith-upstream.html
```

One-time setup for a new clone of the fork:

```sh
git remote add upstream https://github.com/rubensayshi/wowforever-barplanner.git
```

To bring later upstream changes into the development branch:

```sh
git switch binding-safety
git fetch upstream
git merge upstream/main
```

After reviewing the merge and rerunning the tests, `git push origin binding-safety` updates the review branch.

## Sources

Binding behavior was checked against the [Forever 1.60.1 UI source, build 71037](https://github.com/Gethe/wow-ui-source/tree/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns). Relevant files are `Blizzard_SettingsDefinitions_Frame/Keybindings.lua` for enumeration, `Blizzard_Settings_Shared/Blizzard_Keybindings.lua` for contexts, saving and reset, `Blizzard_APIDocumentationGenerated/KeyBindingsDocumentation.lua` for the C namespace, and `Blizzard_FrameXML/CustomBindingManager.lua` for separately managed controls. See also [GetBinding](https://warcraft.wiki.gg/wiki/API:GetBinding), [GetBindingKey](https://warcraft.wiki.gg/wiki/API:GetBindingKey) and [GetBindingAction](https://warcraft.wiki.gg/wiki/API:GetBindingAction).

Read 2026-11-01.

- EllesmereUI source (retail 7.2.2, April 2026): https://github.com/Anysu94/EllesmereUI . `EllesmereUIActionBars/EllesmereUIActionBars.lua` maps Bar 1–8 to the standard action pages (slots 1–12, 61, 49, 25, 37, 145, 157, 169) and binding commands ACTIONBUTTON / MULTIACTIONBAR1–7BUTTON. Not checked against the Forever build.
- Bartender4 (https://github.com/Nevcairiel/Bartender4, 8339c74, 2026-10-02), Dominos (https://github.com/tullamods/Dominos, 6653640, 2026-10-31) and ElvUI (https://github.com/tukui-org/ElvUI, 1fe8b7e, 2026-10-31), read 2026-11-01. All three list interface 16001 and have Forever code paths. Bar N shows slots (N−1)×12+1 (Dominos skips bar 12's slots, so its 12–14 are slots 145–180), and bars 1, 3–6 and 13–15 (Dominos 12–14) pass the game's ACTIONBUTTON / MULTIACTIONBAR1–7BUTTON keys on to their buttons with override bindings (Bartender4 `ActionBars.lua` BINDING_MAPPINGS, Dominos `bars/actionBar/button.lua`, ElvUI `Modules/ActionBars/ActionBars.lua` barDefaults). Their default main bar paging on Forever: Bartender4 Prowl → slots 85–96 (`StateBar.lua`, `ActionBars.lua`); Dominos Shadowform → 73–84 and Moonkin Form → 109–120 (`core/barStates/Camelot.lua`, `bars/actionBar/bar.lua`); ElvUI Shadowform → 73–84 and Prowl → 85–96 (`Defaults/Profile.lua` bar1 paging). The addon fills those pages with copies (`COPY_PAGES` in Barsmith.lua).
- EllesmereUI on Forever: https://www.icy-veins.com/wow-forever/news/wow-forever-players-can-now-build-their-perfect-ui-with-ellesmereui/ (403 when fetched; title from search results)
- ForeverSVFix release notes (SavedVariables loading bug, EllesmereUI profiles): https://github.com/nobewayo/ForeverSVFix/releases
- EUI Tweaks (lists game version 1.60.1): https://www.curseforge.com/wow/addons/eui-tweaks
- Action slot numbers, including stance/form pages (slots 73–120, separate from bars 2–5): https://warcraft.wiki.gg/wiki/Action_slot (retail page; Forever differs for some forms, see the next two lines)
- Which forms swap the main bar in Forever: the client's SpellShapeshiftForm table, column BonusActionBar, for build 1.60.1.70707: https://wago.tools/db2/SpellShapeshiftForm?build=1.60.1.70707 . Cat Form 1, Bear and Dire Bear Form 3, Battle Stance 1, Defensive Stance 2, Berserker Stance 3, Stealth 1 (page = slot 73 + 12 × (value − 1)). Moonkin Form and Shadowform are 0, so they keep the normal main bar, unlike retail. There's no Prowl form, so Prowl should stay on the Cat Form page (not checked in game: `/dump GetBonusBarOffset()` while prowling should print 1).
- Forever's own UI source, 1.60.1 (70532), mirrored at https://github.com/Gethe/wow-ui-source/tree/forever (read 2026-11-01): `Blizzard_ActionBarController/ActionBarController.lua` pages the main bar by `C_ActionBar.GetBonusBarIndex()` (so by the table above), and `Blizzard_ActionBar/Shared/MultiActionBars.xml` gives Edit Mode's Bar 2, 3, 4 (RightBar1), 5 (RightBar2) and 6–8 the slots 61, 49, 25, 37, 145, 157, 169 and buttons MULTIACTIONBAR1–7BUTTON, the same as the planner's bars.
- Spellbook data (read 2026-11-03), built by tools/build-spellbook.py:
  - Trainer spells per class with each rank's level, active talents and racials: wowforevertalents.com (https://wowforevertalents.com/abilities/, /<class>/, /racials/), which reads the Forever client build 1.60.1.70707 and the server hotfixes of 30 October.
  - Spell IDs per rank, passive flags and race limits (for example Desperate Prayer is Dwarf-only, Fear Ward is for every priest): the Forever client's tables for build 1.60.1.70707 via wago.tools (https://wago.tools/db2/SkillLineAbility?build=1.60.1.70707, plus SpellName, Spell, SpellMisc, Talent, TalentTab).
  - Spell ID per talent rank, including talents only the hotfixes add (Water Shield, Riptide, Oath of Light): the talent calculator script on wowforevertalents.com (the `/_astro/TalentCalculator.*.js` bundle and the scripts it imports). A talent is listed when the client marks its spell as not passive; the site's cost line decides only for spells the client tables lack, since some actives (Water Shield) have no cost line.
  - Trainer ranks newer than the client tables (the top rank of Lacerate) and renamed ranks have no ID, so their tooltip is the text from wowforevertalents.com.
- Race backdrops, starting-zone screenshots from Warcraft Wiki (fetched 2026-11-01, file names in tools/fetch-backdrops.py): Human Northshire Abbey, Dwarf Kharanos, Gnome Gnomeregan Entrance, Night Elf Dolanaar, Orc Valley of Trials, Undead Tirisfal Glades, Tauren Camp Narache, Troll Durotar, Skyborne Dalaran (Zephras Isle has no screenshots on the wiki yet). Some are from later expansions, so they don't always look like the Classic client. https://warcraft.wiki.gg/images/<file>
- Original idea: Naowh's Forever action bar planner, https://naowh.gg/forever/action-bars (it only sets up bars for Naowh's own addon suite)
- Heading font: Marcellus (Google Fonts), standing in for the game's Friz Quadrata
- Spell icons load from https://wow.zamimg.com/images/wow/icons/
- Tooltips load from Wowhead's Forever database when you hover a spell, stance or item: https://nether.wowhead.com/forever/tooltip/spell/<id> (the same source as https://www.wowhead.com/forever/spell=<id>). Checked 2026-11-01: 26 of 40 sampled spells differ from Classic, e.g. Lightning Bolt has a 2.5 sec cast. General spells (Attack, racials) have no ID in the data, so they keep the planner's own tooltip.
- CurseForge files for Forever are tagged with game version 1.60.1 (seen on EUI Tweaks above and others, e.g. https://www.curseforge.com/wow/addons/wow-forever-suite/files/all). The names BarPlan (https://www.curseforge.com/wow/addons/barplan, a different Forever addon with its own `/barplan`) and BarSmith (https://www.curseforge.com/wow/addons/barsmith, retail only) are taken, hence "Barsmith Importer".
- BigWigsMods/packager v2.6.1, `release.sh`: interface 16xxx maps to game type forever (CurseForge game version type 88568), the only Forever TOC suffix it knows is `_Camelot`, and it skips WoWInterface for Forever: https://github.com/BigWigsMods/packager/blob/v2.6.1/release.sh (Forever support added in https://github.com/BigWigsMods/packager/pull/202)

The code (page, addon and tools) is under the MIT license, see [LICENSE](LICENSE). World of Warcraft and its icons and screenshots are Blizzard Entertainment's. This is a fan tool.
