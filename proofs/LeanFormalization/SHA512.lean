import Mathlib

namespace LeanFormalization

/-- SHA-512 implementation (RFC 6234). Operates on byte lists. -/

def sha512K : Array UInt64 := #[
  0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
  0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
  0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
  0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
  0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
  0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
  0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
  0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
  0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
  0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
  0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
  0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
  0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
  0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
  0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
  0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
  0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
  0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
  0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
  0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817
]

def rotr64 (x : UInt64) (n : Nat) : UInt64 :=
  (x >>> n.toUInt64) ||| (x <<< ((64 - n).toUInt64))

def sha512Ch (x y z : UInt64) : UInt64 := (x &&& y) ^^^ (~~~x &&& z)
def sha512Maj (x y z : UInt64) : UInt64 := (x &&& y) ^^^ (x &&& z) ^^^ (y &&& z)
def sha512Sigma0 (x : UInt64) : UInt64 := rotr64 x 28 ^^^ rotr64 x 34 ^^^ rotr64 x 39
def sha512Sigma1 (x : UInt64) : UInt64 := rotr64 x 14 ^^^ rotr64 x 18 ^^^ rotr64 x 41
def sha512sigma0 (x : UInt64) : UInt64 := rotr64 x 1 ^^^ rotr64 x 8 ^^^ (x >>> 7)
def sha512sigma1 (x : UInt64) : UInt64 := rotr64 x 19 ^^^ rotr64 x 61 ^^^ (x >>> 6)

def bytesToUInt64BE (bs : List UInt8) : UInt64 :=
  bs.foldl (fun acc b => (acc <<< 8) ||| (b.toUInt64)) 0

def uint64ToBytesBE (x : UInt64) : List UInt8 :=
  [ ((x >>> 56) &&& 0xff).toUInt8,
    ((x >>> 48) &&& 0xff).toUInt8,
    ((x >>> 40) &&& 0xff).toUInt8,
    ((x >>> 32) &&& 0xff).toUInt8,
    ((x >>> 24) &&& 0xff).toUInt8,
    ((x >>> 16) &&& 0xff).toUInt8,
    ((x >>> 8) &&& 0xff).toUInt8,
    (x &&& 0xff).toUInt8 ]

def sha512Pad (msg : List UInt8) : List UInt8 :=
  let bitLen := msg.length * 8
  let msg' := msg ++ [(0x80 : UInt8)]
  let zerosNeeded := (112 - (msg'.length % 128) + 128) % 128
  let padded := msg' ++ (List.replicate zerosNeeded (0 : UInt8))
  let hi := 0  -- upper 64 bits (0 for our sizes)
  let lo := bitLen
  padded ++ uint64ToBytesBE (hi.toUInt64) ++ uint64ToBytesBE (lo.toUInt64)

def sha512ProcessChunk (H : Array UInt64) (chunk : List UInt8) : Array UInt64 :=
  let words := (List.range 16).map (fun i =>
    bytesToUInt64BE (chunk.drop (i*8) |>.take 8))
  let W : Array UInt64 := (List.range 80).foldl (fun (acc : Array UInt64) t =>
    if t < 16 then
      acc.push (words.getD t (0 : UInt64))
    else
      let w15 := acc.getD (t-15) (0 : UInt64)
      let w2 := acc.getD (t-2) (0 : UInt64)
      let w7 := acc.getD (t-7) (0 : UInt64)
      let w16 := acc.getD (t-16) (0 : UInt64)
      let val := sha512sigma1 w2 + w7 + sha512sigma0 w15 + w16
      acc.push val
  ) (#[] : Array UInt64)
  let a0 := H[0]!; let b0 := H[1]!; let c0 := H[2]!; let d0 := H[3]!
  let e0 := H[4]!; let f0 := H[5]!; let g0 := H[6]!; let h0 := H[7]!
  let (a,b,c,d,e,f,g,h) := (List.range 80).foldl (fun (st : UInt64 × UInt64 × UInt64 × UInt64 × UInt64 × UInt64 × UInt64 × UInt64) t =>
    let (a,b,c,d,e,f,g,h) := st
    let T1 := h + sha512Sigma1 e + sha512Ch e f g + sha512K[t]! + W[t]!
    let T2 := sha512Sigma0 a + sha512Maj a b c
    (T1 + T2, a, b, c, d + T1, e, f, g)
  ) (a0,b0,c0,d0,e0,f0,g0,h0)
  #[a0+a, b0+b, c0+c, d0+d, e0+e, f0+f, g0+g, h0+h]

def sha512 (msg : List UInt8) : List UInt8 :=
  let H0 : Array UInt64 := #[0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
                             0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179]
  let padded := sha512Pad msg
  let H := (List.range (padded.length / 128)).foldl (fun H i =>
    sha512ProcessChunk H (padded.drop (i*128) |>.take 128)
  ) H0
  H.foldl (fun acc w => acc ++ uint64ToBytesBE w) []

end LeanFormalization
