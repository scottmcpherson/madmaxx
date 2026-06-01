# Workflow

This repository uses a branch-and-PR workflow. `main` should stay releasable,
local checks should catch obvious problems before review, and CI should be the
merge gate for non-trivial work.

## Core Rules

- Keep `main` clean, current, and releasable.
- Do not work directly on `main` unless explicitly requested.
- Put each unrelated feature, bug fix, or refactor on its own branch.
- Prefer pull requests for shared, risky, CI-backed, or non-trivial work.
- Treat local tests as a preflight check, not a replacement for CI.
- Do not push, tag, publish, or otherwise change remote state unless explicitly
  requested.

## Start A Session

- Run `git status --short` and `git branch --show-current`.
- Treat existing worktree changes as user-owned.
- Do not reset, discard, stash, rebase, or switch away from existing changes
  unless explicitly requested.
- If the worktree is dirty, understand whether the existing changes belong to
  the current task before editing.

## Start New Work

- Start new unrelated work from an up-to-date `main`:
  - `git switch main`
  - `git pull --ff-only`
  - `git switch -c <type>/<short-description>`
- Use focused branch names, for example `fix/tab-title-crash` or
  `feature/codex-sidebar-status`.
- If the current branch already clearly matches the task, continue there.
- If the current branch is for different work, stop and finish, commit, or
  explicitly set aside that work before starting a new branch.

## During Work

- Keep unrelated changes out of the branch.
- If a bug is discovered while working on a feature, fix it on the same branch
  only when it is part of that feature.
- If the bug is unrelated, create a separate branch from `main`.
- Prefer a small WIP commit on the current branch over a stash when context
  needs to be preserved.

## Finish Work

- Review the branch before publishing:
  - `git status --short`
  - `git diff main...HEAD`
  - `git diff`
  - `git diff --cached`
- Run the narrowest relevant formatting, build, or tests from `AGENTS.md`.
- Commit the work intentionally with a clear message.
- Push the branch and open a PR when the work is shared, non-trivial, or should
  be validated by CI.
- Let CI pass before merging.
- Merge through the PR for CI-backed or collaborative work.

## Multiple Items

- Work one unit at a time.
- After a branch is merged, update `main` before starting the next branch.
- If the previous branch is not merged yet, still start unrelated work from
  `main`, not from the previous feature branch.
- Stack branches only when the later work intentionally depends on the earlier
  branch.

## Before A Release

- Treat `main` as the only release source.
- Require a clean, up-to-date `main` before release work.
- Check for local and remote branches that have not landed on `main`.
- Decide whether each branch should be merged, deferred, or abandoned.
- Confirm required CI is green on the release source.

## Cut A Release

- Do not create tags, push branches, publish releases, or otherwise change
  remote repository state unless explicitly requested.
- Require an explicit version or tag.
- Show the release plan before running remote-changing commands.
- Ask for explicit confirmation before tagging, pushing, or publishing.
