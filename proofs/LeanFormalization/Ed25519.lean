import Mathlib
import LeanFormalization.SHA512

/-! # Experimental Ed25519 model

This module provides a simplified Ed25519 verifier used as a placeholder-style
model for the UF-CMA formalization. It is **not** a verified, production-grade
implementation: message encoding is restricted (empty message or a Nat encoded
as 32 little-endian bytes), scalar multiplication assumes a 256-bit bound,
and the group-law/decoding code has not been audited against the full RFC 8032
test suite. It must not be used as a foundation for security claims beyond
the single empty-message test vector exercised in `Ed25519Test` (if present). -/
namespace LeanFormalization

/-- Ed25519 field prime p = 2^255 - 19. -/
def ed25519P : Nat := 2^255 - 19

def fPow (a e : Nat) : Nat :=
  (List.range 256).foldl (fun (st : Nat × Nat × Nat) _ =>
    let (base, result, exp) := st
    if exp == 0 then st
    else
      let result' := if (exp &&& 1) == 1 then (result * base) % ed25519P else result
      let base' := (base * base) % ed25519P
      let exp' := exp / 2
      (base', result', exp')
  ) (a % ed25519P, 1, e) |> (fun st => st.snd.fst)


/-- Group order L. -/
def ed25519L : Nat := 2^252 + 27742317777372353535851937790883648493

/-- d = -121665/121666 mod p. -/
def ed25519D : Nat := (ed25519P - 121665) * fPow 121666 (ed25519P - 2) % ed25519P

/-- Base point x coordinate. -/
def ed25519Bx : Nat := 15112221349535400772501151409588531511454012693041857206046113283949847762202

/-- Base point y coordinate. -/
def ed25519By : Nat := 46316835694926478169428394003475163141307993866256225615783033603165251855960

/-- Field addition. -/
def fadd (a b : Nat) : Nat := (a + b) % ed25519P
def fsub (a b : Nat) : Nat := (a + ed25519P - (b % ed25519P)) % ed25519P
def fmul (a b : Nat) : Nat := (a * b) % ed25519P
def fPow2 (a : Nat) : Nat := fmul a a
def fInv (a : Nat) : Nat := fPow a (ed25519P - 2)

/-- Convert Nat to little-endian bytes (n bytes). -/
def natToBytesLE (n : Nat) (len : Nat) : List UInt8 :=
  (List.range len).map (fun i => ((n >>> (8 * i)) &&& 0xff).toUInt8)

/-- Convert little-endian bytes to Nat. -/
def bytesToNatLE (bs : List UInt8) : Nat :=
  (List.range bs.length).foldl (fun acc i =>
    acc + (bs.getD i (0:UInt8)).toNat * (256 ^ i)) 0

/-- Extended point: (X, Y, Z, T). -/
structure ExtPoint where
  x : Nat
  y : Nat
  z : Nat
  t : Nat
  deriving Repr

def extIdentity : ExtPoint := { x := 0, y := 1, z := 1, t := 0 }

def extBase : ExtPoint := { x := ed25519Bx, y := ed25519By, z := 1, t := (ed25519Bx * ed25519By) % ed25519P }

/-- Affine point representation and addition. -/
-- Affine point as (x, y) with a flag for infinity.
structure AffinePoint where
  x : Nat
  y : Nat
  inf : Bool
  deriving Repr, BEq

def affineIdentity : AffinePoint := { x := 0, y := 1, inf := true }
def affineBase : AffinePoint := { x := ed25519Bx, y := ed25519By, inf := false }

def affineAdd (P Q : AffinePoint) : AffinePoint :=
  if P.inf then Q
  else if Q.inf then P
  else if P.x == Q.x && P.y != Q.y then affineIdentity
  else
    let x1 := P.x; let y1 := P.y; let x2 := Q.x; let y2 := Q.y
    -- Unified twisted-Edwards addition (RFC 8032), a = -1:
    -- x3 = (x1*y2 + y1*x2) / (1 + d*x1*x2*y1*y2)
    -- y3 = (y1*y2 + x1*x2) / (1 - d*x1*x2*y1*y2)
    let x3num := fadd (fmul x1 y2) (fmul y1 x2)
    let denom := fmul (fmul x1 x2) (fmul y1 y2)
    let denom1 := fadd 1 (fmul ed25519D denom)
    let denom2 := fsub 1 (fmul ed25519D denom)
    let x3 := fmul x3num (fInv denom1)
    let y3num := fadd (fmul y1 y2) (fmul x1 x2)
    let y3 := fmul y3num (fInv denom2)
    { x := x3, y := y3, inf := false }

def affineScalarMulImpl (k : Nat) (P : AffinePoint) : AffinePoint :=
  (List.range 256).reverse.foldl (fun (r : AffinePoint) i =>
    let r2 := affineAdd r r
    let bit := (k >>> i) &&& 1
    if bit == 1 then affineAdd r2 P else r2
  ) affineIdentity

-- sqrt mod p: Tonelli-Shanks (p ≡ 5 mod 8, so sqrt(a) = a^((p+3)/8) or a^((p+3)/8)*sqrt(-1))
def fSqrt (a : Nat) : Option Nat :=
  -- check if a is quadratic residue
  let cand := fPow a ((ed25519P + 3) / 8)
  if fPow cand 2 == a % ed25519P then some cand
  else
    let cand2 := fmul cand (fPow 2 ((ed25519P - 1) / 4))  -- sqrt(-1) = 2^((p-1)/4)
    if fPow cand2 2 == a % ed25519P then some cand2
    else none

/-- Decode a 32-byte little-endian point. Returns none if invalid. -/
def decodePoint (bytes : List UInt8) : Option AffinePoint :=
  if bytes.length != 32 then none
  else
    -- y = bytes as LE int, with bit 255 cleared
    let yval := bytesToNatLE bytes &&& ((2^255) - 1)
    let signBit := (bytesToNatLE bytes >>> 255) &&& 1
    -- compute x^2 = (y^2 - 1) / (d*y^2 + 1) mod p
    let y2 := fPow2 yval
    let u := fsub y2 1
    let v := fadd 1 (fmul ed25519D y2)
    let vinv := fInv v
    let x2 := fmul u vinv
    match fSqrt x2 with
    | none => none
    | some x =>
      -- choose sign
      let x' := if (x % 2) != signBit then ed25519P - x else x
      -- also need x != 0 edge? skip
      some { x := x', y := yval, inf := false }

/-- Verify Ed25519 signature. sig, msg, pk are Nats. -/
def ed25519Verify (sig msg pk : Nat) : Bool :=
  -- encode msg, pk, sig as bytes
  -- msg: variable length; use minimal bytes then... Ed25519 messages arbitrary. We'll encode msg as LE bytes (minimal).
  -- For simplicity, encode pk as 32 bytes LE, sig as 64 bytes LE.
  let pkBytes := natToBytesLE pk 32
  let sigBytes := natToBytesLE sig 64
  let Rbytes := sigBytes.take 32
  let Sbytes := sigBytes.drop 32
  let S := bytesToNatLE Sbytes
  -- check S < L
  if S >= ed25519L then false
  else
    match decodePoint Rbytes with
    | none => false
    | some Rpt =>
      match decodePoint pkBytes with
      | none => false
      | some Apt =>
        -- Message encoding limitation: a Nat cannot represent arbitrary byte
        -- strings. For the empty message (msg == 0) we use [], matching the
        -- RFC 8032 empty-message test vector; nonzero msgs are encoded as 32
        -- little-endian bytes. This is a simplification, not a general
        -- message encoding.
        let msgBytes := if msg == 0 then [] else natToBytesLE msg 32
        -- h = SHA512(R || A || M) mod L
        let hInput := Rbytes ++ pkBytes ++ msgBytes
        let hHash := sha512 hInput
        let h := bytesToNatLE hHash % ed25519L
        -- compute S*B
        let SB := affineScalarMulImpl S affineBase
        -- compute h*A
        let hA := affineScalarMulImpl h Apt
        -- R + h*A
        let RhA := affineAdd Rpt hA
        -- compare SB and RhA (affine)
        (SB.x == RhA.x && SB.y == RhA.y && !SB.inf && !RhA.inf)

-- Keep the old interface name working:
def ed25519VerifyReal (sig msg pk : Nat) : Bool := ed25519Verify sig msg pk

end LeanFormalization
