# Smart-Waste-Management-System

An IoT-powered waste optimization system built with Stacks/Clarity and Clarinet. It focuses on two on-chain modules without cross-contract calls or trait usage:

- smart-bin-monitoring: Tracks bin registrations, sensor-reported fill levels, and collection events with tamper-evident logs and admin controls.
- eco-rewards-token-system: A minimal non-transferable proof-of-reward ledger that mints and records reward points for recycling/sustainability actions.

This repository follows a two-branch workflow:
- main: Project initialization files and documentation only (Clarinet scaffolding + README.md).
- development: Active contract development, including .clar sources and PR documentation.

Key requirements and constraints:
- Clarity only (.clar), no cross-contract calls, no traits.
- Clean, simple, logically correct, syntactically valid contracts.
- Contracts validated with clarinet check.
- Package.json and Clarinet.toml are included from Clarinet scaffolding.

Getting started

1) Prerequisites
- Clarinet (https://docs.hiro.so/clarinet)
- Git and GitHub CLI (gh)

2) Project structure (high-level)
- Clarinet.toml — Clarinet project configuration
- contracts/ — Clarity contracts (on development branch)
- settings/ — Network configs (Devnet/Testnet/Mainnet)
- tests/ — Unit test scaffolding (optional)
- .vscode/ — Editor tasks and settings
- package.json — Tooling metadata from Clarinet

3) Development workflow
- Create/modify contracts under contracts/ on development branch.
- Validate locally with clarinet check.
- Commit with clear, one-line messages per contract.
- Open a PR targeting main with PR-DETAILS.md as the body source.

4) Contracts overview

smart-bin-monitoring
- Admin registers bins (id, location, capacity) and authorized sensor/reporters.
- Reporters submit fill-level reports (0–100) stamped with block height and time.
- Collection events can be recorded for a bin with optional notes.
- Public read-only views expose bin metadata, latest report snapshot, and full logs.
- Invariants enforced: unique bin IDs, bounded fill levels, authorized reporters only.

eco-rewards-token-system
- Maintains per-principal reward balances in u128 points.
- Admin-only mint/burn with optional memo strings for event context.
- Non-transferable points by design (no transfer entrypoint) to simplify compliance.
- Public read-only views expose balances and a compact event log.
- Invariants enforced: overflow-safe arithmetic and zero-amount prevention.

5) Security notes
- No traits or cross-contract calls keep trust boundaries clear and audit scope small.
- Admin principals are explicitly set at deploy-time constants.
- Input validation on all public functions (bounds, duplicates, authorization).

6) Validation
- Run clarinet check to ensure syntax and type checks pass.

License

MIT
