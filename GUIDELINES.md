<!-- The sections below are what a typical
     library needs, not a fixed list — drop any that do not apply to this ecosystem, and add a
     section for anything it has that is not covered here. Fill each section with the actual
     conventions and delete the TODO lines. Rules live here and nowhere else — CONTRIBUTING.md,
     AGENTS.md, the code-quality skill and the AI review configs point at this file instead of
     restating it. Delete this comment when done. -->

# Guidelines

The single source of truth for coding conventions in this repository. It serves humans and AI
agents alike: contributors follow it by hand, and every review tool reads it instead of
restating the rules.

> Scope: **how** we write Daml in this repo: naming, layout, idioms, testing, documentation.
> For **why** the library is shaped the way it is (design decisions, package layout and
> naming, dependency rules), see [`ARCHITECTURE.md`](ARCHITECTURE.md).

These conventions target the toolchain listed under
[`README.md` Requirements](README.md#requirements). Where this file is silent, follow the
[Daml language reference](https://docs.canton.network/appdev/reference/daml-language-reference)
and the style of the Daml standard library.

## Naming

<!-- TODO: casing per kind (modules, types, functions, constants, error codes), prefixes and
     suffixes the ecosystem expects, what to name test files and test functions. -->

## Layout and section ordering

<!-- TODO: how a source file is organised top to bottom (header, imports, constants, errors,
     types, constructors, public API, internal helpers, tests), one rule per line, so a reviewer
     can check ordering mechanically. -->

## Imports

<!-- TODO: what to import explicitly vs. rely on implicitly, grouping and ordering, aliasing
     rules. -->

## Types

<!-- TODO: how public types are declared and exposed, visibility and abilities/traits, when to
     wrap vs. expose primitives, invariants a type must guarantee by construction. -->

## Functions and errors

<!-- TODO: visibility rules, argument ordering, return conventions, how errors are declared and
     numbered, when to abort vs. return, what every public entry point must validate. -->

## Idioms and patterns

<!-- TODO: the ecosystem-specific patterns this library standardises on and the anti-patterns it
     forbids — with a short before/after example for each. -->

## Testing

Tests are written not only to verify the correctness of the target code but to be
comprehensively reviewed by other programmers. For code that secures value, the quality of the
tests matters as much as the code itself, and they are held to the same standards of clarity.
Every addition or change to the code comes with relevant and comprehensive tests. Unit tests
are mandatory for every new feature; whether a change also needs an integration test is
decided in review — when unsure, open the PR and ask. The coverage gate itself is set in
[`CONTRIBUTING.md`](CONTRIBUTING.md#code-quality-standards).

<!-- TODO: test layout and naming, what every public function must have (happy path, each
     failure path, boundaries), how expected failures are asserted, and what belongs in unit
     vs. integration tests. -->

## Linting and formatting

<!-- TODO: the formatter and linter configuration and the settings that are non-negotiable, and
     the only acceptable way to suppress a lint (with a justification comment). The commands
     themselves are listed once, in CONTRIBUTING.md's workflow — link there, do not repeat them. -->

## Documentation

<!-- TODO: doc-comment format for modules, types and functions; what a public item's doc must
     contain (purpose, parameters, errors, examples); how generated docs are built and checked. -->