# Skills Monorepo

This repository contains a collection of specialized skills for Gemini CLI, reflecting the engineering standards and patterns of a Senior Software Engineer.

## Repository Structure

- `code-standards/`: Foundational coding standards, mandatory SOLID principles, and architectural pattern strategy.
- `react-code-standards/`: High-quality React and TypeScript patterns, hook ordering, and predictable state.
- `typescript-standards/`: TypeScript-specific best practices and patterns.
- `slot-based-layout/`: Architectural pattern for frontend UI composition using Layouts and Slots (React/Vue).
- `critical-thinking/`: Intellectual mindset for engineering, prioritizing accuracy and architectural integrity.

## How to Install

The easiest way to install these skills is using the `skills` utility:

```bash
npx skills add usermeme/skills
```

Alternatively, you can install them manually:

1.  Package the skill: `node path/to/package_skill.cjs <skill-folder>`
2.  Install: `gemini skills install <packaged-skill>.skill --scope user`
3.  Reload: `/skills reload` in your Gemini CLI session.
