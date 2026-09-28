import Kelana.SignOrbitConsumer

namespace Kelana.SimdTernaryConsumer

open FiberRank

/-- `Int.natAbs` is the exact natural-number magnitude used by the range
contracts below. -/
theorem bounds_of_natAbs_le {x : Int} {bound : Nat}
    (h : x.natAbs ≤ bound) :
    -(bound : Int) ≤ x ∧ x ≤ bound := by
  cases x <;> simp_all <;> omega

/-- A ternary dot response cannot have greater magnitude than the sum of the
query-coordinate magnitudes. -/
theorem response_natAbs_le (weights : List Trit) (query : List Int) (bound : Nat)
    (sameLength : weights.length = query.length)
    (coordinateBound : ∀ x ∈ query, x.natAbs ≤ bound) :
    (response weights query).natAbs ≤ bound * weights.length := by
  induction weights generalizing query with
  | nil =>
      have queryNil : query = [] := List.eq_nil_of_length_eq_zero (by simpa using sameLength.symm)
      subst query
      simp [response]
  | cons trit weights ih =>
      cases query with
      | nil => simp at sameLength
      | cons coefficient query =>
          have tailLength : weights.length = query.length := by simpa using sameLength
          have headBound : coefficient.natAbs ≤ bound := coordinateBound coefficient (by simp)
          have tailBound : ∀ x ∈ query, x.natAbs ≤ bound := by
            intro x hx
            exact coordinateBound x (by simp [hx])
          have tailResponseBound := ih query tailLength tailBound
          cases trit <;>
            simp only [response, Trit.value, Int.neg_one_mul, Int.zero_mul, Int.zero_add,
              Int.one_mul]
          · calc
              (-coefficient + response weights query).natAbs ≤
                  (-coefficient).natAbs + (response weights query).natAbs :=
                Int.natAbs_add_le _ _
              _ ≤ bound + bound * weights.length :=
                Nat.add_le_add (by simpa using headBound) tailResponseBound
              _ = bound * (Trit.neg :: weights).length := by
                simp [Nat.mul_add, Nat.add_comm]
          · exact Nat.le_trans tailResponseBound (by
              simp only [List.length_cons]
              exact Nat.mul_le_mul_left bound (Nat.le_succ weights.length))
          · calc
              (coefficient + response weights query).natAbs ≤
                  coefficient.natAbs + (response weights query).natAbs :=
                Int.natAbs_add_le _ _
              _ ≤ bound + bound * weights.length :=
                Nat.add_le_add headBound tailResponseBound
              _ = bound * (Trit.pos :: weights).length := by
                simp [Nat.mul_add, Nat.add_comm]

/-- The same range contract applies to every coordinate prefix. -/
theorem response_prefix_natAbs_le (weights : List Trit) (query : List Int)
    (bound prefixLength : Nat) (sameLength : weights.length = query.length)
    (coordinateBound : ∀ x ∈ query, x.natAbs ≤ bound) :
    (response (weights.take prefixLength) (query.take prefixLength)).natAbs ≤
      bound * (weights.take prefixLength).length := by
  apply response_natAbs_le
  · simp [List.length_take, sameLength]
  · intro x hx
    exact coordinateBound x (List.mem_of_mem_take hx)

/-- The mathematical signed-int8 query contract. It includes `-128`, whose
magnitude is 128. -/
def SignedInt8 (x : Int) : Prop := -128 ≤ x ∧ x ≤ 127

theorem signedInt8_natAbs_le (x : Int) (h : SignedInt8 x) : x.natAbs ≤ 128 := by
  cases x <;> simp_all [SignedInt8] <;> omega

/-- A 128-column ternary dot response on signed-int8 input has magnitude at
most 16384. Both endpoints fit signed 16-bit storage. -/
theorem response_128_signedInt8_bound (weights : List Trit) (query : List Int)
    (sameLength : weights.length = query.length)
    (columns : weights.length ≤ 128)
    (queryBound : ∀ x ∈ query, SignedInt8 x) :
    (response weights query).natAbs ≤ 16384 := by
  have h := response_natAbs_le weights query 128 sameLength (by
    intro x hx
    exact signedInt8_natAbs_le x (queryBound x hx))
  omega

structure Chunk where
  weights : List Trit
  query : List Int

namespace Chunk

def ValidSignedInt8 (chunk : Chunk) : Prop :=
  chunk.weights.length = chunk.query.length ∧
    ∀ x ∈ chunk.query, SignedInt8 x

def response (chunk : Chunk) : Int :=
  FiberRank.response chunk.weights chunk.query

end Chunk

/-- Sum the independently looked-up responses for consecutive chunks. -/
def accumulatedResponse : List Chunk → Int
  | [] => 0
  | chunk :: chunks => chunk.response + accumulatedResponse chunks

/-- Number of original coordinates represented by a chunk list. -/
def accumulatedWidth : List Chunk → Nat
  | [] => 0
  | chunk :: chunks => chunk.weights.length + accumulatedWidth chunks

/-- Every intermediate chunk accumulation obeys the bound for the number of
coordinates consumed so far. -/
theorem accumulatedResponse_bound (chunks : List Chunk)
    (valid : ∀ chunk ∈ chunks, chunk.ValidSignedInt8) :
    (accumulatedResponse chunks).natAbs ≤ 128 * accumulatedWidth chunks := by
  induction chunks with
  | nil => simp [accumulatedResponse, accumulatedWidth]
  | cons chunk chunks ih =>
      have chunkValid := valid chunk (by simp)
      have chunkBound : chunk.response.natAbs ≤ 128 * chunk.weights.length := by
        exact response_natAbs_le chunk.weights chunk.query 128 chunkValid.1 (by
          intro x hx
          exact signedInt8_natAbs_le x (chunkValid.2 x hx))
      have tailValid : ∀ tail ∈ chunks, tail.ValidSignedInt8 := by
        intro tail htail
        exact valid tail (by simp [htail])
      calc
        (accumulatedResponse (chunk :: chunks)).natAbs ≤
            chunk.response.natAbs + (accumulatedResponse chunks).natAbs := by
          simpa [accumulatedResponse] using
            Int.natAbs_add_le chunk.response (accumulatedResponse chunks)
        _ ≤ 128 * chunk.weights.length + 128 * accumulatedWidth chunks :=
          Nat.add_le_add chunkBound (ih tailValid)
        _ = 128 * accumulatedWidth (chunk :: chunks) := by
          simp [accumulatedWidth]
          omega

theorem accumulatedWidth_take_le (chunks : List Chunk) (prefixChunks : Nat) :
    accumulatedWidth (chunks.take prefixChunks) ≤ accumulatedWidth chunks := by
  induction chunks generalizing prefixChunks with
  | nil => simp [accumulatedWidth]
  | cons chunk chunks ih =>
      cases prefixChunks with
      | zero => simp [accumulatedWidth]
      | succ prefixChunks =>
          simp only [List.take_succ_cons, accumulatedWidth]
          have tailBound := ih prefixChunks
          omega

/-- For a 128-column row, every chunk prefix fits the same signed-16 range.
This covers the 43 successive accumulations of a 3-trit chunking. -/
theorem every_chunk_prefix_128_bound (chunks : List Chunk)
    (valid : ∀ chunk ∈ chunks, chunk.ValidSignedInt8)
    (totalWidth : accumulatedWidth chunks ≤ 128)
    (prefixChunks : Nat) :
    (accumulatedResponse (chunks.take prefixChunks)).natAbs ≤ 16384 := by
  have prefixValid : ∀ chunk ∈ chunks.take prefixChunks, chunk.ValidSignedInt8 := by
    intro chunk hchunk
    exact valid chunk (List.mem_of_mem_take hchunk)
  have prefixBound := accumulatedResponse_bound (chunks.take prefixChunks) prefixValid
  have prefixWidth := accumulatedWidth_take_le chunks prefixChunks
  omega

/-- The concrete 43-chunk partition has the preceding prefix guarantee. The
range depends on its 128 coordinates, not on the chunk count itself. -/
theorem forty_three_chunk_prefix_bound (chunks : List Chunk)
    (_chunkCount : chunks.length = 43)
    (valid : ∀ chunk ∈ chunks, chunk.ValidSignedInt8)
    (totalWidth : accumulatedWidth chunks = 128)
    (prefixChunks : Nat) :
    (accumulatedResponse (chunks.take prefixChunks)).natAbs ≤ 16384 := by
  exact every_chunk_prefix_128_bound chunks valid (by omega) prefixChunks

/-- Join two little-endian bytes into their 16-bit word. The `BitVec 8` input
types make both byte ranges explicit. -/
def wordFromBytes (low high : BitVec 8) : BitVec 16 :=
  high ++ low

def lowByte (word : BitVec 16) : BitVec 8 := word.extractLsb' 0 8

def highByte (word : BitVec 16) : BitVec 8 := word.extractLsb' 8 8

theorem byte_value_lt_256 (byte : BitVec 8) : byte.toNat < 256 := by
  exact byte.isLt

/-- Splitting and little-endian joining preserve every 16-bit word. -/
theorem wordFromBytes_parts (word : BitVec 16) :
    wordFromBytes (lowByte word) (highByte word) = word := by
  exact BitVec.extractLsb'_append_extractLsb'

/-- Signed interpretation of a little-endian byte pair. -/
def signed16FromBytes (low high : BitVec 8) : Int :=
  (wordFromBytes low high).toInt

/-- A response in `[-16384, 16384]` survives signed-16 byte storage exactly. -/
theorem signed16_bytes_exact (responseValue : Int)
    (lower : -16384 ≤ responseValue) (upper : responseValue ≤ 16384) :
    signed16FromBytes (lowByte (BitVec.ofInt 16 responseValue))
      (highByte (BitVec.ofInt 16 responseValue)) = responseValue := by
  rw [signed16FromBytes, wordFromBytes_parts]
  exact BitVec.toInt_ofInt_eq_self (w := 16) (by decide) (by omega) (by omega)

def applySign (negative : Bool) (value : Int) : Int :=
  if negative then -value else value

/-- Encode the sign-orbit orientation as the Boolean consumed by the SIMD
sign operation. -/
def orbitNegative (n c : Nat) : Bool :=
  if c ≤ n - 1 - c then false else true

theorem applySign_orbit_orientation (n c : Nat) (value : Int) :
    applySign (orbitNegative n c) value =
      SignOrbitConsumer.orientation n c * value := by
  by_cases h : c ≤ n - 1 - c <;>
    simp [orbitNegative, SignOrbitConsumer.orientation, applySign, h]

/-- `lookup_fold` followed by the Boolean sign operation returns the original
table entry. -/
theorem lookup_fold_applySign (n c : Nat) (table : Nat → Int)
    (codeInRange : c < n)
    (antisymmetric : ∀ j, j < n → table (n - 1 - j) = -table j) :
    table c = applySign (orbitNegative n c)
      (table (SignOrbitConsumer.folded n c)) := by
  rw [applySign_orbit_orientation]
  exact SignOrbitConsumer.lookup_fold n c table codeInRange antisymmetric

/-- Apply a separate sign in a 16-bit lane with the standard XOR/subtract
identity. A false sign uses mask `0`; a true sign uses mask `0xffff`. -/
def xorSubtractSign (negative : Bool) (word : BitVec 16) : BitVec 16 :=
  let mask : BitVec 16 := if negative then -1 else 0
  (word ^^^ mask) - mask

theorem xorSubtractSign_eq (negative : Bool) (word : BitVec 16) :
    xorSubtractSign negative word = if negative then -word else word := by
  cases negative
  · simp [xorSubtractSign]
  · simp only [xorSubtractSign, ↓reduceIte]
    have negativeOne : (-1 : BitVec 16) = BitVec.allOnes 16 :=
      BitVec.neg_one_eq_allOnes
    have xorNegativeOne : word ^^^ (-1) = ~~~word := by
      rw [negativeOne]
      exact BitVec.xor_allOnes
    rw [xorNegativeOne, BitVec.sub_eq_add_neg]
    simp [BitVec.neg_eq_not_add]

/-- XOR/subtract applies the requested sign exactly throughout the response
range. Negating either endpoint still fits signed 16-bit interpretation. -/
theorem xorSubtractSign_exact (negative : Bool) (responseValue : Int)
    (lower : -16384 ≤ responseValue) (upper : responseValue ≤ 16384) :
    (xorSubtractSign negative (BitVec.ofInt 16 responseValue)).toInt =
      applySign negative responseValue := by
  rw [xorSubtractSign_eq]
  cases negative with
  | false =>
      change (BitVec.ofInt 16 responseValue).toInt = responseValue
      exact BitVec.toInt_ofInt_eq_self (w := 16) (by decide) (by omega) (by omega)
  | true =>
      change (-BitVec.ofInt 16 responseValue).toInt = -responseValue
      rw [← BitVec.ofInt_neg]
      exact BitVec.toInt_ofInt_eq_self (w := 16) (by decide) (by omega) (by omega)

/-- Every bounded 128-column response can be split into two table bytes and
reconstructed without changing its integer value. -/
theorem response_signed16_bytes_exact (weights : List Trit) (query : List Int)
    (sameLength : weights.length = query.length)
    (columns : weights.length ≤ 128)
    (queryBound : ∀ x ∈ query, SignedInt8 x) :
    signed16FromBytes (lowByte (BitVec.ofInt 16 (response weights query)))
      (highByte (BitVec.ofInt 16 (response weights query))) = response weights query := by
  have magnitude := response_128_signedInt8_bound weights query sameLength columns queryBound
  have range := bounds_of_natAbs_le magnitude
  exact signed16_bytes_exact (response weights query) (by omega) (by omega)

/-- Every intermediate chunk accumulation also round-trips through signed-16
bytes. This rules out silent truncation at any of the 43 accumulation steps. -/
theorem every_chunk_prefix_signed16_exact (chunks : List Chunk)
    (valid : ∀ chunk ∈ chunks, chunk.ValidSignedInt8)
    (totalWidth : accumulatedWidth chunks ≤ 128)
    (prefixChunks : Nat) :
    signed16FromBytes
      (lowByte (BitVec.ofInt 16 (accumulatedResponse (chunks.take prefixChunks))))
      (highByte (BitVec.ofInt 16 (accumulatedResponse (chunks.take prefixChunks)))) =
        accumulatedResponse (chunks.take prefixChunks) := by
  have magnitude := every_chunk_prefix_128_bound chunks valid totalWidth prefixChunks
  have range := bounds_of_natAbs_le magnitude
  exact signed16_bytes_exact (accumulatedResponse (chunks.take prefixChunks))
    (by omega) (by omega)

/-- A folded-table response reconstructed from bytes and then sign-corrected is
exact. `negative` is the separately computed sign-orbit orientation. -/
theorem folded_signed16_bytes_exact (negative : Bool) (representative : Int)
    (lower : -16384 ≤ representative) (upper : representative ≤ 16384) :
    (xorSubtractSign negative
      (wordFromBytes (lowByte (BitVec.ofInt 16 representative))
        (highByte (BitVec.ofInt 16 representative)))).toInt =
      applySign negative representative := by
  rw [wordFromBytes_parts]
  exact xorSubtractSign_exact negative representative lower upper

end Kelana.SimdTernaryConsumer
