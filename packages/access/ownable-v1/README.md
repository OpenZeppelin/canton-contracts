# Ownable V1

A two-step ownership capability for Daml applications, including offer,
acceptance, decline, withdrawal, and renunciation.

| Field | Value |
|---|---|
| Package | `openzeppelin-ownable-v1` |
| Public module | `OpenZeppelin.OwnableV1` |
| Version | `0.1.0` |
| Status | Experimental; unaudited |
| Solidity analogue | `Ownable2Step` |

> [!WARNING]
> `Ownership` is a generic capability and is not intrinsically bound to an
> application resource. Applications must establish which ownership contract is
> canonical for each protected resource.

## What it provides

- `Ownership`: an owner-signed capability that can begin a transfer or be
  renounced.
- `OwnershipOffer`: a pending transfer observed by the nominated owner.
- Accept, decline, and withdraw paths that make the consent and recovery model
  explicit.

The two-step handoff is necessary in Daml because a new signatory cannot be
bound unilaterally. Acceptance creates a new `Ownership` signed by the nominee;
decline or withdrawal restores ownership to the original owner.

## Authority and lifecycle

- The current owner signs `Ownership` and controls transfer and renunciation.
- The current owner signs an offer; the nominee observes it and alone can accept
  or decline it.
- The original owner can withdraw a pending offer.
- Renunciation or direct archival leaves no replacement ownership contract.
- The consuming application is responsible for selecting and disclosing the
  authoritative ownership contract for its resource.

## Build

From the repository root:

```sh
DAML_PACKAGE=packages/access/ownable-v1 dpm build
```

## Consume a local build

```yaml
data-dependencies:
  - ../canton-contracts/packages/access/ownable-v1/.daml/dist/openzeppelin-ownable-v1-0.1.0.dar
```

```daml
import OpenZeppelin.OwnableV1
```
