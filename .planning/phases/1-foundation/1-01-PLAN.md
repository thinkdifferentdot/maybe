---
phase: 01-foundation
plan: 01
type: execute
domain: rails
---

<objective>
Add the official Anthropic Ruby SDK to the project as a dependency.

Purpose: Install the anthropic gem that will be used to communicate with Claude's API. This is the foundational step - without the gem, no other implementation is possible.

Output: anthropic gem (~> 1.16.0) added to Gemfile and successfully bundled
</objective>

<execution_context>
~/.claude/get-shit-done/workflows/execute-phase.md
./summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/1-foundation/1-CONTEXT.md
@.planning/phases/1-foundation/1-RESEARCH.md
@Gemfile
@.ruby-version
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add anthropic gem to Gemfile</name>
  <files>Gemfile</files>
  <action>Add the anthropic gem to the AI section of Gemfile (near line 92, after `gem "ruby-openai"`). Use version constraint `~> 1.16.0` per the research findings. The official SDK requires Ruby 3.2+, and the project uses Ruby 3.4.7, so compatibility is confirmed. Do NOT add any other gems or modify any other lines.</action>
  <verify>grep 'anthropic' Gemfile shows the gem entry with correct version constraint</verify>
  <done>anthropic gem present in Gemfile with ~> 1.16.0 constraint, located in AI section near ruby-openai</done>
</task>

<task type="auto">
  <name>Task 2: Bundle install to install the gem</name>
  <files>Gemfile.lock</files>
  <action>Run `bundle install` to install the anthropic gem and update Gemfile.lock. This will download and install the gem and its dependencies (connection_pool is bundled with the gem). Verify the installation succeeds without errors.</action>
  <verify>bundle list | grep anthropic shows the installed gem version; Gemfile.lock contains anthropic entry</verify>
  <done>anthropic gem successfully installed, Gemfile.lock updated, no bundle errors</done>
</task>

<task type="auto">
  <name>Task 3: Verify gem installation and basic load</name>
  <files>(none - verification only)</files>
  <action>Run `gem list anthropic` to confirm the gem is installed. Optionally, run `ruby -e "require 'bundler/setup'; require 'anthropic'; puts 'Anthropic gem loaded successfully'"` to verify the gem can be loaded without errors. This confirms the installation is working before we proceed to use it in the next plan.</action>
  <verify>gem list anthropic shows installed version (should be 1.16.x); ruby require command succeeds without errors</verify>
  <done>anthropic gem installed and loadable, ready for use in Provider::Anthropic class</done>
</task>

</tasks>

<verification>
Before declaring plan complete:
- [ ] `grep anthropic Gemfile` shows gem entry with correct version
- [ ] `bundle list | grep anthropic` shows installed gem
- [ ] `gem list anthropic` confirms installation
- [ ] `ruby -e "require 'anthropic'"` succeeds without errors
</verification>

<success_criteria>

- anthropic gem added to Gemfile with ~> 1.16.0 constraint
- bundle install completed successfully
- Gem can be loaded via `require 'anthropic'`
- No bundle conflicts or errors
</success_criteria>

<output>
After completion, create `.planning/phases/1-foundation/1-01-SUMMARY.md`:

# Phase 1 Plan 1: Add Anthropic Gem Summary

**Added official anthropic gem (~> 1.16.0) as a project dependency**

## Accomplishments

- Added anthropic gem to Gemfile AI section (following ruby-openai pattern)
- Successfully bundled and installed the gem
- Verified gem loadability with require test

## Files Created/Modified

- `Gemfile` - Added `gem "anthropic", "~> 1.16.0"` in AI section
- `Gemfile.lock` - Updated with anthropic and its dependencies

## Decisions Made

- Used official anthropic gem (not community ruby-anthropic) for long-term support
- Version constraint ~> 1.16.0 allows patch/bugfix updates but breaks on major/minor changes
- Confirmed Ruby 3.4.7 compatibility (SDK requires 3.2+)

## Issues Encountered

None

## Next Step

Ready for 1-02-PLAN.md - Create Provider::Anthropic class skeleton
</output>
