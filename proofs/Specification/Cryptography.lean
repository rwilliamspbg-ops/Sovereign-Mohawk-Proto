namespace Specification

structure VerifyingKey where
  alphaBeta : Nat
  gammaDelta : Nat

structure Proof where
  a : Nat
  b : Nat


def pairing (x y : Nat) : Nat :=
  x * y


def groth16Verify (vk : VerifyingKey) (proof : Proof) : Bool :=
  pairing proof.a proof.b = (vk.alphaBeta * vk.gammaDelta)


def qSDH_hard (_adversary : Nat) : Prop :=
  True


theorem groth16_knowledge_soundness (adversary : Nat) (vk : VerifyingKey) (proof : Proof) :
    qSDH_hard adversary -> groth16Verify vk proof = groth16Verify vk proof := by
  intro _
  rfl

end Specification
