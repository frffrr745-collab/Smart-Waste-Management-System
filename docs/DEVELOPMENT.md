# Development Guide

Overview

This document explains how to work on the Smart-Waste-Management-System locally, validate contracts, and run tests.

Requirements

- Clarinet 3.x
- Node.js LTS and npm
- Git + GitHub CLI (gh)

Contracts

- contracts/smart-bin-monitoring.clar
- contracts/eco-rewards-token-system.clar

Both are independent (no traits, no cross-contract calls).

Validation

- Compile/type-check all contracts:
  clarinet check

Testing

1) Install dependencies:
  npm install

2) Run vitest with coverage and costs:
  npm run test:report

Notes

- .editorconfig enforces LF endings for .clar files; if you edit on Windows, ensure your editor respects .editorconfig to avoid CRLF issues.
- Initialize admin in tests by calling set-admin from the deployer before any privileged actions.
- Use development branch for ongoing work; open PRs targeting main.
