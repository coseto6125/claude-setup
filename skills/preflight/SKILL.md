---
name: preflight
description: Six design questions to answer in one line each before a new module or feature. User-invoked.
disable-model-invocation: true
---

# Preflight

Before the first edit, answer each question in one line that names the file, symbol or number you checked. Write the six lines in the plan or the scratchpad. "Nothing changes" is a valid answer. Depth follows the risk of the change. Add design only when the requirement or the evidence asks for it.

1. **Requirement.** What does the request ask, what does the existing behaviour do, and which edge cases and data semantics decide correctness?
2. **Architecture and reuse.** What in the repo already does part of this, where does the concept live, and which interface serves every caller? Query with `ecp find` and `ecp impact --direction upstream`. Interface shape: `codebase-design`.
3. **Simplicity.** What is the simplest implementation that meets the request today, and is it simpler than what was asked?
4. **Performance.** What is the input scale, the theoretical minimum complexity, and which step disappears outright? Python recipes: `python-perf`.
5. **Security and reliability.** Where does untrusted input enter, who may trigger this, what fails, and what runs concurrently? Authority decisions: `authority-check`.
6. **Verification and delivery.** Which test goes red if this is wrong, and which callers, configs or deployments move with it?

Implement against the six lines. Before you report, check the diff against them.
