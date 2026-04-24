namespace Specification

abbrev FloatArray := List Float

structure Node where
  id : Nat
  gradient : FloatArray
  isByzantine : Bool

structure Swarm where
  nodes : List Node
  krumNeighbors : Nat
  dimension : Nat

structure Message where
  sender : Nat
  payload : List UInt8
  size : Nat

structure RDPState where
  alpha : Float
  totalEpsilon : Float
  targetDelta : Float


def honestNodes (nodes : List Node) : List Node :=
  nodes.filter (fun n => not n.isByzantine)


def addVector (a b : FloatArray) : FloatArray :=
  List.zipWith (fun x y => x + y) a b


def scaleVector (c : Float) (v : FloatArray) : FloatArray :=
  v.map (fun x => c * x)


def sqDist (a b : FloatArray) : Float :=
  (List.zipWith (fun x y =>
    let d := x - y
    d * d) a b).foldl (fun acc x => acc + x) 0.0


def getAt? {a : Type} : List a -> Nat -> Option a
  | [], _ => none
  | x :: _, 0 => some x
  | _ :: xs, n + 1 => getAt? xs n


def insertSorted (x : Float) : List Float -> List Float
  | [] => [x]
  | y :: ys =>
      if x <= y then
        x :: y :: ys
      else
        y :: insertSorted x ys


def sortAsc : List Float -> List Float
  | [] => []
  | x :: xs => insertSorted x (sortAsc xs)


def honestGradient (nodes : List Node) : Option FloatArray :=
  match honestNodes nodes with
  | [] => none
  | first :: rest =>
      let sum := rest.foldl (fun acc n => addVector acc n.gradient) first.gradient
      let count := Float.ofNat (rest.length + 1)
      some (scaleVector (1.0 / count) sum)


def neighborScore (gradients : List FloatArray) (idx k : Nat) : Float :=
  match getAt? gradients idx with
  | none => 0.0
  | some g =>
      let dists := (List.range gradients.length).foldl
        (fun acc j =>
          if j = idx then acc
          else match getAt? gradients j with
               | none => acc
               | some h => sqDist g h :: acc)
        []
      let smallest := (sortAsc dists).take k
      smallest.foldl (fun acc x => acc + x) 0.0


def argminAux (rest : List Float) (bestIdx idx : Nat) (best : Float) : Nat :=
  match rest with
  | [] => bestIdx
  | x :: xs =>
      if x < best then
        argminAux xs idx (idx + 1) x
      else
        argminAux xs bestIdx (idx + 1) best


def argmin? (xs : List Float) : Option Nat :=
  match xs with
  | [] => none
  | x :: rest => some (argminAux rest 0 1 x)


def multiKrumSelectImpl (nodes : List Node) (k : Nat) : Option FloatArray :=
  let gradients := nodes.map Node.gradient
  if gradients.isEmpty then
    none
  else
    let neighbors := Nat.min k (gradients.length - 1)
    let scores := (List.range gradients.length).map (fun i => neighborScore gradients i neighbors)
    match argmin? scores with
    | none => none
    | some idx => getAt? gradients idx


def totalBytes (messages : List Message) : Nat :=
  messages.foldl (fun acc m => acc + m.size) 0


def rdpCompose (steps : List Float) : Float :=
  steps.foldl (fun acc x => acc + x) 0.0

end Specification
