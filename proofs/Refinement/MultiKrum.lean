import Specification.System

namespace Refinement

open Specification


def krumSpec (nodes : List Node) (k : Nat) : Option Specification.FloatArray :=
  multiKrumSelectImpl nodes k


def krumImpl (nodes : List Node) (k : Nat) : Option Specification.FloatArray :=
  multiKrumSelectImpl nodes k


theorem krum_impl_refines_spec (nodes : List Node) (k : Nat) :
    krumImpl nodes k = krumSpec nodes k := by
  rfl

end Refinement
