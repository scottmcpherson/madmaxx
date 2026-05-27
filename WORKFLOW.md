# Workflow

This is the simple Git workflow for working with agents in this repository.

## Start A Session

- Run `git status --short` and `git branch --show-current`.
- Treat existing worktree changes as user-owned.
- Do not reset, discard, stash, rebase, or switch away from existing changes
  unless explicitly requested.

## Start A Feature

- Start feature work from `main` when possible.
- Keep unrelated features on separate branches.
- Use a focused branch name, for example `feature/tab-title-fix`.
- If the current branch already clearly matches the task, continue there
  instead of creating a new branch.

## Finish A Feature

- Review the diff against `main`.
- Run the narrowest relevant formatting, build, or tests from `AGENTS.md`.
- Commit the feature work intentionally.
- Merge the feature branch into `main` when ready.
- Do not push unless explicitly requested.

## Before A Release

- Treat `main` as the only release source.
- Check for local and remote branches that have not landed on `main`.
- Decide whether each branch should be merged, deferred, or abandoned.
- Require a clean, up-to-date `main` before release work.

## Cut A Release

- Do not create tags, push branches, publish releases, or otherwise change
  remote repository state unless explicitly requested.
- Require an explicit version or tag.
- Show the release plan before running remote-changing commands.
- Ask for explicit confirmation before tagging, pushing, or publishing.
