---
name: browser-timeout-guard
description: Check the local timeout workaround before external Chrome/Edge extension automation on this Windows machine, and diagnose recurring 10–20 second timeouts. Use read-only detection first; repair only a confirmed affected runtime with recognized code patterns. Do not use for the in-app browser.
---

# Browser Timeout Guard

Before the first external Chrome/Edge extension operation in a session, run read-only detection. Repeat only after a plugin update or a new timeout symptom:

```powershell
& "$env:USERPROFILE\.codex\skills\browser-timeout-guard\scripts\Repair-BrowserTimeout.ps1" -CheckOnly
```

The script scans legacy `openai-bundled/browser` and `openai-bundled/chrome` bundles. Its scan does not establish which runtime the current browser tool actually uses. Identify the active runtime from the tool/plugin metadata before interpreting a match as relevant.

- `OK`: continue the requested browser operation.
- `NEEDS_REPAIR` (exit 2): inspect the reported bundle and verify the active runtime uses it and matches the known affected code. A match in an unused cached version is not a reason to repair. If the metadata does not identify the active version/path, or the association cannot be established from available evidence, leave the cache unchanged and proceed with the user's requested browser operation. Investigate the runtime further only if that operation actually fails or times out; missing metadata alone must not block browser work.
- `UNSUPPORTED` or no legacy bundle (exit 3): this does not prove the active browser is broken. Continue a normal requested operation when its tool is available. If it fails, diagnose the active runtime and preserve the unsupported bundle.

Do not run the script in mutation mode against the entire default cache: it can change multiple versions and partially modify unsupported bundles. For a confirmed affected active version, stage only that version under a task-local cache with the same `<browser-or-chrome>/<version>/scripts/` layout. Use `-PluginCacheRoot <staged-cache>` with `-CheckOnly` first, then without `-CheckOnly` only if all staged targets are recognized. Review the diff and JavaScript syntax, recheck that the active original has not changed, preserve its original backup, and apply only the verified repair to that version. Never edit unrelated cached versions.

The known workaround bounds an unavailable site-status request to 1.5 seconds using the existing fail-open path. Preserve URL safety checks; never remove or unconditionally bypass them. Unknown code layouts require diagnosis and narrowly scoped validation before any repair, not automatic pattern expansion during an unrelated browser task.

If the active loaded bundle was changed and requires a restart, explain the affected path and why a restart is necessary before asking the user to restart Codex. A `RESTART_REQUIRED` message from a staged copy alone does not mean the active runtime changed.

Use the user's requested browser operation as the functional check; do not add a separate latency probe after a successful check or repair.
