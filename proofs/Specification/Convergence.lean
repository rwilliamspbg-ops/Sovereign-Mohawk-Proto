namespace Specification


def envelope (k t : Nat) (zeta : Float) : Float :=
  zeta * zeta + (1000000.0 / (Float.ofNat (k * t + 1)))


theorem envelope_refl (k t : Nat) (zeta : Float) :
    envelope k t zeta = envelope k t zeta := by
  rfl

end Specification
