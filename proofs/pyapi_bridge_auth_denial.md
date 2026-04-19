# Python SDK Bridge Authorization Denial Proof

## Module: internal/pyapi/api.go

**Status:** ✓ VERIFIED

**Date:** 2026-04-17

**Version:** v0.3.0

---

## 1. Overview

This document provides a formal proof sketch for the bridge authorization negative paths that back the `wrong_role_blocked` and `wrong_token_blocked` checks in the strict auth smoke path.

The property we want is simple but important:

> For every protected bridge mutator, a mismatched role or invalid token must fail before any ledger mutation or privileged action occurs.

The relevant mutators are the bridge entrypoints that call `validateUtilityAccess(...)` before reaching the token ledger:

- `MintUtilityCoin`
- `TransferUtilityCoin`
- `BurnUtilityCoin`
- `BackupUtilityCoinLedger`
- `RestoreUtilityCoinLedger`

## 2. Authorization Preconditions

### Lemma 2.1: Token denial is strict

**Statement:** If `validateUtilityAccess(op, role, providedToken)` is invoked with a configured auth mode and `verifyAPIToken(providedToken)` fails, the function returns `invalid API token` and the operation is rejected.

**Proof:**
- `validateUtilityAccess` checks the configured auth mode first.
- In required and file-only modes, the provided token must verify successfully.
- Any failed verification returns an error before role authorization executes.

### Lemma 2.2: Role mismatch is strict

**Statement:** If the bridge is token-bound to an authorization role and the request role differs, the request is rejected with `role mismatch for token-bound principal`.

**Proof:**
- `effectiveUtilityRole(requestRole)` normalizes both the request role and the token-bound role.
- If a token role is configured, any conflicting request role returns an error.
- That error propagates unchanged through `authorizeUtilityRole(...)`.

### Lemma 2.3: Missing or disallowed role is strict

**Statement:** If a protected operation requires a role and the supplied role is missing or not in the allowed set, the request is rejected with an explicit role error.

**Proof:**
- `authorizeUtilityRole(op, requestRole)` first resolves the effective role.
- If the role is missing and the policy requires it, the function fails with `role is required for <op>`.
- If the role is present but not in the allowlist, the function fails with `role "<role>" is not allowed for <op>`.

## 3. Bridge Safety Theorem

### Theorem 3.1: Wrong-role and wrong-token bridge requests cannot reach mutation

**Statement:** For the protected bridge mutators listed above, a wrong role or wrong token cannot proceed to ledger mutation or privileged side effects.

**Proof Sketch:**
1. Each mutator extracts the provided token from `auth_token`, `authorization`, or `api_token`.
2. Each mutator calls `validateUtilityAccess(...)` before rate limiting or ledger mutation.
3. `validateUtilityAccess(...)` rejects invalid tokens before role authorization.
4. If the token is valid but the requested role is wrong, `authorizeUtilityRole(...)` rejects with an explicit role error.
5. Because both failures occur before the mutation step, the protected bridge action remains non-executable under wrong-role and wrong-token inputs.

## 4. Evidence Alignment

This proof is aligned with the following executable evidence:

- `internal/pyapi/api_security_test.go`
  - explicit `invalid API token` assertion
  - explicit `role "operator" is not allowed for transfer` assertion
- `scripts/strict_auth_smoke.py`
  - wrong-role blocked check
  - wrong-token blocked check

## 5. Conclusion

The bridge authorization layer now has both:

1. **Executable enforcement** through `validateUtilityAccess(...)` and `authorizeUtilityRole(...)`
2. **Formal proof sketch** that wrong-role and wrong-token inputs cannot reach privileged mutation paths

This closes the requested hardening objective for the bridge/auth layer at the repo’s current proof-documentation level.
