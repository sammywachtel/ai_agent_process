# Claude Code Commands

**The actual command files are located in your project's `.claude/commands/` directory (note the dot prefix).**

This directory serves as a reference placeholder in the template structure.

## Available Commands

| Command | Invocation | Purpose |
|---------|------------|---------|
| `ap_project.md` | `/ap_project <action>` | Roadmap, requirements, backlog management |
| `ap_exec.md` | `/ap_exec <scope> <iteration>` | Execute implementation iterations |
| `ap_release.md` | `/ap_release <mode>` | Changelog, PR creation, release tagging |
| `ap_iteration_results.md` | `/ap_iteration_results <scope> <iteration>` | Document iteration results |
| `ap_changelog_init.md` | `/ap_changelog_init` | Initialize CHANGELOG from git history |

## Quick Reference

```bash
# Project management
/ap_project init                    # Initialize roadmap
/ap_project status                  # Check project status
/ap_project add-todo "description"  # Add backlog item
/ap_project add-requirement "name"  # Create requirement

# Iteration workflow
/ap_exec scope_name iteration_01    # Execute iteration
/ap_exec scope_name iteration_01_a  # Execute sub-iteration

# Release workflow
/ap_release pr                      # Create PR only
/ap_release release patch           # Patch release
/ap_release noscope pr              # PR without scope context
```

## Documentation

For detailed usage of each command, see:
- Each `.md` file in `.claude/commands/`
- `claude/commands.md` for full command reference
- `README.md` for framework overview

## Customization

For projects with unique workflow requirements (polyrepo, custom CI/CD, etc.):

**File:** `.agent_process/process/local_environment_instructions.md`

Commands automatically check this file for:
- Extended command arguments
- Multi-repository coordination
- Custom validation steps
- Environment-specific setup

This file is preserved across re-installations.
