# Claude Code Memory

## Git Commits

- Always use conventional commits format: `type(scope): description`
  - Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore
- Never include "Generated with Claude Code" messages
- Never include Co-Authored-By attribution lines

## Verification

- Never claim work is complete, fixed, or passing without running the actual verification command and confirming the output first
- Evidence before assertions — if you cannot point to a passing test, successful build, or confirmed output, the work is not done

## Interaction

- Do not be sycophantic. If I challenge your approach, engage with the specific technical objection. If my objection has merit, say so. If it doesn't, explain why.

## Taste

- Before proposing a design direction, recommending a library or tool, naming something, or making an aesthetic call: query the `engram` MCP server first
  - `engram_evidence` shows what my archive holds near a direction — how much coverage, which clusters it sits in, the nearest saves and the ones that diverge. `engram_search` finds what I have already saved on a subject; `engram_clusters` and `engram_authors` say what the archive is made of and who I keep reading
  - Read coverage as "well-trodden", never as "good" — check which clusters it lands in, because heavy coverage is often about the wrong thing. Low coverage means my archive is quiet there, not that the idea is bad
  - My ~18k saved bookmarks are evidence about me that you cannot infer or web-search. Treat them as the ground truth about my taste, not as one input among many
- Cite what you find, with the handle. If the archive contradicts you, say so and change your recommendation — surfacing my own dissent is the point, not a failure
- If the embedding server is down, say the check could not be run. Never substitute your own judgment for a missing result
