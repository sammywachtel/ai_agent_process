# Claude Code Commands

Copy the command files from this directory into your project’s `.claude/commands/` folder.

- **ap_exec.md** – slash command `/ap_exec <scope> <iteration>` that performs implementation and validation for a single iteration and then triggers `/ap_iteration_results`.
- **ap_iteration_results.md** – slash command `/ap_iteration_results <scope> <iteration>` that documents the results using `test-output.txt`.

After copying, restart Claude Code (or reload commands) so the new shortcuts are available.
