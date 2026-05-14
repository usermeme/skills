# Skills Monorepo

This repository contains a collection of specialized skills for Gemini CLI, reflecting the engineering standards and patterns of a Senior Software Engineer.

## Repository Structure

- `code-standards/`: Foundational coding standards, mandatory SOLID principles, and architectural pattern strategy.
- `typescript-standards/`: TypeScript-specific best practices and patterns.
- `slot-based-layout/`: Architectural pattern for frontend UI composition using Layouts and Slots (React/Vue).

## How to Install

To install a skill from this repository:

1.  Package the skill: `node path/to/package_skill.cjs <skill-folder>`
2.  Install: `gemini skills install <packaged-skill>.skill --scope user`
3.  Reload: `/skills reload` in your Gemini CLI session.
