# Step 06: Update Version Files (release mode ONLY)

**Model tier:** cheap
**Tools needed:** Read, Write
**Input:** structure output (`.run/release/02-structure.md`), new version
**Output:** `.run/release/06-version-update.md`

---

## Your Task

Update version in all detected version files to the new version. Only runs in `release` mode.

## Update Each File

For `pyproject.toml`:
```toml
[project]
version = "{new_version}"
```

For `package.json`:
```json
{
  "version": "{new_version}"
}
```

For `setup.py`:
```python
setup(version="{new_version}", ...)
```

**For full-stack projects, update ALL version files to the same version.**

## Output Format

Write to `.run/release/06-version-update.md`:

```markdown
# Version Update

**New version:** {X.Y.Z}

## Files Updated
- `{path}`: {old} → {new}
```
