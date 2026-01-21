# Local Environment Instructions

**Status:** Template - No custom instructions configured

This file is read by `/ap_release` and other workflow commands to handle project-specific environment requirements. If your project needs custom release workflows, validation steps, or environment configuration, document them here.

---

## When to Use This File

Add instructions here when your project has:

- **Polyrepo architecture** - Multiple git repositories that must be coordinated
- **Custom release processes** - Additional validation, deployment, or notification steps
- **Environment-specific setup** - Required configuration before running workflows
- **Extended arguments** - Additional command-line arguments for workflow commands
- **Multi-step validation** - Complex validation requiring multiple tools or environments
- **Cross-repository dependencies** - Release ordering or dependency management

---

## Template Structure

Replace this template content with your actual instructions. Recommended sections:

### Project Configuration
Describe your project's structure, paths, and key files.

### Extended Arguments
Document any additional arguments your commands accept beyond the standard ones.

### Workflow Modifications
Explain how your project's workflow differs from the standard template.

### Step-by-Step Instructions
Provide clear, actionable steps that integrate with the standard workflow.

### Examples
Show concrete examples of common operations in your environment.

---

## Example: Polyrepo Configuration

See the nap project's local_environment_instructions.md for a real-world example of coordinating releases across multiple repositories with dependency ordering.

---

## Getting Started

1. Replace this template content with your project's specific instructions
2. Keep instructions concise and actionable
3. Reference the standard workflow steps where applicable
4. Test your instructions with a dry-run before committing
5. Update this file as your project's needs evolve

**Remember:** These instructions augment the standard workflow - they don't replace it. Focus on what's unique to your project.
