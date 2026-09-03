# Shell and verification guardrails

Hard-won in this repo. Each line below cost a real mistake.

## The shell is zsh, not bash

- **Unquoted variables do not word-split.** `for x in $LIST` iterates **once** over the whole
  string. Use an array: `LIST=(a b c)` then `for x in "${LIST[@]}"`. A skip-list built this way
  silently matches nothing, and the loop processes every item it was meant to exclude.
- **Quote glob arguments.** `grep --include=*.yaml` fails with `no matches found`. Write
  `--include='*.yaml'`.
- **Quote URLs containing `?` or `&`.** `gh api "repos/o/r/contents?ref=v1"`, not bare.
- Prefer `python3` heredocs with a quoted delimiter (`<<'PYEOF'`) for multi-file edits. Shell
  expansion inside an unquoted heredoc will mangle `${...}` and backticks.

## Staging

- **Never `git add -A`, `git add .`, or `git add <directory>`.** Stage explicit file paths only.
  This working tree routinely holds unrelated in-progress work; a directory-wide add sweeps it
  into someone else's commit under a misleading message.
- Run `git status --short` before committing and confirm every staged path is yours.
- Split unrelated changes into separate commits even when they touch the same file.

## Do not judge what you have not read

- **Never truncate output you are about to draw a conclusion from.** `gh pr diff | head -20` will
  show only the version bump and hide the rest. Measure first (`| wc -l`), then read in full.
- For Renovate PRs, the source diff is 2-8 lines and tells you almost nothing. The **Flate PR
  comment** renders what the chart actually produces - that is the real impact. A version-only
  diff can render 121 changed hunks across 14 objects.

## Verify before landing

- **Confirm an image tag exists** in the registry before committing a manifest that pins it.
  Consistent references are not the same as valid ones.
- **Confirm a chart value key exists** via `helm show values <chart>`. Helm silently ignores keys
  that do not exist, so a setting can look applied for months while doing nothing.
- **Check whether a workload is live or dormant** before assessing risk. Apps commented out of
  `clusters/aeon/apps/*/kustomization.yaml` have no running pods, so manifest changes to them
  carry no immediate blast radius.

## Kubernetes immutability

- `PersistentVolumeClaim.spec.dataSourceRef` is **immutable once bound**. Swapping a component
  that changes it will be rejected by the API server and wedge the Kustomization. Migrating a
  populated PVC requires scale-down, delete, repopulate.
- Check `spec` immutability generally before assuming a component swap is a no-op on live objects.
