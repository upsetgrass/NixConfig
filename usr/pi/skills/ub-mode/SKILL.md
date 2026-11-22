---
name: ub-mode
description: >
  Follow the reduced principles when writing or changing code. Every change
  follows First Make it Work, then Then Make it Right, then Follow Practice.
  Use when the user invokes /skill:ub-mode or asks for the reduced principles.
---

<!-- Adapted from unclebob/ub-mode, commit 3da62bf3fcfd2034de41f30d920d2739e566171f. Local Git policy below overrides the upstream Practice section. -->

# ub-mode

Every time you are asked to make a change follow:
* First Make it Work.
* Then Make it Right.
* Follow Practice.

## Git writes require an explicit user request

This rule takes precedence over every other step of this skill, including cleanup and finishing a task. Do not run Git-related writes by default, directly or indirectly through scripts, tools, hooks, or hosting-service APIs. This includes changing the working tree, index, refs, history, branches, tags, worktrees, remotes, or pull requests: e.g. `git add`, `commit`, `push`, `fetch`, `pull`, `merge`, `rebase`, `reset`, `checkout`, `switch`, `stash`, `clean`, `branch -d`, `tag`, `worktree add/remove/prune`, and write-mode `git config`. Read-only inspection such as `git status`, `git diff`, `git log`, and `git show` is fine.

Only perform a **specific** Git write when the user explicitly asks you to perform that operation in their own prompt; authorization for one operation (for example, commit) does not authorize another (for example, push). Generic requests to fix code, finish the task, follow ub-mode, or 'handle Git' do not count. If intent is ambiguous, ask first. When the user only asks how to do a Git write, explain the appropriate commands without executing them. Never infer permission to commit, push, or clean from a successful test or from the original ub-mode instructions.

# First Make it Work

## Laziness Protocol

* One decision lives in one place.
* Ship the smallest edit that solves the problem.

## Foundational Thinking

* Get the data shape right before you write the logic.
* Do first whatever helps every later phase.
* If a concurrent writer would matter, do not share state.

## TDD

* Write the failing test before you change the code.
* See it fail for the reason you expect.
* Make the smallest change that makes it pass.
* If an honest test is impractical, do not write a bad one.

## Redesign From First Principles

* Do not bolt a new requirement onto the old design.
* Ask what you would have built if it had been there from the start, think that through, and deliver it in pieces.

## Attack the Premise

* When two fixes that share one premise fail the same gate, write that premise in one sentence and count which actors hold the imbalance.
* Remove the assignment.
* Do not start another fix until you have done that.

## Subtract Before You Add

* Take complexity out before you add anything.

## Outcome-Oriented Execution

* Aim at the end state you can check.
* A break in the middle is allowed when you planned it and can undo it.

## Build the Lever

* If the work is not obvious at a glance, build the tool that does it.
* Do one unit by hand, then make the tool match that unit.

## Architecture

### Model the Domain

* Put the domain in a structure that makes the illegal states impossible.
* Maintain a glossary of domain terms.
* If the code is already clear and local, leave it.

### Boundary Discipline

* Check the data where it enters.
* Inside, trust it.
* Keep the business logic in a pure function.

### Type System Discipline

* Make the illegal value impossible to write.
* Parse outside data once, where it comes in.
* Do not silence the compiler.

### Make Operations Idempotent

* Running it twice, or running it after a crash halfway through, ends in the same state.

### Separate Before Serializing Shared State

* If they do not need the same mutable thing, give each its own.
* If they do, allow one writer, and enforce that in the structure.

# Then Make it Right

## Fix Root Causes

* Reproduce it.
* Fix the cause.
* A guard that only hides the crash is not a fix.

## Sequence work into verifiable units

* Finish one small unit and check it.
* Then start the next.

## Test Behavior, Not Implementation

* The test calls the code the way its user does and checks the result that user would see.
* If the test would still pass when every function returned nothing, throw it out.

## Crapper

* Use the crapper tool
* Reduce each function under  CRAP 10 by splitting it, by testing it, or both.
* Consider whether case statements are worth reducing.

## Dryer

* Use the dryer tool to eliminate duplication that rank 0.8 or above.

## Mutator

* Use the mutator tool
* Cover the uncovered.
* Kill the survivors.
* Delete dead code.

## Refactoring

* Pin what the code does.
* Change the structure.
* Prove the behavior did not change.

# Practice

## Keep a Log

* Keep a log of every action you take and the reason you took it.
* Report that log upon completion.

## Guard the Context Window

* Keep the main thread small.
* Send the bulk elsewhere, and keep the summary.

## Worktree Cleanup

* Identify what might be safe to remove, but do not remove worktrees, clean files, or make other Git-related changes without an explicit user request for that operation.
* Uncommitted work waits for the user's decision; report it instead of clearing it.

## Git Handoff (No Automatic Commit or Push)

* Summarize the changes, verification, and any remaining Git steps as recommendations. Do not commit or push as part of completing a coding task.
* If the user explicitly asks you to make a commit, do only the authorized Git operations and describe why, what changed, and how you verified it.
* Push only when separately and explicitly requested; never assume the destination is the main branch. If the user asks only for advice, explain the commands but do not run them.
