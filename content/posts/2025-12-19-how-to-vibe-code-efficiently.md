+++
title = "How To Vibe Code Efficiently"
description = "Using Codex in a proper way"
date = 2025-12-19

[taxonomies]
categories = ["Post"]
tags = ["C++", "Python"]

[extra]
toc = true
+++

Vibe coding is pairing with an LLM to ship code faster without losing clarity. It is a tool for completing tasks and a way to learn new
stacks as you go.

## What vibe coding can do

Vibe coding is not only about completing a ticket. It is also a way to study: a coder can quickly explore new frameworks or libraries,
and a researcher can dig into algorithms or math without getting stuck on boilerplate. With an open mindset, you expand your technical
boundaries, handle more work in parallel, and free yourself from repetitive tasks so you can focus on design and research.

## User guide

1. **Clarify a direction**

    Do one thing at a time so the model stays focused. In practice, ship one feature per branch.

2. **Master Git**

    Use branches for features, and revert early when the direction is wrong.

3. **Choose a simple tech stack**

    Fewer moving parts make it easier for the model to be accurate.

4. **Maintain instructions and docs**

    Record the steps you took; next time the model can start from that context without re-reading the whole codebase.

5. **Give good prompts**

    Be explicit about goals and constraints to save tokens and iterations.

6. **Manage chat context**

    Keep related work in the same thread so the model can reuse history.

7. **Ask for unit and integration tests**

    Safety nets keep the session honest.

8. **Debug in the right environment**

    Run and inspect code locally so the model can reason with real outputs.

## Use case

- Exploring a new library: ask the model for a minimal example, run it, then iterate with real errors and logs.
- Refactoring safely: outline the target shape, let the model draft changes, and enforce tests before merging.
- Research tasks: offload boilerplate data loading or plotting so you can focus on the math or model design.
