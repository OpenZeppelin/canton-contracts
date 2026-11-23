# Guidelines

The single source of truth for coding conventions in this repository. It serves humans and AI
agents alike: contributors follow it by hand, and every review tool reads it instead of
restating the rules.

> Scope: **how** we write Daml in this repo: naming, layout, idioms, testing, documentation.
> For **why** the library is shaped the way it is (design decisions, package boundaries,
> dependency rules), see [`ARCHITECTURE.md`](ARCHITECTURE.md). For the commands, the
> coverage gate, and the pull request conventions, see [`CONTRIBUTING.md`](CONTRIBUTING.md).

These conventions target the toolchain listed under
[`README.md` Requirements](README.md#requirements). Where this file is silent, follow the
[Daml language reference](https://docs.canton.network/appdev/reference/daml-language-reference)
and the style of the Daml standard library.

Each rule is one line or one short paragraph, so a reviewer can check it on its own. A rule
that needs a reason gives it in the next sentence.

## Naming

### Packages and modules

[`ARCHITECTURE.md`](ARCHITECTURE.md#package-and-module-names) gives the reasons for these names.

| Package | Holds | Modules under |
|---|---|---|
| `openzeppelin-api-<component>-vN` | Frozen interfaces and their view types | `OpenZeppelin.Api.<Component>VN` |
| `openzeppelin-<component>-vN` | Templates and the types they store | `OpenZeppelin.<Component>VN` |
| `openzeppelin-<component>-types-vN` | Records that the utils functions read and the templates store | `OpenZeppelin.<Component>.TypesVN` |
| `openzeppelin-<component>-utils` | Functions, failure statuses, and choice bodies | `OpenZeppelin.<Component>.Utils` |

- Every package name except a utils package ends in `-vN`, the package's own generation.
- A component that implements a named standard carries the standard as a second segment of its
  name: `openzeppelin-token-cip112-v1` under `OpenZeppelin.Token.Cip112.V1`. Each segment of
  the component name is one segment of the module namespace.
- A category directory under `packages/` or `experiments/` never appears in a package name or a
  module namespace.
- A compatible release keeps the package name and raises the `version` in `daml.yaml`. A
  breaking change is a sibling package with the next `-vN` suffix and the next `VN` module
  suffix. A utils package keeps its name and raises its semver major version.
- A module that is not public API is named `<Module>.Internal`.
- A template is named for the component's domain term, and the name does not change across
  versions: `AuthorizationGrant`, `RoleGrant`.

### Code

- Modules, templates, interfaces, data types, type classes, and constructors are `PascalCase`.
  Fields, functions, and local bindings are `camelCase`. Nothing is `SCREAMING_SNAKE_CASE`.
- A choice is `<Template>_<Action>`: `Vault_Withdraw`, `TokenRules_OfferMint`. An interface
  choice is `<Interface>_<Action>`: `Timelock_Apply`.
- An interface method that a choice body calls is `<action>Impl`: `applyImpl`. A method of an
  upstream interface keeps its upstream name: `settlementFactory_settleBatchImpl`.
- An interface view type is `<Interface>View`: `TimelockView`.
- A predicate returns `Bool` and is `is<Property>`: `isPaused`, `isValidConfig`, `isReadyAt`.
- A guard fails unless a condition holds. It is `require<Condition>`: `requireReady`,
  `requireValidConfig`. A guard on a flag is `when<State>`: `whenNotPaused`.
- A check that returns `Either FailureStatus a` instead of failing is `check<Condition>`. Its
  failing form is the matching `require<Condition>`.
- A `FailureStatus` constant is `e<Condition>`: `eEnforcedPause`, `eNotReady`. A failure that
  carries data is a function named for the condition: `authorityMismatch expected actual`.
- An `errorId` is the provider's DNS name, a slash, and one lowercase hyphenated name that
  starts with the component: `openzeppelin.com/pausable-enforced-pause`. It never changes after
  a release, because clients match on it.
- A party field or argument is named for its role: `admin`, `owner`, `holder`, `authority`,
  `grantee`. Never `user` or `party`.
- A binding that holds a `ContractId` ends in `Cid`: `grantCid`, `instructionCids`.
- A test is `test_<behavior>`, in `camelCase` after the prefix:
  `test_whenNotPausedGuardsOperation`. The name states the behavior. When it names both the
  subject and the condition, an underscore separates them:
  `test_transfer_cannotUseLockedHoldings`.
- A test package is the tested package's name plus `-test`. Its modules sit under
  `<Root>.Test`, where `<Root>` is the tested package's module root, with one module per suite
  under `<Root>.Test.<Suite>`. Fixture templates live in `<Root>.Test.Fixtures`.

## Layout and section ordering

A source file, top to bottom:

1. The license header, only in a file that contains third-party code: the copyright lines,
   the `SPDX-License-Identifier` line, and one line that names the source.
2. The module doc comment (`-- |`).
3. The `module` line. A public module either lists its exports or exports everything. Helpers
   that are not API go in the `.Internal` module, not behind an export list alone.
4. Imports.
5. Data types, type synonyms, and view types.
6. Interfaces and templates.
7. Functions: the public ones first, then the helpers they call.
8. `FailureStatus` constants, when the module defines them.

Separate groups of definitions with a section comment: a `-- Title` line followed by a line
of dashes.

Inside a template, in this order: the fields under `with`, then under `where` the
`signatory`, `observer`, and `ensure` clauses, the interface instances, and the choices.
Order the choices by the lifecycle of the contract.

Inside a choice, in this order: the header, its `-- ^` doc comment, the arguments under
`with`, `observer`, `controller`, and `do`.

Indent by two spaces. Fields under `with` and clauses under `where` sit four spaces in:

```daml
template Vault
  with
    admin : Party
    holder : Party
  where
    signatory admin
    observer holder
```

## Imports

- Group imports in this order, with one blank line between groups: the Daml standard library
  (`DA.*`, and `Daml.Script` in a test), third-party packages (`Splice.*`), then
  `OpenZeppelin.*`.
- Name what you take from the standard library: `import DA.Action (unless, when)`.
- Write a qualified import as `import DA.Map qualified as Map`.
- Import an upstream interface module qualified under its own name:
  `import Splice.Api.Token.HoldingV2 qualified as HoldingV2`. The generation then shows at
  each use.
- `Daml.Script` is imported in test packages only.

## Types

- Declare a record as `data X = X with`, one field per line. Derive `(Eq, Show)`.
- A record with rules its fields must satisfy has an `isValid<Type>` predicate, and every
  template that stores the record calls the predicate in `ensure`:
  `ensure isValidRegistryConfig config`.
- Type a `ContractId` argument as narrowly as the choice allows. Use the template's
  `ContractId` when the choice handles only its own template. Use an interface `ContractId`
  only when the choice is meant to accept other implementations.

## Functions and errors

- Every top-level function has a type signature. Every public one has a doc comment.
- `ensure` holds every rule the template's fields must satisfy. The signatories can create the
  template directly, without any choice, so a rule that only a choice or a constructor
  function checks does not hold for every contract.
- Every failure a consumer can reach carries an `errorId`. Raise it with `failWithStatus` and
  a named `FailureStatus`, or with a standard library function that does the same, such as
  `assertWithinDeadline`. `assertMsg`, `error`, `abort`, and `fail` carry no `errorId`, so use
  them only for a state that cannot be reached.
- Build every `FailureStatus` of a component with one helper in its `.Internal` module, so the
  `errorId` prefix is written once:

  ```daml
  pausableFailure : Text -> FailureCategory -> Text -> FailureStatus
  pausableFailure name category message = FailureStatus with
    errorId = "openzeppelin.com/pausable-" <> name
    category
    message
    meta = TextMap.empty
  ```

- Choose the `FailureCategory` by whether a retry can succeed.
  `InvalidGivenCurrentSystemStateOther` is for a failure that a later state can clear.
  `InvalidIndependentOfSystemState` is for an input that can never succeed.
- A `message` is one plain English sentence for a developer:
  `"Cannot withdraw a committed allocation before its settlement deadline."` The `errorId`
  names the component, so the message does not repeat it.
- Do not define exceptions, and do not use `try` and `catch`. Do not write an `agreement`
  clause. Do not use contract keys. Enforce "at most one" with a check at creation.

## Idioms and patterns

Each pattern below is one the library standardises on, with the form it replaces.

**A guard reads the contract being exercised.** A caller can substitute or omit a contract it
supplies, so a guard that fetches a separate switch contract is not sound.

```daml
-- No: the caller chooses which `PauseState` to pass.
choice Vault_Withdraw : ContractId Vault
  with pauseCid : ContractId PauseState
  controller holder
  do
    pause <- fetch pauseCid
    when pause.paused (failWithStatus eEnforcedPause)

-- Yes: the flag is a field of the contract the choice runs on.
choice Vault_Withdraw : ContractId Vault
  controller holder
  do
    whenNotPaused this
```

**A fetched credential proves nothing until its fields are checked.** Check every field of a
contract the caller supplies against state the choice already trusts, and make the acting
party a controller.

```daml
-- No: any `PauseCredential` passes.
cred <- fetch credCid

-- Yes: the issuer and the holder are both bound.
cred <- fetch credCid
unless (cred.admin == admin) (failWithStatus eWrongCredentialIssuer)
unless (cred.account == caller) (failWithStatus eCredentialNotCallers)
```

**Pin a caller-supplied interface contract to its template before exercising it.** An
interface exercise runs the code of whatever template implements the interface, with the
authority of the party exercising. A check on the contract's view does not help, because the
foreign template writes its own view.

```daml
-- No: runs any implementation of `Allocation` with the admin's authority.
exercise allocationCid Allocation_Cancel with ..

-- Yes: `pinAllocationTo @TokenAllocation` fails unless the contract is a `TokenAllocation`.
expireAllocationsImpl (pinAllocationTo @TokenAllocation) config.admin cancelArgs
```

**Derive, do not accept.** Derive observers, controllers, and expected values from the fields
of the contract. A value the caller passes as a choice argument is the caller's claim.

**A long-lived entry-point contract has nonconsuming choices.** Concurrent workflows then do
not contend on it. Consumers obtain it by explicit disclosure.

**A choice that changes a field is consuming.** It creates the successor with
`create this with ...`, and the predecessor is archived. A `nonconsuming` choice that creates
a successor must call `archive self`, or both contracts stay active.

## Testing

Tests are written not only to verify the correctness of the target code but to be
comprehensively reviewed by other programmers. For code that secures value, the quality of the
tests matters as much as the code itself, and they are held to the same standards of clarity.
Every addition or change to the code comes with relevant and comprehensive tests. Unit tests
are mandatory for every new feature; whether a change also needs an integration test is
decided in review. When unsure, open the PR and ask. The coverage gate itself is set in
[`CONTRIBUTING.md`](CONTRIBUTING.md#code-quality-standards).

Layout:

- Tests live in an isolated `-test` package under `test/`, `experiments/test/`, or beside an
  example as `examples/<example>-test`. The package has version `0.0.0`, depends on
  `daml-script`, and data-depends on the production DAR. `scripts/check.sh` enforces this.
- Tests import the compiled DAR, so they cross the same package boundary an integrator does.
- One top-level `Script ()` per behavior. Its `-- |` comment states the behavior in one
  sentence.
- A `setup : Script Fixture` function allocates the parties and creates the starting
  contracts. It returns them in a record that each test opens with `Fixture{..} <- setup`.
- Allocate every party with `allocateParty`. Never write a party ID by hand.

What each choice and function needs:

- The path that succeeds, with an assertion on the resulting contract or balance.
- One test for each `FailureStatus` it can raise.
- One test for each party that must not be able to exercise it.
- The boundaries: just before, at, and just after each deadline; zero and the smallest
  amount; an empty list where a list is an argument.
- For a template, a create that breaks each `ensure` rule.
- For a privacy claim, an assertion on what a party that is not a stakeholder gets back from
  `query`.

How to assert a failure:

- A `FailureStatus`: use `trySubmit` and compare the whole status with the constant, as
  `submitMustFailWith eEnforcedPause $ trySubmit holder do ...` does. A test that passes on any
  failure covers nothing.
- A missing authority: match `AuthorizationError`, as `submitMustFailAuthorization` does.
- Use a bare `submitMustFail` only for a failure that is neither, such as an `ensure`
  violation.

Authority:

- Submit as exactly the party the choice names as controller. A test that submits with every
  party's authority at once does not test the authorization.
- Give a submitting party read access with `readAs` or an explicit disclosure, never by adding
  it to `actAs`.

Other rules:

- Do not compare a `ContractId` across a consuming choice. Query the successor.
- Tests that need the Ledger API run in the sandbox suites of `scripts/check-sandbox.sh`, on a
  static-time ledger.
- A fixture template that exists only to show a defect says so in one sentence of its doc
  comment.

## Linting and formatting

The commands are listed once, in
[`CONTRIBUTING.md`](CONTRIBUTING.md#a-typical-workflow).

- `dpm damlc lint` reports nothing for every package, test and example packages included.
- Fix a lint hint. Do not suppress it.
- A `-Wno-...` build option is allowed only in these two cases, and adding a third is a review
  decision: `-Wno-template-interface-depends-on-daml-script` in a test package, and
  `-Wno-template-has-new-interface-instance` in a package that adds an interface instance
  through SCU.
- CI checks spelling with `typos`.
- There is no formatter. Keep code and comments within 100 columns.
- Use repository-relative paths in code, documentation, and configuration. Never write a
  username, a home directory, or another machine-specific path.

## Documentation

`dpm damlc docs` renders the API reference from the doc comments. The command is in
[`CONTRIBUTING.md`](CONTRIBUTING.md#api-documentation). Run it after changing a doc comment and
read the output.

### Doc comments

Write what the generator cannot derive, and write it in the affirmative: what the symbol is,
what it does, and what the consumer does with it. A comment lists nothing that the symbol
lacks or cannot do. The exception is a test fixture whose purpose is a defect; it gets one
sentence naming the defect.

- `-- |` goes above a module, template, interface, data type, or function. `-- ^` goes after
  a choice header, a field, or an interface method. A `-- |` above a `choice` or an interface
  method is a parse error, and the module then renders nothing.
- A template, interface, data type, or field comment is one sentence. A template comment adds
  one sentence per `ensure` rule, in words, because an `ensure` failure carries no `errorId`.
- A choice comment states, each once: what the choice does for the caller; the choice kind,
  only when the body archives and recreates the contract under a `nonconsuming` header; any
  authority the body checks beyond the controller; and each `FailureStatus` by constant name
  and `errorId`, with the condition that raises it.
- A `FailureStatus` constant's comment states the condition it reports and its `errorId`. It
  names no choice or function that raises it, because that list goes stale.
- A function comment states what the function does and what it fails with, in one sentence
  each. It covers that function only. It does not repeat the body, describe what callers do
  with the result, or carry a rule for a party other than the caller.
- The module comment describes the model: where the state lives, what the consumer writes, and
  how the consumer changes the state. Two to four short paragraphs and at most one code
  example. It has no symbol table and no sentence that a symbol's own comment repeats.
- Open a function or choice comment with a verb sentence: "Move `amount` out of the vault."
  Open the comment of a function that implements an interface method with
  "Implementation for `Allocation.allocation_cancelImpl`." Open a template, type, field,
  predicate, view, constant, or module comment with a noun phrase that says what it is. Text
  copied from a vendored package keeps its upstream wording.
- At most one code example per symbol, in a fenced block inside the comment, and only where
  the call is not obvious from the signature.

### Comments inside code

A `--` comment inside a function or choice body says only what the code cannot show: why it
takes its approach over the obvious one, an outside constraint, or where a limitation is
explained. The same holds for a comment in a script or a configuration file. Delete a comment
that says what the next lines do.

### One home for each fact

| Content | Lives in |
|---|---|
| Signatures, fields, arguments, signatories, controllers, return types, interface instances | The output of `dpm damlc docs` |
| Standard Daml and Canton semantics: what a consuming choice archives, who a controller is | Nowhere. The reader knows Daml. |
| What one symbol does, what it fails with, and the trust boundary, security limitation, or operational assumption it carries | That symbol's doc comment |
| The model, what the consumer writes, and caveats about the package as a whole | The header comment of the public module |
| Adoption, build, dependency, signatory rationale, disclosure, upgrade assumptions, and the package-wide caveats of a package with several public modules, none of which leads | The package `README.md` |
| Design decisions, trade-offs, rejected alternatives | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| Release and versioning policy | [`RELEASING.md`](RELEASING.md) |
| User-visible changes to released packages and their public APIs | `CHANGELOG.md` |
| Commands, coverage, CI | [`CONTRIBUTING.md`](CONTRIBUTING.md) |

A fact appears in its home and nowhere else. A second mention names the symbol that holds it:
"the same caution as `pause` applies". The exception is an `errorId`. It appears on its
constant and in the comment of each choice that raises it, because a client matches on it.

A trust boundary, security limitation, or operational assumption is stated once, in the doc
comment of the component it belongs to. State what the caller must do in one imperative
sentence, and what goes wrong otherwise in one more: "Check that the lock has expired before
acting on `False`. Otherwise the contract ends while its holdings stay locked." No CAUTION,
WARNING, or NOTE block, and no second copy.

Every production template or interface documents what it adds to signatories, observers,
controllers, choices, disclosure, authorization assumptions, archival behavior, failure modes,
and upgrade assumptions. Document only what the component defines or changes, and omit a topic
where it adds nothing.

### Wording

- Present tense, current behavior. No history and no design narration: not "deliberately",
  "we chose", "now", "previously", "no longer". No removed content, earlier layouts, rejected
  alternatives, milestones, review context, or planned work.
- No audit finding ID such as `L-05`, and no issue or PR number, outside `CHANGELOG.md`.
- Affirmative framing. Say what a symbol does. Do not say what it declares no, names no,
  cannot, or does not check.
- Describe what the package does, not what it derives from. No "analogue", "modelled on",
  "counterpart", and no comparison with another language's library or another chain.
- Use Daml vocabulary: template, choice, controller, signatory, observer, interface instance,
  view, `FailureStatus`.
- One condition per sentence. Name what happens: "ends the contract without touching its
  locked holdings", not "skips the funding".
- Delete any sentence or word whose removal loses nothing: "saturating at `maxTime`", not
  "saturating at `maxTime` instead of overflowing".
- State a computed value by its field and expression: "`expiresAt` is `requestedAt + maxTTL`",
  not "expires `maxTTL` after `requestedAt`".
- Compare against a named bound, written the same way each time: "a deadline later than
  `requestedAt + maxTTL`", not "a deadline later than that".
- When code calls, matches, or reproduces third-party code, its comment links to the source: a
  permalink pinned to a commit, never a branch, and to the exact lines, never a whole file.
- No test names in a `README.md`, a guide, or a doc comment. A test comment may name the test
  that covers the other half of a behavior.
- When you edit a comment, it keeps its length or shrinks unless the edit adds a missing fact.
  Fix a wrong sentence by cutting the wrong part. Every sentence kept in an edited comment
  meets these rules.
- No attribution to a tool or a model anywhere.
- Refer to a repository file by its exact filename, with the extension, in backticks.

### README files

- The root `README.md` is the consumer landing page: the production packages, their purpose,
  how to build and consume them, their compatibility model, and security guidance. Contributor
  instructions belong in `CONTRIBUTING.md`.
- A package `README.md` has these sections, in this order, and omits one only when the package
  has nothing to say under it: "What it provides", "Usage", "Authority and lifecycle",
  "Compatibility", "Build", "Security caveats", "Consume a local build".
- A reader adopts the package from its `README.md` alone. For an interface package that means
  the field, the interface instance, the guard, and the choice they write. For a template
  package it means the create and the sequence of choices.
- A package that implements a named standard names the standard in its `README.md`.
- Every code block in a `README.md`, a guide, or a comment mirrors code that `dpm build`
  compiles in an example or test package.
- `CHANGELOG.md` holds only user-visible changes to released production packages and their
  public APIs. It excludes repository organization, CI, tests, tooling, and
  documentation-only changes.
