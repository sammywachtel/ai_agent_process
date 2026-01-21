# Claude Code Commands

**The actual command files are located in your project's `.claude/commands/` directory (note the dot prefix).**

This directory serves as a reference placeholder to maintain the template structure.

## Available Commands

The following commands are installed to `.claude/commands/`:
- `ap_changelog_init.md` - Initialize CHANGELOG.md from git history
- `ap_exec.md` - Execute one iteration with validation
- `ap_iteration_results.md` - Document iteration results
- `ap_project.md` - Roadmap management (init, discover, status, etc.)
- `ap_release.md` - Changelog updates, PR creation, and release tagging

## Usage

Commands are invoked with the `/` prefix in Claude Code:
```
/ap_project status
/ap_exec scope_name
/ap_release pr
```

See each command file in `.claude/commands/` for detailed usage.

## Customization

### Local Environment Instructions

If your project has unique workflow requirements (polyrepo, custom CI/CD, etc.), customize command behavior using:

**File:** `../.agent_process/process/local_environment_instructions.md`

Commands like `/ap_release` automatically check this file for project-specific:
- Extended command arguments
- Multi-repository coordination
- Custom validation steps
- Environment-specific setup

This file is preserved across re-installations, allowing you to maintain project-specific workflows without modifying the core template files.
