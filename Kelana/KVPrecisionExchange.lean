import Std

namespace Kelana.KVPrecisionExchange

/-- Quantized K positions after an after-query whole-group flush. -/
def keyPost (group t : Nat) : Nat := (t / group) * group

/-- Quantized V positions after maintaining `group` recent positions. -/
def valuePost (group t : Nat) : Nat := t - group

/-- Before this query's flush, only the previous query's aged positions exist. -/
def keyPre (group t : Nat) : Nat := keyPost group (t - 1)
def valuePre (group t : Nat) : Nat := valuePost group (t - 1)

/-- Exact chronology gap after warm-up, not a horizon-specific enumeration. -/
theorem post_gap (group t : Nat) (hg : 0 < group) (ht : group ≤ t) :
    keyPost group t = valuePost group t + (group - t % group) := by
  have hm := Nat.mod_lt t hg
  have hd : (t / group) * group + t % group = t := by
    simpa [Nat.mul_comm] using Nat.div_add_mod t group
  unfold keyPost valuePost
  omega

theorem post_order (group t : Nat) (hg : 0 < group) :
    valuePost group t ≤ keyPost group t := by
  by_cases ht : group ≤ t
  · rw [post_gap group t hg ht]
    omega
  · simp only [valuePost]
    omega

theorem post_gap_bound (group t : Nat) (hg : 0 < group) :
    keyPost group t ≤ valuePost group t + group := by
  by_cases ht : group ≤ t
  · rw [post_gap group t hg ht]
    omega
  · have hdiv : t / group = 0 := Nat.div_eq_of_lt (by omega)
    simp [keyPost, hdiv]

theorem pre_order (group t : Nat) (hg : 0 < group) :
    valuePre group t ≤ keyPre group t := post_order group (t-1) hg

theorem pre_gap_bound (group t : Nat) (hg : 0 < group) :
    keyPre group t ≤ valuePre group t + group := post_gap_bound group (t-1) hg

/-- `common` includes identical recent fields and metadata. Code byte costs
    are per quantized position; the two arms exchange them, not the metadata. -/
def bytes (common low high k v : Rat) : Rat := common + low*k + high*v

theorem exchange_difference (common low high k v : Rat) :
    bytes common high low k v - bytes common low high k v =
      (high-low)*(k-v) := by
  unfold bytes
  grind +ring

/-- Spending more code bytes on V is never larger when K has at least as
    many quantized positions. The observer error is absent from this law. -/
theorem value_heavy_no_larger (common low high k v : Rat)
    (hbits : low ≤ high) (hcount : v ≤ k) :
    bytes common low high k v ≤ bytes common high low k v := by
  have ha : 0 ≤ high-low := by grind
  have hb : 0 ≤ k-v := by grind
  have hp := Rat.mul_nonneg ha hb
  have he := exchange_difference common low high k v
  grind

/-- The actual integral byte ledger, including its chronology premises. -/
theorem nat_exchange_difference (common low high k v : Nat)
    (hbits : low ≤ high) (hcount : v ≤ k) :
    common + high*k + low*v =
      common + low*k + high*v + (high-low)*(k-v) := by
  have hb := Nat.sub_add_cancel hbits
  have hc := Nat.sub_add_cancel hcount
  grind +ring

theorem post_value_heavy_no_larger (group t common low high : Nat)
    (hg : 0 < group) (hbits : low ≤ high) :
    common + low*keyPost group t + high*valuePost group t ≤
      common + high*keyPost group t + low*valuePost group t := by
  rw [nat_exchange_difference common low high (keyPost group t)
    (valuePost group t) hbits (post_order group t hg)]
  omega

theorem pre_value_heavy_no_larger (group t common low high : Nat)
    (hg : 0 < group) (hbits : low ≤ high) :
    common + low*keyPre group t + high*valuePre group t ≤
      common + high*keyPre group t + low*valuePre group t :=
  post_value_heavy_no_larger group (t-1) common low high hg hbits

/-- Instantiation: complete eight-head code-byte differences at t256,
    with identical source/recent/metadata fields cancelling. -/
theorem original_256_counts :
    keyPre 32 256 = 224 ∧ valuePre 32 256 = 223 ∧
    keyPost 32 256 = 256 ∧ valuePost 32 256 = 224 := by decide

theorem original_pre_exchange (common : Rat) :
    8 * (bytes common 64 32 224 223 - bytes common 32 64 224 223) = 256 := by
  unfold bytes
  grind +ring

theorem original_post_exchange (common : Rat) :
    8 * (bytes common 64 32 256 224 - bytes common 32 64 256 224) = 8192 := by
  unfold bytes
  grind +ring

end Kelana.KVPrecisionExchange
