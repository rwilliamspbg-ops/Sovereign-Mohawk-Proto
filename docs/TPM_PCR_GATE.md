# TPM PCR policy gate

`scripts/tpm_pcr_policy_gate.sh` gates a command on measured TPM PCR values.
It is the first step toward "the agent only starts if the boot state matches a
policy": wrap the agent's `docker compose up` with the gate, and a changed PCR
(e.g. firmware or bootloader change) prevents startup.

## Policy format

```
# comments allowed
sha256 <pcr-index> <expected-hex>
```

Capture a policy on the target host with (requires root to read `/dev/tpmrm0`):

```bash
sudo tpm2_pcrread sha256:0,1
# copy the 0x... values, without the 0x prefix, into the policy file
```

## Usage

```bash
TPM2PCRREAD="sudo -n tpm2_pcrread" \
  scripts/tpm_pcr_policy_gate.sh policy.txt -- \
  docker compose -f docker-compose.yml -f lan-compose-b-agent3.yml up -d --no-deps node-agent-3
```

Exit codes: `0` = all PCRs matched (and the wrapped command succeeded, if any),
`2` = usage/read error, `3` = PCR mismatch — the wrapped command is NOT run.

`TPM2PCRREAD` overrides the reader command (default `tpm2_pcrread`) so the gate
can be tested with a deterministic mock. Run `bash scripts/test_tpm_pcr_policy_gate.sh`
for those tests. Both the match and mismatch paths were also exercised on an
Ubuntu host with a mock reader; the mismatch path returns 3 and does not leak
the command.

## Root access requirement

Reading PCRs needs root (`/dev/tpmrm0` is group `tss`). On a host where the
operator has configured a narrow passwordless sudo rule for `tpm2_pcrread`, the
example above works unattended. Otherwise run the gate in a root shell or
configure `/etc/sudoers.d/tpm-pcr-read` locally. The agent never embeds or
forwards a sudo password; the gate only invokes the configured reader.

## Scope

The gate checks measured boot state before startup. It does not by itself
implement remote attestation, PCR policy sealing, or a measurement of the agent
binary; those remain separate work.
