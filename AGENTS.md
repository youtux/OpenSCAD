# OpenSCAD Integration Guide for Agents

## Running OpenSCAD on macOS

When working with OpenSCAD files programmatically or in a terminal on macOS, use the full path to the executable:

### Command Format

```bash
/Applications/OpenSCAD.app/Contents/MacOS/openscad [options] <input_file> -o <output_file>
```

### Common Examples

### Important Notes

1. **Output format** must be specified via file extension or `--export-format` option
2. **Working directory** matters for relative `include` statements
3. **Echo statements** in SCAD files will be printed to stdout/stderr
4. **Exit codes** indicate success (0) or failure (1)
5. Use `2>&1` to capture both stdout and stderr
6. The macOS app bundle path is: `/Applications/OpenSCAD.app/Contents/MacOS/openscad`

### Debugging Tips

When developing SCAD scripts with complex logic:

1. Add `echo()` statements with descriptive messages
2. Run through OpenSCAD to see the output
   ```bash
   /Applications/OpenSCAD.app/Contents/MacOS/openscad --preview -o /tmp/test.stl debug.scad 2>&1
   ```

### Environment

- Platform: macOS
- Shell: zsh (or bash)
- Standard output handling: Redirect with `>`, `2>&1` for stderr

## Git Workflow

When committing changes to the repository:

1. **Never use `git add -A`** - this can add unwanted files
2. **Add files individually** using `git add <specific-file>` for each modified file
3. Review changes with `git status` before committing
4. Use descriptive commit messages that explain what was changed and why
