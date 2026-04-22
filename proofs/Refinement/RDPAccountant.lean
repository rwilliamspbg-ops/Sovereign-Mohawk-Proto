import Specification.Privacy

namespace Refinement

open Specification


def accountantSpec (steps : List (Float × Float)) : Float :=
  composeRDP steps


def accountantImpl (steps : List (Float × Float)) : Float :=
  rdpAccountant steps


theorem accountant_impl_refines_spec (steps : List (Float × Float)) :
    accountantImpl steps = accountantSpec steps := by
  rfl

end Refinement
