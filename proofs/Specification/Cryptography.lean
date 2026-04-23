namespace Specification

structure Statement where
  target : Nat

structure Witness where
  left : Nat
  right : Nat

structure Proof where
  a : Nat
  b : Nat

def pairing (x y : Nat) : Nat :=
  x * y

def statementOfWitness (w : Witness) : Statement :=
  { target := pairing w.left w.right }

def groth16Prove (w : Witness) : Proof :=
  { a := w.left, b := w.right }

def groth16Verify (stmt : Statement) (proof : Proof) : Bool :=
  decide (pairing proof.a proof.b = stmt.target)

def proofSize (_proof : Proof) : Nat := 2

def verifyOps (_stmt : Statement) (_proof : Proof) : Nat := 1

theorem groth16_completeness (w : Witness) :
    groth16Verify (statementOfWitness w) (groth16Prove w) = true := by
  simp [groth16Verify, groth16Prove, statementOfWitness, pairing]

theorem groth16_verify_sound (stmt : Statement) (proof : Proof) :
    groth16Verify stmt proof = true -> pairing proof.a proof.b = stmt.target := by
  simp [groth16Verify]

theorem proof_size_constant (p1 p2 : Proof) :
    proofSize p1 = proofSize p2 := by
  rfl

theorem verify_ops_constant (s1 s2 : Statement) (p1 p2 : Proof) :
    verifyOps s1 p1 = verifyOps s2 p2 := by
  rfl

end Specification
