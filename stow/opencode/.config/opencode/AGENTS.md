# Skills

Installed agent skills encode tested methods for common tasks. When one matches the task, follow it rather than improvising.

To find the skills that match, run `skill-search <what you are about to do>` at the start of a task and before each step (plan, choose a library or design, build, test, debug, review, commit, ship, report): a few words, a topic, or a plain description of the task ("the tests pass locally but fail in CI"). It prints the best-matching skills with the path to each SKILL.md; read the ones that fit and follow them. `~/.agents/skill-search/INDEX.md` is the full map, filing every installed skill by the moment it helps with. Skills it marks "ask first" spawn agents, push, deploy or send to outside services: check with the user before following one.
