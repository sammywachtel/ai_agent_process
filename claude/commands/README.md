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
