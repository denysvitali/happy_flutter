# The Perfect CLAUDE.md: Complete Research Synthesis

This document synthesizes research from 20 specialized agents analyzing CLAUDE.md best practices across documentation, community resources, and real-world examples.

## Executive Summary

The perfect CLAUDE.md file:
- **Stays under 200-300 lines** (ideally under 150)
- **Contains only universally applicable instructions** — things Claude cannot infer
- **Uses progressive disclosure** — links to detailed docs rather than inlining
- **Focuses on WHY, WHAT, and HOW** — purpose, tech stack, and workflows
- **Is ruthlessly pruned** — every line must prevent mistakes

---

## 1. Structure and Format Best Practices

### Essential Sections (Must Include)

| Section | Purpose | Example Length |
|---------|---------|----------------|
| **Workflow Rules** | Universal must-follow rules | 2-5 lines |
| **Project Overview** | One-sentence description + tech stack | 5-10 lines |
| **Common Commands** | Build, test, run commands | 15-25 lines |
| **Architecture** | Project structure, key patterns | 20-40 lines |
| **Key Conventions** | Critical coding patterns | 10-20 lines |

### Recommended Heading Hierarchy

```markdown
# CLAUDE.md

## Workflow Rules
[Critical rules that apply to every task]

## Project Overview
[Brief description and tech stack]

## Common Commands
[Essential commands with descriptions]

## Architecture
### Project Structure
[Directory tree with descriptions]

### Key Patterns
[Important architectural patterns]

## Coding Conventions
[Critical conventions that differ from standards]
```

### Formatting Guidelines

**Use bullet points for:**
- Lists of technologies, tools, dependencies
- Naming conventions and patterns
- Short rules and guidelines

**Use code blocks for:**
- Shell commands (always specify language: `bash`)
- File structure diagrams
- Configuration examples

**Use tables for:**
- Mapping relationships
- Quick reference comparisons
- Provider/state mappings

### Emphasis Strategy

Use emphasis **sparingly** and **at the beginning** of instructions:

| Word | Use For | Example |
|------|---------|---------|
| **MUST** | Requirements | "MUST verify before proceeding" |
| **NEVER** | Prohibitions | "NEVER commit directly to main" |
| **ALWAYS** | Universal rules | "ALWAYS run tests before committing" |
| **IMPORTANT** | Critical notes | "IMPORTANT: hide TabBar when importing custom" |

---

## 2. Progressive Disclosure Patterns

### The @imports System

Use `@path/to/file` to include additional context without bloating the main file:

```markdown
See @README.md for project overview.
See @docs/architecture.md for detailed architecture.
See @docs/testing-patterns.md for testing guidelines.
```

**Key points:**
- Imports are evaluated at session start (not lazy)
- Maximum recursion depth: 5 levels
- First-time use shows approval dialog

### The .claude/rules/ Directory

For larger projects, split instructions into modular rule files:

```
.claude/
├── CLAUDE.md              # Main instructions
└── rules/
    ├── code-style.md      # Code style guidelines
    ├── testing.md         # Testing conventions
    └── security.md        # Security requirements
```

**Path-specific rules with frontmatter:**

```yaml
---
paths:
  - "src/api/**/*.ts"
---

# API Development Rules
- All endpoints must include input validation
```

### Skills vs CLAUDE.md

| Use CLAUDE.md For | Use Skills For |
|-------------------|----------------|
| Universal rules (every task) | Task-specific workflows |
| Project architecture | Domain knowledge |
| Common commands | Repeatable procedures |
| Critical conventions | Background information |

---

## 3. Content Guidelines

### Include in CLAUDE.md

- Bash commands Claude cannot guess
- Code style rules that differ from defaults
- Testing instructions and preferred runners
- Repository etiquette (branch naming, PR conventions)
- Architectural decisions specific to your project
- Developer environment quirks
- Common gotchas or non-obvious behaviors

### Exclude from CLAUDE.md

- Anything Claude can figure out by reading code
- Standard language conventions Claude already knows
- Detailed API documentation (link instead)
- Information that changes frequently
- File-by-file descriptions
- Self-evident practices like "write clean code"

### Command Documentation

**Document explicitly:**
- Wrapper tools (e.g., `devenv shell -- flutter`)
- Custom scripts or non-standard flags
- Environment-specific requirements
- CI-specific commands

**Don't document (Claude can infer):**
- Standard commands like `npm install`
- Obvious conventions
- Commands already in `package.json`

---

## 4. Anti-Patterns to Avoid

### The Kitchen Sink Problem

**Don't:** Stuff everything into CLAUDE.md
**Do:** Keep it under 300 lines, move details to referenced files

### Outdated Instructions

**Don't:** Include information that changes frequently
**Do:** Link to external documentation, use file references

### Conflicting Rules

**Don't:** Include multiple instructions that contradict
**Do:** Prioritize, remove duplicates, consolidate

### Vague Guidelines

**Don't:** Use phrases like "write clean code" or "be careful"
**Do:** Be specific: "Use single quotes, 80 char line length"

### Excessive Length

**Don't:** Create files with 500+ lines
**Do:** Ruthlessly prune — if removing a line wouldn't cause mistakes, cut it

---

## 5. Length and Density Research

### Research Findings

- **Frontier LLMs can follow ~150-200 instructions reliably**
- **Performance degrades uniformly as instruction count increases**
- **Claude Code's system prompt already contains ~50 instructions**
- **Target: Under 300 lines, ideally under 150**

### Optimal Token Budgets

| Component | Recommended Limit |
|-----------|------------------|
| CLAUDE.md total | < 2,000 tokens |
| Main file | < 20,000 tokens (10% of 200k context) |
| Skills total | < 20,000 tokens |

### File Size Targets by Project Type

| Project Type | Target Lines | Structure |
|--------------|--------------|-----------|
| Small | 50-100 | Single file |
| Medium | 100-200 | Single file + @refs |
| Large (monorepo) | 100-150 root | Hierarchical files |
| Enterprise | 100 root | Hierarchical + skills |

---

## 6. Context Management Strategies

### When to Use /clear

- Switching to unrelated tasks
- After major feature completion
- When experiencing slow responses
- After 2+ corrections on same issue

### Compaction Strategies

**Automatic:** Triggers at 95% context capacity
**Manual:** Use `/compact` with focus hints:
```
/compact Focus on the API changes
```

**Custom instructions in CLAUDE.md:**
```markdown
## Compact Instructions
When compacting, preserve modified files and test status.
```

### Subagents for Investigation

Delegate research to keep main context clean:
```
Use subagents to investigate X
```

---

## 7. Cross-Tool Compatibility

### AGENTS.md vs CLAUDE.md

| Tool | AGENTS.md | CLAUDE.md |
|------|-----------|-----------|
| Claude Code | Via symlink | Native |
| OpenAI Codex | Native | Via fallback |
| GitHub Copilot | Native | Native |
| Cursor | Native | Via .cursorrules |
| Zed | Native | Native |

### Recommended Strategy

For maximum compatibility:
1. Create `AGENTS.md` as primary (broader tool support)
2. Symlink to `CLAUDE.md` for Claude Code: `ln -s AGENTS.md CLAUDE.md`
3. Keep content tool-agnostic
4. Use wrapper files for tool-specific features

---

## 8. Security Considerations

### Critical Security Rules

1. **Never include secrets in CLAUDE.md**
2. **Deny access to .env files:**
   ```json
   {
     "permissions": {
       "deny": ["Read(**/.env*)"]
     }
   }
   ```
3. **Use allowlists over blocklists for commands**
4. **Enable sandboxing for production**

### Safe Command Patterns

- Deny: `sudo`, `rm -rf`, `curl`, `wget`
- Allow: `npm run *`, `git status`, `git commit *`

---

## 9. Real-World Examples Analysis

### Effective Patterns Observed

1. **Critical Rules First** — LerianStudio/ring uses "⛔ CRITICAL RULES (READ FIRST)"
2. **Skill References** — ChrisWiles showcase links to skills for deep context
3. **Specific Commands** — ModelContextProtocol uses exact commands: `uv run --frozen pytest`
4. **Anti-Patterns with Alternatives** — "NEVER use X, use Y instead"

### Size Examples

- **HumanLayer**: <60 lines
- **Small projects**: 50-100 lines
- **Medium projects**: 100-200 lines
- **Large projects**: Root 100-150 + hierarchical files

---

## 10. Maintenance Best Practices

### Continuous Improvement

- Add instructions when Claude makes mistakes
- Use `#` key to add to CLAUDE.md quickly
- Document friction points as they occur

### Periodic Review

| Frequency | Action |
|-----------|--------|
| Weekly | Quick accuracy check |
| Monthly | Prune outdated instructions |
| Quarterly | Comprehensive review |

### Team Collaboration

- Commit CLAUDE.md to git
- Review changes in PRs
- Use `@claude` mentions on PRs to update rules
- Treat it as a living document

---

## 11. Complete Template

```markdown
# CLAUDE.md

## Workflow Rules
- **ALWAYS** [universal rule 1]
- **NEVER** [universal rule 2]

## Project Overview
[One-sentence description]

**Tech Stack:**
- Framework, language, versions

## Common Commands
```bash
# Essential command
command --flag

# Another essential command
command --flag
```

## Architecture
### Project Structure
```
lib/
├── folder/    # Description
└── file.dart  # Purpose
```

### Key Patterns
- Pattern 1: Description
- Pattern 2: Description

## Coding Conventions
- Convention 1
- Convention 2

## Testing
- Test command: `command`
- Test file location: `path/`

## Additional Documentation
- Detailed architecture: @docs/architecture.md
- Testing patterns: @docs/testing.md
```

---

## Summary Checklist

- [ ] Under 300 lines (ideally under 150)
- [ ] Every line prevents mistakes
- [ ] Uses progressive disclosure with @imports
- [ ] Commands are specific and copy-paste ready
- [ ] Emphasis used sparingly at beginning of instructions
- [ ] No secrets or credentials
- [ ] No obvious conventions Claude already knows
- [ ] Committed to version control
- [ ] Team-reviewed and maintained

---

*Generated with Claude Code — Research synthesis from 20 specialized agents*
