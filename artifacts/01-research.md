---
stage: research
project: pausable
mode: greenfield
extends: null
status: draft
timestamp: 2026-08-31
author: nenad.misic@openzeppelin.com
previous_stage: null
tags: [pausable, emergency-stop, access-control, cip-0112, token-standard, disclosure, canonical-instance]
---

# Pausable - Research Report

## Summary

Canton has no on-ledger pausable component, and no CIP proposes one. CIP-0112
standardizes how a registry *reports* that an instrument is paused, and leaves
enforcement entirely to the registry implementation, so the gap is named in a
live standard but unfilled. A shareable component is meaningful, but not as a
port of `Pausable.sol`: on Canton the enforceable part of a pause is a field on
a contract that already sits in the operation's authorization path, and the
shareable part is the interface, the view type, and the guard helpers around it.

## Existing Canton Implementations

### Daml Finance `Lockable` - the closest native analogue

- Interface: [`Daml.Finance.Interface.Util.V3.Lockable`](https://github.com/digital-asset/daml-finance/blob/155f931b6ebe7d3662fd72788cb17f0bfb5a7ba6/src/main/daml/Daml/Finance/Interface/Util/V3/Lockable.daml)
- Default implementation: [`Daml.Finance.Util.V4.Lockable`](https://github.com/digital-asset/daml-finance/blob/155f931b6ebe7d3662fd72788cb17f0bfb5a7ba6/src/main/daml/Daml/Finance/Util/V4/Lockable.daml)
- Account freeze in practice: [`Daml.Finance.Account.V4.Account`](https://github.com/digital-asset/daml-finance/blob/155f931b6ebe7d3662fd72788cb17f0bfb5a7ba6/src/main/daml/Daml/Finance/Account/V4/Account.daml)

Daml Finance does not model a pause. It models a lock, and it implements account
freezing as a lock with the context string `"Frozen"`. The documentation states
this directly: an account "can optionally implement the `Lockable` interface,
allowing it to be frozen, i.e., temporarily disabling credits and debits".

```daml
data Lock = Lock with
    lockers : Parties        -- parties which are locking the contract
    context : Set Text       -- why the lock is held; a set, for reentrant locks
    lockType : LockType      -- Semaphore | Reentrant

data View = View with
    lock : Optional Lock
    controllers : Parties    -- whose authorization is needed to acquire a lock

interface Lockable requires Disclosure.I where
  viewtype V
  acquire : Acquire -> Update (ContractId Lockable)
  release : Release -> Update (ContractId Lockable)

mustNotBeLocked : (HasToInterface i Lockable) => i -> Update ()
```

Two properties matter more than the API shape.

First, **the flag lives on the resource contract itself**. `Account` carries
`lock : Optional Lockable.Lock` as a template field, and `credit` / `debit` call
`Lockable.mustNotBeLocked this`. The contract that is already being exercised
answers the question. There is no separate state contract to locate, disclose,
or verify, so the canonical-instance problem does not arise.

Second, **the lock also moves authority**. `Account` declares
`signatory custodian, owner, Lockable.getLockers this`, and `acquireImpl`
asserts that `newLockers` is a subset of the new contract's signatories. A locked
account cannot be archived or replaced without the lockers. Enforcement is
therefore structural as well as flag-based.

Limitations for our purposes:

- Per-resource, not global. There is no "freeze this instrument everywhere".
  Freezing an instrument means freezing every account, one contract at a time.
- Daml 2.x and keyed. The tests use `submitExerciseInterfaceByKeyCmd`, so the
  pattern assumes contract keys with maintainer-guaranteed uniqueness. That
  guarantee does not exist in Canton 3.x (see Gap Analysis).
- Requires template-author opt-in at compile time. `Lockable` cannot be added to
  a template the author did not write.
- Semantically a lock, not a pause: it names lockers and a reason, and it is
  designed for collateral and settlement encumbrance, not for an operator's
  emergency stop.

### Daml Finance account `controllers`

The default account implementation gates incoming and outgoing transfers through
a `controllers` property rather than a flag. This is pause-by-authority: the
operation needs the controller's authorization, so withholding it stops the
operation. It costs interactivity, which is the trade-off discussed under
Recommendation.

### CIP-0112 - pause reporting is standardized, enforcement is not

[CIP-0112 §4.1.7](https://github.com/canton-foundation/cips/blob/1838cc0cc4d908ed2d6c912636c956b93273e66e/cip-0112/cip-0112.md) states the problem in the ecosystem's own words:

> A global "pause" function is fairly universal in RWAs. CIP-0056 gave no
> standardized way to detect this for wallets, exchanges, or apps other than via
> attempted but failed transfers. CIP-0112 extends the token metadata API to
> expose a `paused` flag and optional `pauseInfo`, allowing wallets and other
> clients to detect when an instrument is paused and why.

The extension is to the OpenAPI spec of the off-ledger metadata endpoint, in
[`token-metadata-v1.yaml`](https://github.com/hyperledger-labs/splice/blob/82b447cf088fbeb17fb78142d55f1ffe984df7ff/token-standard/splice-api-token-metadata-v1/openapi/token-metadata-v1.yaml):

```yaml
paused:
  description: |
    Indicates whether the instrument is currently paused. A paused instrument
    cannot be transferred or allocated.
  type: boolean
  default: false
pauseInfo:
  $ref: "#/components/schemas/PauseInfo"

PauseInfo:
  properties:
    reason:   { type: string }                      # why it is paused
    until:    { type: string, format: date-time }   # exclusive, if known
```

This is the single most important finding. A live Canton standard asserts that a
global pause is normal for RWAs, defines the vocabulary for it (`paused`,
`reason`, `until`), commits registries to publishing it, and specifies nothing
about how it is enforced or where the value comes from. A registry is free to
serve `paused: true` from a config file.

### Splice token standard - no on-ledger pause interface

Across the sixteen `splice-api-token-*` packages at
[82b447c](https://github.com/hyperledger-labs/splice/tree/82b447cf088fbeb17fb78142d55f1ffe984df7ff/token-standard)
there is no pause interface, no pause choice, and no pause field. The only
`paused` occurrences in the tree are the OpenAPI schema above, its changelog
entry, and an unrelated legacy-sequencer comment in DSO governance.

The standard does contain a *de facto* pause, and it is worth naming because it
sets the bar the component must beat. Every factory choice requires a choice
context obtained from the registry's off-ledger API:

```
POST /registry/transfer-instruction/v2/transfer-factory
  -> factoryId, choiceContext.choiceContextData, choiceContext.disclosedContracts
```

A registry that wants to stop transfers can simply stop answering. No client can
assemble a valid command without the disclosed contracts. That mechanism is
free, needs no Daml, and is what registries do today. It is also weak: a client
holding a previously fetched context whose disclosed contracts are still active
can still submit; the stop is invisible to auditors; and nothing on the ledger
records that a pause was in effect when a transaction was rejected.

### Splice / Amulet - no application-level pause

Amulet has no pause. The pause machinery in Splice is at the infrastructure
layer: `LegacySequencerConfig` in DSO governance, and the operational SV
endpoints `/v0/admin/domain/pause` and `/unpause`. CIP-0062, CIP-0089 and
CIP-0117 all use "pause" to mean halting the synchronizer for an upgrade. None
of it is reachable by an application.

### The Canton documentation's own reference pattern

The [Explicit Contract Disclosure](https://docs.canton.network/appdev/deep-dives/explicit-contract-disclosure)
deep-dive contains the closest thing to an official shape for "authority-signed
reference state that non-stakeholders must consult":

```daml
-- Expresses the current market value of a stock issued by the issuer.
-- Not modelled in this example: the issuer ensures that only one `PriceQuotation`
-- is active at a time for a specific `stockName`.
template PriceQuotation
  with
    issuer: Party
    stockName: Text
    value: Int
  where
    signatory issuer

    -- Helper choice to allow the controller to fetch this contract without being
    -- a stakeholder. By fetching this contract, the controller proves that this
    -- contract is active and represents the current market value for this stock.
    nonconsuming choice PriceQuotation_Fetch: PriceQuotation
      with fetcher: Party
      controller fetcher
      do pure this
```

Three things to take from it:

1. The read choice has a **flexible controller** (`fetcher`), not the issuer.
   Without that, a consumer who is not a stakeholder cannot read the state.
2. The docs prescribe **binding assertions** in the consuming choice:
   `priceQuotation.issuer === quotationProducer` and
   `priceQuotation.stockName === asset.stockName`. Read the signer and the
   subject, and check both against what the resource expects.
3. The docs **concede the uniqueness gap in a comment**. Single-active-instance
   selection is an off-ledger issuer responsibility. Canton does not offer it.

Disclosure itself is safe. Contract ids are a hash over arguments, template id
and signatories, so a tampered payload is rejected with
`DISCLOSED_CONTRACT_AUTHENTICATION_FAILED`; and disclosed contracts are resolved
through the normal activeness lookup, so an archived pause state cannot be
replayed. Staleness is not the risk. Substitution of a different live instance
is.

### Independent community libraries - nothing

[SynfiniDLT](https://github.com/SynfiniDLT) `daml-tokenization-toolkit`,
`account-hierarchy` and `daml-nft` are the substantial independent Daml
tokenization libraries. Across 67 Daml source files there is not one occurrence
of pause, freeze, frozen, suspend, halt or disable. They also do not use
`Lockable`.

### Operational-layer alternatives that already exist

Worth listing because a reviewer will ask why an on-ledger component is needed:
a participant operator can un-vet a package, a party can be deactivated, and an
SV can pause the synchronizer. All three are blunt, operator-scoped, invisible
to Daml, and unusable as an application-level control.

## Cross-Ecosystem Implementations

### Cardano / Plutus

The most informative comparison, because Cardano's eUTxO model has the same
absence of readable global state that Canton has.

The two mechanisms Cardano uses to answer "what is the current policy state" are
the [state thread token](https://plutonomicon.github.io/plutonomicon/statethread)
and [CIP-31 reference inputs](https://cips.cardano.org/cip/CIP-31). A state
thread NFT distinguishes the UTxO carrying the current state from other UTxOs at
the same script address, which is exactly the canonical-instance problem, solved
by making uniqueness a minting-policy invariant rather than a lookup. Reference
inputs let a validator read a UTxO without spending it, which is the direct
analogue of a Canton `fetch` on a disclosed contract, and it exists for the same
reason: spending the state would serialize every reader.

[CIP-113 programmable tokens](https://github.com/cardano-foundation/cip113-programmable-tokens/tree/9db7e0629a1509cc9d41d069f0ef0ed251601173)
is the regulated-token standard built on this. Its architecture is a shared
registry of token entries, each naming an issuance script, a transfer-validation
script, an issuer-control script and an *optional global state reference (e.g.,
denylist)*, plus pluggable "substandards". The shipped freeze-and-seize
substandard implements an on-chain denylist with sender and recipient checks and
issuer freeze/seize controls. The published introduction does not specify how
the transfer validator resolves the authoritative policy UTxO; the registry
entry holds a reference and the mechanics live in an architecture document not
included there.

The lesson for Canton is the shape, not the code: the ecosystem that shares our
constraint arrived at a registry entry that *names* the policy state, a policy
state read by reference, and uniqueness enforced by the minting policy rather
than by a lookup. Canton's equivalent of the registry entry is a field on the
authority contract. Canton has no equivalent of the minting policy, which is why
uniqueness stays an operator responsibility.

### Corda

No standard pause exists. The Tokens SDK provides issue, move and redeem, with
no freeze or suspend. Corda's reference states are a close parallel to Canton's
disclosed-contract fetch, and Corda's notary consumption check gives the same
activeness guarantee, but nobody built the pattern into a shared library. Corda
is prior art for the absence, not for the design.

### Solidity / EVM

[`Pausable.sol`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/0a76a61577248146ec6a905c7359fec2de2109f6/contracts/utils/Pausable.sol)
is an abstract mixin:

```solidity
bool private _paused;
event Paused(address account);   event Unpaused(address account);
error EnforcedPause();           error ExpectedPause();
modifier whenNotPaused();        modifier whenPaused();
function paused() public view returns (bool);
function _pause() internal whenNotPaused;      // internal, on purpose
function _unpause() internal whenPaused;
```

The design decision to copy is that `_pause` is `internal`. The component ships
no authorization; the deriving contract wires it to `Ownable` or `AccessControl`.
That separation is the right one and matches this repository's rule that
implementation packages do not depend on other implementation packages.

The design decision that does *not* translate is `_paused` in contract storage
read by a modifier. That works because EVM contracts have private mutable
storage that every call reads for free. Canton has neither the storage nor the
free read.

Two further EVM points are load-bearing:

- **[`AccessManager.setTargetClosed`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/0a76a61577248146ec6a905c7359fec2de2109f6/contracts/access/manager/AccessManager.sol)**
  (`onlyAuthorized`, `ADMIN_ROLE`) closes a target at the authority layer.
  `canCall` returns false first, before any role check, and permissions survive
  the closure intact. This is pause implemented as authority revocation rather
  than as a flag on the resource, and it is the closest EVM analogue to the
  Canton shape recommended below.
- **[ERC-3643 / T-REX](https://eips.ethereum.org/EIPS/eip-3643)** is the RWA
  standard CIP-0112 is implicitly referencing. It carries both a global
  `pause()` and targeted controls (`setAddressFrozen`,
  `freezePartialTokens` / `unfreezePartialTokens`), exercised by agents. Global
  and targeted are separate features with separate authority in every serious
  RWA standard. Aave splits them the same way: `setPoolPause` and
  `setReservePause` under `onlyEmergencyOrPoolAdmin`, held by a 5/9 guardian
  multisig, and explicitly scoped so it cannot touch individual positions.

Authorization-model mismatch to keep in view: every EVM pattern above assumes
`msg.sender` plus globally readable state. On Canton the caller's identity is a
set of authorizing parties, and the state is not readable at all unless someone
hands it to you. Copy the feature decomposition. Do not copy the enforcement
mechanism.

Empirical context for the Risks section: an analysis of 84,062 Ethereum
contracts found roughly 58% are administrated ERC20 tokens, about 90% of
deployed ERC20s, and identified indefinite pause by a compromised or malicious
admin as a primary hazard. The proposed mitigations were deferred maintenance, a
board of trustees, and a safe pause with a forced unfreeze deadline
([arXiv:2107.10979](https://arxiv.org/abs/2107.10979)).

### Hyperledger Fabric / Quorum

Stubbed by agreement. Fabric's pause is a boolean under a key in channel world
state, read by chaincode. Inside a channel the state is globally readable, which
is the exact property Canton lacks, so the pattern carries no transferable
lesson. Quorum privacy groups would be the interesting case, but the private
state is still globally readable within the group, so the same objection holds.

### Privacy / Disclosure Requirements and Leakage

Requirements and attack classes only, as agreed.

- **The pausing authority learns the traffic.** Per the Canton ledger model, for
  a `Fetch` node the signatories of the fetched contract are informees, while
  observers are not: "Bank 2 and Bob are informees of the Fetch node because
  Bank 2 is a signatory of the input contract and Bob is the actor. Had Bob not
  been the actor, he would not be an informee because contract observers are not
  automatically informees of non-consuming Exercises and Fetches"
  ([ledger model](https://docs.canton.network/overview/reference/ledger-model-detailed)).
  A separate pause-state contract signed by the pauser therefore puts the
  pauser's participant node in the read path of every gated operation. The
  pauser's projection is limited to the `Fetch` subaction, so no payload leaks,
  but the volume and timing of all gated activity does, and the node must
  process and store an event per operation. This is the sharpest Canton-specific
  consequence of a naive port, and it is documented nowhere in a pausable
  context.
- **The same rule is good news for the observer route.** Adding consumers as
  observers on the pause state does not make them informees of each other's
  fetches. Broad observation does not create cross-consumer leakage on reads.
- **Divulgence widens on `fetch`.** Whatever the pause state carries is divulged
  into the transaction. A `reason` string describing a regulatory action is the
  wrong thing to put in a field that every transfer fetches.
- **Targeted freeze leaks the subject.** ERC-3643's on-chain denylist publishes
  who is frozen. Any Canton design that requires a caller to consult a per-party
  freeze list must not make that list readable by callers. This is the strongest
  argument for keeping targeted freeze on the subject's own resource contract
  rather than in a shared list.
- **Absence is unprovable.** A Daml choice cannot verify that a contract does
  not exist. Any pause modelled as "the enabling contract was archived" must be
  checked positively, by requiring a live contract, or it is not enforceable.

### Other Ecosystems

**Sui.** The Coin Registry / Currency Standard has an explicit global pause for
regulated coins, gated on `DenyCapV2` created with `allow_global_pause = true`:
`coin::deny_list_v2_enable_global_pause` and
`..._disable_global_pause`, with state in the system `DenyList` shared object
([docs](https://docs.sui.io/standards/currency)). Two details are worth
importing. Global pause and the address deny list are independent: clearing the
pause does not unfreeze denied addresses. And enforcement is split in time,
immediate for inputs and only at the next epoch boundary (about 24 hours) for
receiving. Even a chain with a global shared object accepts a propagation delay.

**Aptos.** Freezing is per-store, not global: `set_frozen_flag` takes a
`TransferRef`, an owner address and a boolean, over a `FungibleStore` whose
address is derived from the owner and the metadata object. Dispatchable fungible
assets let the issuer inject custom withdraw and deposit logic. Closest in
spirit to Daml Finance's per-account lock.

**XRPL.** The richest vocabulary, and the only one with a renunciation
primitive:
[Individual Freeze, Deep Freeze, Global Freeze and No Freeze](https://xrpl.org/docs/concepts/tokens/fungible-tokens/freezes).
Three transferable ideas. Individual Freeze still permits payments *to the
issuer*, so a pause has a deliberate escape hatch for redemption. Deep Freeze is
a separate, stronger setting that also blocks receiving, so send-block and
receive-block are distinct capabilities. No Freeze permanently surrenders the
ability to freeze individuals and to end a global freeze, which is a credible
commitment mechanism that `Pausable.sol` has no equivalent of and that Canton
models cleanly by archiving the authority contract with no successor.

**Stellar.** `AUTH_REQUIRED` gates trustlines, and
[SEP-0008](https://github.com/stellar/stellar-protocol/blob/8912a8047931453bb5d6a631e10a9d7125c570f3/ecosystem/sep-0008.md)
regulated assets route every transaction through an issuer approval server
returning Success, Revised, Action Required or Rejected. This is the same shape
as the Splice choice-context endpoint: pause by declining to approve. Two
unrelated ecosystems converged on an off-ledger per-transaction gate, which is
evidence that the pattern is natural and also evidence for why it is not
sufficient on its own.

## Ecosystem Needs

**Who wants this.** CIP-0112 identifies the population directly: RWA issuers.
Any registry implementing the metadata API must now publish a `paused` flag, and
must decide what backs it. Regulated stablecoin issuers need pause plus targeted
freeze for sanctions response, the ERC-3643 feature set. Registries built on
CIP-0056 / CIP-0112, including the `openzeppelin-tokenCIP112-v1` line of work,
are the immediate consumers.

**The common pattern across ecosystems.** Every serious regulated-asset standard
ships the same three-part decomposition: a global pause on the instrument, a
targeted freeze on a holder, and an issuer-side forced action (clawback, seize,
recovery, forced transfer). They are separate capabilities with separate
authority. A component that conflates global pause with targeted freeze will not
fit any of them.

**Pain points with what exists today.** A Canton registry that wants to pause
either stops serving choice contexts, which is unenforced and unauditable, or
writes a bespoke flag into its own rules contract, which is what every registry
will do independently and inconsistently. Neither produces an on-ledger record
that an auditor can use to establish that a pause was in force at a given time.

**Integration requirements.** These are firm constraints on any design.

1. The pause state must reach a non-stakeholder caller, which means it must be
   deliverable as a disclosed contract through the registry choice-context
   response, or must live on a contract the caller already sees.
2. The read must be exercisable by a party that is not a stakeholder, which
   means a flexible-controller read choice or a plain field on a fetched
   contract.
3. The on-ledger shape must be projectable onto CIP-0112's
   `paused` / `pauseInfo{reason, until}` so the metadata endpoint can be derived
   from ledger state instead of from configuration.
4. Choice contexts are prefetched and chained. The CIP-0112 API notes that
   implementations "SHOULD avoid that this value depends on contract-ids passed
   in the choice arguments, so that clients can prefetch choice contexts when
   chaining multiple token standard actions together in a single Daml
   transaction." A pause state whose contract id changes on every flip is
   compatible with this, but a design that forces a fresh context per action is
   not.
5. Flipping the pause contends with every concurrent read. Canton's guidance is
   explicit that write-read contention occurs "when one requester submits a
   transaction with a consuming exercise on a contract while another requester
   submits another exercise or a fetch on the same contract", and that
   non-consuming choices do not collide with each other. Concurrent reads are
   free; the flip rejects everything in flight.

## Gap Analysis

**What exists but is incomplete.**

- CIP-0112 defines the pause vocabulary and the reporting duty, and specifies no
  enforcement and no provenance for the value. A registry can report a pause it
  does not enforce, or enforce one it does not report.
- Daml Finance `Lockable` is the right mechanism for the wrong problem, is
  per-resource, and assumes keys.
- The registry choice-context endpoint is an effective but unenforced,
  cache-vulnerable and unauditable pause.

**What is missing entirely.**

- Any on-ledger pause interface in the Canton ecosystem, in any package,
  standard, or community library.
- Any shared vocabulary for pause authority, pause reason, or pause expiry on
  the ledger.

**What the platform does not solve and will not.**

- **Canonical-instance selection.** Canton offers no way to prove that a
  presented contract is the unique current instance of anything. The official
  disclosure example concedes this in a source comment. LF 2.3 contract keys do
  not fix it: the Canton 3.5 release notes state that "the keys are not unique,
  meaning multiple contracts may share the same key" and "negative lookups are
  not validated", and conclude that "application developers must ensure key
  uniqueness through external enforcement mechanisms". Moving to LF 2.3 improves
  ergonomics and changes nothing about the guarantee.
- **Mandatory guards across a package boundary.** No Daml construct forces a
  consumer's choice body to call a guard. An interface can own the body of its
  own choices, but the pause check has to happen inside the *gated* operation,
  which belongs to someone else's interface. Solidity has the same limitation
  and at least makes the missing `whenNotPaused` visible in the signature; Daml
  offers no equivalent marker.
- **Retrofitting.** Per the language reference, "to make a template an instance
  of an existing interface, an `interface instance` clause must be defined in
  the template declaration", and the clause's template must match the enclosing
  declaration. A `Pausable` interface cannot be attached to a template whose
  source you do not control. An existing package can add the instance in a later
  SCU-compatible version, but that still requires a source change and a release
  by the template's owner.
- **Interface package freeze cost.** Interface definitions are not upgradeable.
  Redefining one in version 2 of a package fails to type check even when the
  definition is unchanged, and a template sharing a package with an interface
  loses upgradeability too, so interfaces need their own package that defines no
  templates ([SCU deep-dive](https://docs.canton.network/appdev/deep-dives/smart-contract-upgrade#separate-interfaces/exceptions-from-templates)).
  The consequence for a consumer is a pin rather than a dead end. A package that
  uses an interface stays on that exact interface-package version, and a
  breaking interface change is published as a sibling `-v2` package beside `-v1`,
  with both versions live on the ledger and consumers migrating at their own
  pace. A single interface choice can also be retired in place by making its
  body `error "No longer implemented."`.

**What could usefully be standardized.** The view type. If pause state is
exposed through one interface view whose fields map onto CIP-0112's `paused`,
`reason` and `until`, then wallets, auditors and the metadata endpoint read one
shape regardless of which registry implements it. That is the part with genuine
network value, and it is small.

**Pitfalls found in other ecosystems.**

- Fail-open guards. A pause that depends on the implementer remembering an
  assert fails silently in the direction of permitting the operation.
- Conflating global pause with targeted freeze. Every RWA standard keeps them
  separate; Sui goes as far as making clearing the global pause leave the deny
  list untouched.
- Indefinite pause. The dominant audit finding against `Pausable`, and the
  reason the ERC20 literature proposes forced unfreeze after a deadline.
  CIP-0112's `until` field already anticipates a bounded pause.
- No escape hatch. XRPL keeps payments to the issuer legal during an individual
  freeze. A total pause that also blocks redemption traps holders.
- Propagation delay is normal. Sui accepts an epoch boundary for the receive
  side. A Canton design should state what happens to in-flight workflows rather
  than pretend the flip is instantaneous.

## Recommendation

- **Verdict: Build differently.**

**Recommended approach.**

Do not ship a standalone `PauseState` template as the product. On Canton a pause
is enforceable exactly where the pausing authority is already a required
authorizer in the operation's authorization path. A `create` needs the authority
of every signatory of the created contract, and non-interactive authority comes
only from exercising a choice on a contract that authority signed. Where the
pauser already owns such a chokepoint - a registry factory, an admin-signed
rules contract, a custodian-signed account - the pause is a field on that
contract plus one assert, and it needs no separate contract, no disclosure, no
canonical-instance selection, and no extra ledger events. Where the pauser owns
no chokepoint, no library can make a pause enforceable, because nothing compels
the parties to consult it. Daml Finance reached the same conclusion by putting
`lock` on `Account` rather than in a lock registry.

So the shareable component is three things, and a standalone flag contract is
not one of them. Ship a frozen `openzeppelin-pausable-api-v1` package defining a
`Pausable` interface whose view carries the pause state in CIP-0112-compatible
terms (`paused`, and optional `reason` and `until`), so that wallets, auditors
and the metadata endpoint read one shape across registries. Ship pure guard
helpers - the `whenNotPaused` / `requireNotPaused` family, plus the
`until`-versus-ledger-time evaluation and the binding checks that verify the
presented state's signer and subject against what the resource expects. And ship
the documentation that tells an integrator which of the two topologies they are
in, because that judgement, not the code, is what determines whether their pause
actually holds.

Offer the separate-contract shape as the secondary, documented-with-caveats
option for consumers who genuinely need one pause state shared across several
templates. Model it on the `PriceQuotation` pattern from the Canton docs, with a
flexible-controller read choice, mandatory non-optional presentation in the gated
choice, and mandatory binding assertions. Say plainly in the package README that
single-active-instance selection is the operator's responsibility, that the
pauser becomes an informee of every read, and that flipping the flag rejects
concurrent in-flight operations.

**Key design considerations.**

1. **Enforceability is a property of the authorization topology, not of the
   component.** Decide up front which topology the package serves, and state
   which one it cannot help. Everything else follows from this.
2. **Put the state where the caller already looks.** Prefer a field on the
   contract being exercised or on the authority contract in the path. Reach for a
   separate contract only when several templates must share one switch, and then
   accept off-ledger canonical-instance selection as an explicit, documented
   assumption.
3. **The pauser is an informee of every fetch.** A shared pause-state contract
   makes the pauser's node a participant in every gated operation, leaking
   traffic volume and timing and adding an event per operation. Where the pauser
   is already a signatory in the path, as a token-standard registry admin is,
   this costs nothing new. Where it is not, it is a real and surprising cost.
4. **Separate the capabilities, and separate their authority.** Global pause,
   targeted freeze and forced issuer action are three features in every RWA
   standard surveyed. Scope this component to global pause, and make sure the
   interface does not foreclose the other two.
5. **Decide the asymmetries and the escape hatches explicitly.** Bounded pause
   via `until` and ledger time; whether pause and unpause carry the same
   authority; which operations stay legal while paused, with redemption to the
   issuer as the precedent; and whether the authority can be irrevocably
   surrendered, which Canton models by archiving with no successor and which
   XRPL treats as a first-class feature.
6. **Align the view with CIP-0112 from the start.** The reporting standard
   already exists. A view that projects cleanly onto `paused` and
   `pauseInfo{reason, until}` lets a registry derive its metadata endpoint from
   ledger state, which is the concrete integration win. Keep sensitive reason
   text off a field that every transaction fetches.

**Risks.**

- **Building a component nobody can enforce.** The largest risk. A generic
  free-floating pause flag is easy to write, compiles, tests green, and provides
  no guarantee to a consumer whose authority is not in the operation's path. It
  would be worse than nothing, because it would look like a security control.
- **Fail-open enforcement.** No Daml mechanism makes the guard mandatory. If the
  package's value proposition is a guarantee, the documentation and the test
  suite carry it, not the type system. Design the API so the guard is hard to
  omit: a non-optional argument, a name that reads as an obligation, and a view
  that makes an unchecked implementation visibly wrong.
- **Interface freeze pins the dependency.** A consumer that depends on the
  frozen API package stays on that version of it. Correcting the view type later
  means publishing a sibling `-v2` package and migrating every consumer, so
  getting the view type wrong is expensive even though it is recoverable. This
  weighs against putting anything in the view that a later standard may extend,
  and CIP-0112 may extend `PauseInfo`.
- **Substitution.** A consumer who omits the signer and subject binding checks
  can be handed a different live pause state. The guard helpers should make the
  binding check the default path rather than an optional extra.
- **Centralization findings.** Pause is the most commonly flagged
  centralization control in smart-contract audits, and indefinite pause by a
  compromised key is the specific hazard. Composition with a timelock or a
  multi-party authority is a design question this component should answer by
  reference, not by absorbing `access-control` as a dependency.
- **CIP movement.** Nobody has proposed an on-ledger pause CIP, and no open CIP
  PR touches pause. The upside is that OpenZeppelin can define the shape. The
  downside is that a later CIP could define a different one. Aligning the view
  with CIP-0112's existing vocabulary is the cheapest hedge available.

## Out of Scope

- **Existing implementations in this repository.** Excluded at the dev's
  instruction. `experiments/security/pausable-v1` and
  `packages/security/pausable` were not treated as a baseline, and the report is
  written greenfield. Note that several findings here bear on that code, in
  particular the flexible-controller read choice and the pauser-as-informee
  cost.
- **Hyperledger Fabric and Quorum.** Stubbed by agreement. Their pause depends
  on globally readable state within a channel or privacy group, which is the
  property Canton lacks.
- **ZK privacy mechanisms.** Requirements and leakage classes only, per the
  skill's scope. No mechanism from Midnight, Aztec or Miden is transferable.
- **Targeted per-holder freeze and issuer forced actions.** Surveyed as context
  because every RWA standard bundles them with pause, but scoped out as separate
  components. The recommendation is only that this component's interface must not
  foreclose them.
- **Choosing the LF target.** Both LF 2.1 and LF 2.3 were researched. Keys do
  not change the canonical-instance guarantee, so the choice is a design-stage
  decision about ergonomics and protocol-version reach, not a research question.
- **The design itself.** Module layout, template and choice signatures, and the
  exact view record are Stage 2.

## Dev Notes

Decisions were taken on 2026-08-31 and are recorded against each question below.
Three of them depart from the Recommendation. The Recommendation is left as
written, because it records what the research concluded rather than what was
later chosen.

- **The view carries `paused` only.** The Recommendation asks for `reason` and
  `until` in the view as well. A consumer that must serve CIP-0112's `pauseInfo`
  carries those as its own template fields beside `paused`, so the whole
  metadata response still comes from one on-ledger contract while the frozen
  interface stays a single boolean. Interfaces cannot be extended, and CIP-0112
  may extend `PauseInfo`.
- **The guards do not evaluate ledger time.** Publishing `until` is reporting;
  enforcing it is a separate feature that raises who may extend a pause and
  whether expiry needs its own transaction. Neither belongs in the primitive. A
  consumer that wants an expiring pause writes it.
- **The separate-contract shape is not shipped.** The Recommendation offers it as
  a documented-with-caveats secondary option. Anyone who needs one switch shared
  across several templates can build it on `Pausable`: a single-field template
  implementing the interface, fetched and guarded by the protected operations,
  with their own check that the switch presented is the expected one.

One element of the design has no counterpart in the research. The component
ships no pause authority at all, matching `_pause`'s `internal` visibility in
Solidity. A Daml controller expression is pure and cannot fetch a credential, so
a role, a party set, or a timelock needs the caller and the credential as choice
arguments, which no inherited choice can provide. The consumer therefore writes
the pause choice in every case, and the interface supplies the flag, the getter,
the guards, and `pause`/`unpause`.

**Revised on 2026-09-01.** The design first split the single-party case into
`PausableAdmin requires Pausable`, which inherited `PausableAdmin_Pause` and
`PausableAdmin_Unpause` for a `pauser : Party` in its view. That second
interface was dropped in favour of one interface. Writing the consumer's own
choice costs the single-party case four lines, and a `pauser` field in a frozen
view is a standing invitation to name a placeholder party, which publishes a
false claim about who holds the switch and opens a live second path to it. One
interface also removes the question of which of the two a template should
implement. `setPausedImpl` moved onto `Pausable` as a result, so every
implementer supplies it; the cost is one method, and the benefit is that
`pause`/`unpause` carry the guard for every authority model rather than only the
single-party one.

## Open Questions

1. **Which topology does the component commit to serving?** Authority-in-path
   only, which is honest and narrow, or both shapes with the free-floating one
   carrying caveats? This decision determines the package's entire surface and
   should be made before design starts.

   **Decided: authority-in-path only.** The component serves the case where the
   pause authority already signs a contract that the protected operations are
   exercised on. The free-floating shape is not shipped.

2. **Is `openzeppelin-tokenCIP112-v1` the first consumer, and is the goal that
   its registry derives the CIP-0112 `paused` flag from ledger state?** If yes,
   the view type is driven by that endpoint and the design has a concrete
   acceptance test. If no, the CIP-0112 alignment argument weakens considerably.

   **Decided: no field mirroring.** The view does not carry CIP-0112's fields. A
   registry holds `reason` and `until` as its own template fields beside
   `paused` and serves the endpoint from all three, so the response is still
   derived from ledger state without freezing those fields into an interface
   that cannot later change.

3. **Does a frozen `-api-v1` interface package earn its cost here?**
   ARCHITECTURE.md requires one for any interface, and the dependency-freeze
   consequence is real. The alternative is a template-only package with guard
   functions and no interface, which loses the cross-registry uniform view that
   is the main network-level argument for building this at all.

   **Decided: yes.** Ship `openzeppelin-pausable-api-v1`, public module
   `OpenZeppelin.PausableV1`, no implementation package because there are no
   templates. Without the interface there is no component, only a few
   `assertMsg` wrappers. The freeze is a pin rather than a dead end, and the
   frozen surface is one boolean plus one party.

4. **What is the intended answer on pause authority composition?** Ownable,
   AccessControl, a timelock, or authority-agnostic in the Solidity manner where
   `_pause` is internal and the consumer wires it. The repository's dependency
   policy pushes toward authority-agnostic; the audit literature pushes toward
   shipping a safe default.

   **Decided: authority-agnostic, with no add-on** (revised 2026-09-01).
   `Pausable` carries the flag, the getter, the guards, and `pause`/`unpause`,
   and names no authority. Every consumer writes the choice that decides who may
   flip the switch, single-party consumers included. The optional
   `PausableAdmin` add-on that an earlier revision shipped for a single `pauser`
   party was dropped: it saved four lines, and it froze a `pauser` field into a
   view where a placeholder value would publish a false claim about who holds
   the switch.

5. **Is a bounded pause (`until`) in scope for v1?** It answers the dominant
   audit criticism and CIP-0112 already has the field, but it puts ledger-time
   evaluation inside the guard and raises questions about who may extend a pause
   and whether an expired pause needs an explicit unpause transaction.

   **Decided: out of scope for v1.** CIP-0112 alignment needs the reporting half
   only, which a consumer supplies from its own fields. Keeping ledger-time
   evaluation out of the guard leaves both follow-on questions unasked.

6. **What is the required behaviour for in-flight workflows at the moment of a
   flip?** Sui accepts an epoch delay; Canton will reject concurrent readers.
   Confirm that origination-only pause semantics, where committed work proceeds
   and new work is refused, is the intended and documented guarantee.

   **Decided: origination-only, as proposed.** A gated choice refuses to start
   while paused, committed work is unaffected, and a flip rejects the concurrent
   operations that were reading the contract. Stated in the package README and
   the module header. Where a consumer applies the guard, including whether a
   multi-step workflow gates its completion steps as well as its entry point, is
   the consumer's decision and belongs with that workflow rather than with this
   primitive. `Pausable.sol` documents nothing on the subject either.
