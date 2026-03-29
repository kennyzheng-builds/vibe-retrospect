# Vibe Retrospect

A dual-purpose Claude Code skill for vibe coding knowledge transfer.

**Mode 1 — Retrospect**: Analyze a completed vibe coding project (codebase + git history + Claude Code session logs) and generate a human-readable HTML article + a structured knowledge document for agents.

**Mode 2 — Learn**: Import someone else's knowledge document, and the skill configures your CLAUDE.md with teaching rules and project references so your agent can coach you through building a similar project step by step.

## The Problem

When you vibe code a project — all the decisions, pitfalls, debugging sessions, and methodology — that experience lives in your head and in scattered conversation logs. It's hard to share, and it's gone when the session ends.

Meanwhile, someone who wants to build something similar has to start from scratch, making the same mistakes you already solved.

**Vibe Retrospect bridges this gap**: the builder extracts their experience into a portable format, and the learner's agent absorbs it to provide guided coaching.

## How It Works

```
Builder (User A)                          Learner (User B)
─────────────────                         ─────────────────
Finished a project                        Wants to build something similar
      │                                         │
      ▼                                         ▼
Says "retrospect" or "复盘"               Says "I want to learn from this project"
      │                                         │
      ▼                                         ▼
Skill analyzes:                           Skill asks for knowledge doc
  - Codebase + configs                          │
  - Git history (80 commits)                    ▼
  - Claude Code session logs              Parses the knowledge doc
  - CLAUDE.md rules                             │
  - docs/ and memory files                      ▼
      │                                   Configures user's environment:
      ▼                                     - CLAUDE.md (teaching rules + references)
Generates TWO outputs:                      - docs/reference/ (knowledge doc)
  1. {project}-story.html (for humans)      - docs/status.md (progress tracker)
  2. {project}-knowledge.md (for agents)          │
      │                                         ▼
      ▼                                   User starts building with their agent
Shares knowledge.md with User B           Agent coaches step by step
```

## Install

### Via curl

```bash
curl -sL https://raw.githubusercontent.com/kennyzheng-builds/vibe-retrospect/main/SKILL.md -o ~/.claude/skills/vibe-retrospect/SKILL.md
mkdir -p ~/.claude/skills/vibe-retrospect/scripts
curl -sL https://raw.githubusercontent.com/kennyzheng-builds/vibe-retrospect/main/scripts/parse-sessions.sh -o ~/.claude/skills/vibe-retrospect/scripts/parse-sessions.sh
chmod +x ~/.claude/skills/vibe-retrospect/scripts/parse-sessions.sh
```

### Via Agent

Tell your Claude Code agent:

```
Install the vibe-retrospect skill from https://github.com/kennyzheng-builds/vibe-retrospect.
Download SKILL.md to ~/.claude/skills/vibe-retrospect/SKILL.md
and scripts/parse-sessions.sh to ~/.claude/skills/vibe-retrospect/scripts/parse-sessions.sh
```

## Usage

### Mode 1: Retrospect (Builder)

In your project directory, say any of these to your agent:

- "复盘"
- "retrospect"
- "review my project"
- "总结开发经验"
- "打包我的开发经验"
- "write up how I built this"

The skill will:
1. Silently scan your codebase, git history, Claude Code session logs, and docs
2. Ask you a few questions to fill gaps (origin story, key moments, advice for others)
3. Generate two files in `./outputs/`:
   - **`{project}-story.html`** — Self-contained HTML article for humans
   - **`{project}-knowledge.md`** — Structured knowledge document for agents

Share the `knowledge.md` with anyone who wants to learn from your experience.

### Mode 2: Learn (Learner)

With the skill installed, say:

- "I want to learn from this project"
- "我想学做这个项目"
- "帮我学习这个项目"
- "coach me through building this"

The skill will:
1. Ask for the reference project's `knowledge.md` file
2. Ask about your experience level and goals
3. Configure your project:
   - Create/modify `CLAUDE.md` with teaching rules (discuss before coding, explain every step, stage checks)
   - Store the knowledge doc in `docs/reference/`
   - Set up progress tracking (`docs/status.md`, `docs/tasks/`)
4. Tell you the first prompt to send to start building

From that point on, your agent uses the CLAUDE.md rules and reference material to guide you step by step.

## What's in a Knowledge Document?

The generated `{project}-knowledge.md` follows a standard schema:

| Section | What it contains |
|---|---|
| Quick Facts | Timeline, commits, tech stack, cost, repo URL |
| The Problem | What pain point the project solves, origin story |
| Key Decisions | Each major decision with context, options, and reasoning |
| Architecture | Tech stack table, system design diagram, data model, API routes |
| Development Timeline | Day-by-day milestones with commit counts |
| How Builder & AI Collaborated | CLAUDE.md rules, workflow patterns, direct feedback quotes |
| Pitfalls & Solutions | Each pitfall with symptom, root cause, fix, and prevention |
| Build Guide | Prerequisites, recommended build order, CLAUDE.md template |
| Lessons Learned | On product, on vibe coding, on technical choices |

Direct quotes from session logs are included wherever possible — they capture the authentic reasoning behind decisions.

## Data Sources (Retrospect Mode)

The skill analyzes these sources, in priority order:

1. **Claude Code session logs** (`~/.claude/projects/{path}/*.jsonl`) — The real gold. Contains every user decision, feedback, and debugging session. Shows WHY, not just WHAT.
2. **CLAUDE.md** — Project rules and collaboration norms
3. **docs/** — Specs, decisions, status, tasks
4. **Git history** — Timeline, commit messages, most-changed files, peak days
5. **Codebase** — Config files, main source, deployment scripts
6. **GitHub** — PRs and issues (if remote exists)

Session logs are prioritized over git history because git shows what changed, but session logs show why.

## Example

See [`examples/agentslink-knowledge.md`](examples/agentslink-knowledge.md) for a real knowledge document generated from the [AgentsLink](https://github.com/kennyzheng-builds/agentslink) project — an Agent-to-Agent collaboration service built in 11 days with 80 commits.

## File Structure

```
vibe-retrospect/
  SKILL.md                          # The skill definition (install this)
  scripts/
    parse-sessions.sh               # Session log parser (extracts user messages, decisions, feedback)
  examples/
    agentslink-knowledge.md         # Real example output
  README.md                         # This file
```

## Language

The skill matches the user's language. If you speak Chinese, all generated content will be in Chinese. If English, English.

## License

MIT
