# SKILL: Explain file or section using repository context

Purpose
- Provide a reproducible agent workflow that, given a file path (or file + section), reads the repository context, locates related code, and produces a concise, actionable explanation targeted to developers.

When to use
- The user asks "explain this file" or "explain this function/section" and expects the explanation to consider the rest of the codebase (imports, providers, usages, tests).

Inputs
- `filePath` (required): workspace-relative path to the file to explain.
- `section` (optional): function/class name, line range, or textual excerpt to focus on.
- `depth` (optional): `quick` | `medium` | `thorough` — how many related files to scan.
- `goals` (optional): what the user wants (high-level summary, code links, refactor suggestions, tests to add).

Outputs
- A structured explanation including: Overview, Key Symbols, Data Flow/Dependencies, Where It's Used, Serialization/IO, Notable Patterns/Decisions, Potential Issues, Quick Fixes or Next Steps. Include file links when referencing files.

Step-by-step Process
1. Validate inputs: check `filePath` exists in workspace.
2. Read the target file fully.
3. Extract imports and exported symbols (classes, functions, providers, routes).
4. For `depth=quick`: gather direct imports + immediate callers (1 hop). For `medium`: include imports of imports and tests. For `thorough`: search repo for symbol names and collect call sites and providers.
5. Read the most relevant related files (limit to ~10 files for medium; configurable).
6. Analyze:
   - High-level intent and responsibilities of the file.
   - Main public API (classes, functions, providers) and types.
   - How data flows in and out (network, streams, DB, state management).
   - Lifecycle, side effects, and resource management.
   - Any TODOs, FIXMEs, or feature flags.
7. Produce explanation with code excerpts and file links.
8. If requested, produce suggested changes/patches and run tests or static analysis.

Decision points / branching logic
- If `filePath` missing → ask the user for a path.
- If `section` provided → focus analysis on that symbol; still gather context but prioritize.
- If file is a small widget or single-class file → provide concise explanation and references to providers/services.
- If the repo is large and `depth=thorough` → ask user if they want a slower deep scan (may take longer).

Quality criteria / completion checks
- File was read and the explanation references at least one related file or provider.
- All symbol names referenced are present in the repo and linked.
- Explanation contains actionable next steps or a short checklist (3 items max) for follow-up.

Example prompts (user-facing)
- "Explain `lib/models/navigation_state.dart` in the context of the whole repo, quick scan."
- "Explain the `OutdoorRoute` class in `lib/models/navigation_state.dart` and list where it's used."
- "Summarize `lib/providers/navigation_provider.dart` and suggest any lifecycle issues."

Agent iteration and interaction pattern
1. Validate target file exists. If not, prompt user to correct the path.
2. Run a quick scan (imports + top-level symbols) and return a short summary and list of files I'll read next. Ask for confirmation to continue for `depth=thorough`.
3. After user confirmation (if needed), perform the scan and produce the final explanation.
4. If the user asks for changes, propose a patch and offer to apply it.

Implementation notes for agent developer
- Use `grep_search` to find callsites for symbol names. Use `read_file` to fetch file contents. Limit file reads to conserve time.
- Always add `ref` or file links with workspace-relative paths when referencing files in the explanation.
- If producing patches, use `apply_patch` and then run `flutter analyze` / tests if requested.

Example output structure
- **Overview:** one-line summary
- **Key symbols:** bullet list of classes/functions with short descriptions
- **Data flow & dependencies:** where data comes from/where it goes
- **Where used:** short list of file links with lines
- **Lifecycle & side effects:** services started, network calls, streams
- **Potential issues & suggestions:** 2–4 focused items
- **Next steps (optional):** small checklist (run tests / patch / add logging)

Related skills to create next
- `create-explanation-tests`: auto-generate small unit or widget tests that validate the described behavior.
- `create-refactor-plan`: propose a minimal refactor for large, complex files.

---

This SKILL is intended for workspace-integrated agents that can read files, search the repository, and optionally apply patches. It is written to prioritize clarity, actionable advice, and linking to the codebase for verification.
