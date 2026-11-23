---
name: release
description: Package RightMouseMenu as a DMG and publish it as a GitHub Release. Use when the user asks to release, package, or ship the app to GitHub.
---

# Release RightMouseMenu

Output is `RightMouseMenu-<version>-universal.dmg` attached to a GitHub Release tagged `v<version>`.
Work through the steps in order; each outward-facing step (commit, push, release) needs the user's go-ahead
unless they already gave it for that step in this request.

## 1. Code must be committed and pushed

```sh
git status --porcelain
git log origin/main..HEAD --oneline   # unpushed commits
```

- If the tree is dirty: summarise the changes, propose a commit message, and **ask the user to approve**.
  After approval: `git add` the intended files (never stray files such as `.swp`), `git commit`, `git push`.
- If there are unpushed commits, ask, then `git push`.
- Do not build until the tree is clean. The app's About page shows `0.1.0 (<commit>)`, or `(<commit> - dirty)`
  when built from uncommitted changes, so a dirty build would ship a misleading version.

## 2. Version

- Default: the current `MARKETING_VERSION` in `Scripts/generate_project.py` (also mirrored in `project.yml`).
- If the user asks for a different version, update it in **both** targets in `generate_project.py` (app and
  extension) and in `project.yml`, run `python3 Scripts/generate_project.py`, then commit and push (step 1 again,
  with approval) before building.
- Check whether the version already exists on GitHub:
  `gh release view v<version>` and `git ls-remote --tags origin v<version>`.
- If either exists, show the user what is there (release title, publish date, the commit the tag points to, attached
  files) and **ask whether to overwrite it**. Do not overwrite without an explicit yes.
  - **Yes**: delete the old release and tag, then continue with step 3 and publish as a fresh release on the current
    commit:
    ```sh
    gh release delete v<version> --cleanup-tag --yes   # removes the release and the remote tag
    git push origin :refs/tags/v<version>              # only if a tag remains without a release
    git tag -d v<version>                              # local tag, if present
    ```
  - **No**: stop, and suggest bumping the version instead (see above).

## 3. Build the DMG

```sh
bash Scripts/package_dmg.sh
```

It builds Release for all architectures, checks that the app and the Finder extension contain the same
architectures, verifies the code signature, and writes `.build/release/RightMouseMenu-<version>-universal.dmg`.
The `-universal` label is added only when the binary really contains both arm64 and x86_64; otherwise the script
leaves it out. The script prints `Version <v> (<commit>)`: confirm there is no `- dirty`.

## 4. Publish

```sh
gh release create v<version> .build/release/RightMouseMenu-<version>-universal.dmg \
  --target "$(git rev-parse HEAD)" --title "RightMouseMenu <version>" --notes-file <notes>
```

Use the real file name the script printed. Notes: a short change list from
`git log --oneline <previous tag>..HEAD` (or all commits for the first release), then:

> The app is ad-hoc signed and not notarized. On first launch, right-click the app and choose Open (or run
> `xattr -dr com.apple.quarantine /Applications/RightMouseMenu.app`). Then enable the Finder extension in
> System Settings → General → Login Items & Extensions → Finder.

Finish by giving the user the release URL.
