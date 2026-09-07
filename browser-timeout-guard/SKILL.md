---
name: browser-timeout-guard
description: Check and repair the local Codex Chrome plugin timeout workaround before external-browser automation. Use on this Windows machine before the first chrome:control-chrome or other external Chrome/Edge extension operation in a session, after Codex/plugin updates, or whenever external-browser commands repeatedly take about 10–20 seconds or time out. Do not use for browser:control-in-app-browser operations.
---

# Browser Timeout Guard

Run the deterministic preflight before the first external Chrome/Edge browser operation in each Codex session. Do not run it for the in-app Browser:

```powershell
& "$env:USERPROFILE\.codex\skills\browser-timeout-guard\scripts\Repair-BrowserTimeout.ps1"
```

The script scans installed `openai-bundled/browser` and `openai-bundled/chrome` plugin versions, repairs known timeout-causing code paths, creates one original backup beside every changed bundle, and validates JavaScript syntax. It keeps the site-status safety request but bounds an unavailable request to 1.5 seconds, using the plugin's existing fail-open path instead of disabling the check.

After a successful preflight, continue with the requested external-browser task. Do not run a separate browser latency probe: the user's first requested external-browser operation is the functional check.

If the script reports `RESTART_REQUIRED`, ask the user to restart Codex before browser work because the loaded runtime may still contain the old bundle. If it reports an unsupported bundle layout, stop modifying that bundle, inspect the new code structure, and update the script with narrowly scoped patterns. Never remove or unconditionally bypass URL safety checks.

Use `-CheckOnly` for diagnosis without changing files. Use `-PluginCacheRoot <path>` only for isolated testing.
