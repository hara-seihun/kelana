import Std

/-!
# Anytime search certificates

A minimization search can stop with a sound interval even when the candidate type
is infinite. The checker needs a feasible incumbent, a cover by candidates
already examined and unresolved regions, and a sound lower bound for each
region. The objective is a `Nat`; callers may add storage, priced online work,
and consumer distortion before supplying it here.
-/

namespace Kelana.QuantizationCertificates

/-- A minimization problem. No enumeration or finiteness assumption is attached
to the candidate type. -/
structure Problem (Candidate : Type) where
  feasible : Candidate → Prop
  objective : Candidate → Nat

/-- Region bounds are local facts. `sound` says what a region lower bound means;
it does not assume a global lower bound. -/
structure RegionBounds {Candidate : Type} (p : Problem Candidate) (Region : Type) where
  contains : Region → Candidate → Prop
  lower : Region → Nat
  sound : ∀ r c, p.feasible c → contains r c → lower r ≤ p.objective c

/-- Transport a lower bound through a no-worse representative. This is the
interface needed by dominance or simulation results; the certificate module
does not prescribe how the representative is obtained. -/
theorem lowerThroughRepresentative {Candidate : Type} {p : Problem Candidate}
    {lower : Nat} {representative candidate : Candidate}
    (hfloor : lower ≤ p.objective representative)
    (hnoWorse : p.objective representative ≤ p.objective candidate) :
    lower ≤ p.objective candidate :=
  Nat.le_trans hfloor hnoWorse

/-- Build region bounds from representative candidates. The representative may
depend on the covered candidate, as it does when a dominated prefix transports
each completion to a no-worse completion. -/
def RegionBounds.ofRepresentatives {Candidate Region : Type} (p : Problem Candidate)
    (contains : Region → Candidate → Prop) (lower : Region → Nat)
    (representative : ∀ r c, p.feasible c → contains r c → Candidate)
    (representativeFloor : ∀ r c (hc : p.feasible c) (hrc : contains r c),
      lower r ≤ p.objective (representative r c hc hrc))
    (noWorse : ∀ r c (hc : p.feasible c) (hrc : contains r c),
      p.objective (representative r c hc hrc) ≤ p.objective c) :
    RegionBounds p Region where
  contains := contains
  lower := lower
  sound := by
    intro r c hc hrc
    exact lowerThroughRepresentative
      (representativeFloor r c hc hrc) (noWorse r c hc hrc)

/-- The search frontier after any bounded amount of work. Every feasible
candidate is either an examined candidate or remains in an unresolved region. -/
structure Frontier {Candidate Region : Type} (p : Problem Candidate)
    (bounds : RegionBounds p Region) where
  explored : List Candidate
  unresolved : List Region
  cover : ∀ c, p.feasible c →
    c ∈ explored ∨ ∃ r, r ∈ unresolved ∧ bounds.contains r c

/-- A concrete feasible candidate. Its objective is an upper bound on the
unknown optimum. -/
structure Incumbent {Candidate : Type} (p : Problem Candidate) where
  candidate : Candidate
  feasible : p.feasible candidate

/-- A checkable anytime certificate. The two floor fields are local obligations:
examined candidates meet `lower`, and every unresolved region has a region bound
at least `lower`. -/
structure Certificate {Candidate Region : Type} (p : Problem Candidate)
    (bounds : RegionBounds p Region) where
  frontier : Frontier p bounds
  incumbent : Incumbent p
  lower : Nat
  exploredFloor : ∀ c, c ∈ frontier.explored → p.feasible c → lower ≤ p.objective c
  unresolvedFloor : ∀ r, r ∈ frontier.unresolved → lower ≤ bounds.lower r

/-- A candidate attains the minimum over all feasible candidates. -/
def Optimal {Candidate : Type} (p : Problem Candidate) (c : Candidate) : Prop :=
  p.feasible c ∧ ∀ d, p.feasible d → p.objective c ≤ p.objective d

/-- Local coverage and local region bounds imply the advertised global lower
bound. This also applies when the candidate type is infinite. -/
theorem Certificate.globalLower {Candidate Region : Type} {p : Problem Candidate}
    {bounds : RegionBounds p Region} (cert : Certificate p bounds) :
    ∀ c, p.feasible c → cert.lower ≤ p.objective c := by
  intro c hc
  rcases cert.frontier.cover c hc with hexplored | ⟨r, hr, hrc⟩
  · exact cert.exploredFloor c hexplored hc
  · exact Nat.le_trans (cert.unresolvedFloor r hr) (bounds.sound r c hc hrc)

/-- The certificate's lower endpoint bounds every feasible objective, while its
incumbent supplies the upper endpoint. -/
theorem Certificate.globalInterval {Candidate Region : Type} {p : Problem Candidate}
    {bounds : RegionBounds p Region} (cert : Certificate p bounds) :
    cert.lower ≤ p.objective cert.incumbent.candidate ∧
      (∀ c, p.feasible c → cert.lower ≤ p.objective c) ∧
      ∃ c, p.feasible c ∧ p.objective c ≤ p.objective cert.incumbent.candidate := by
  refine ⟨cert.globalLower cert.incumbent.candidate cert.incumbent.feasible,
    cert.globalLower, cert.incumbent.candidate, cert.incumbent.feasible, Nat.le_refl _⟩

/-- When the admissible lower bound meets the incumbent cost, the incumbent is
optimal. -/
theorem Certificate.optimalOfBoundsMeet {Candidate Region : Type}
    {p : Problem Candidate} {bounds : RegionBounds p Region}
    (cert : Certificate p bounds)
    (hmeet : cert.lower = p.objective cert.incumbent.candidate) :
    Optimal p cert.incumbent.candidate := by
  refine ⟨cert.incumbent.feasible, ?_⟩
  intro c hc
  rw [← hmeet]
  exact cert.globalLower c hc

/-- A region whose lower bound reaches the incumbent cannot contain a strictly
better feasible candidate, so pruning it is safe. -/
theorem Certificate.safePrune {Candidate Region : Type}
    {p : Problem Candidate} {bounds : RegionBounds p Region}
    (cert : Certificate p bounds) (r : Region)
    (hbound : p.objective cert.incumbent.candidate ≤ bounds.lower r) :
    ∀ c, p.feasible c → bounds.contains r c →
      ¬ p.objective c < p.objective cert.incumbent.candidate := by
  intro c hc hrc himproves
  have hlocal := bounds.sound r c hc hrc
  exact (Nat.not_lt_of_ge (Nat.le_trans hbound hlocal)) himproves

/-- Replace the incumbent by any no-worse feasible candidate. The frontier and
all lower-bound evidence remain valid. -/
def Certificate.improve {Candidate Region : Type}
    {p : Problem Candidate} {bounds : RegionBounds p Region}
    (cert : Certificate p bounds) (next : Candidate) (hfeasible : p.feasible next)
    (_hbetter : p.objective next ≤ p.objective cert.incumbent.candidate) :
    Certificate p bounds where
  frontier := cert.frontier
  incumbent := ⟨next, hfeasible⟩
  lower := cert.lower
  exploredFloor := cert.exploredFloor
  unresolvedFloor := cert.unresolvedFloor

@[simp] theorem Certificate.improve_lower {Candidate Region : Type}
    {p : Problem Candidate} {bounds : RegionBounds p Region}
    (cert : Certificate p bounds) (next : Candidate) (hfeasible : p.feasible next)
    (hbetter : p.objective next ≤ p.objective cert.incumbent.candidate) :
    (cert.improve next hfeasible hbetter).lower = cert.lower := rfl

@[simp] theorem Certificate.improve_upper {Candidate Region : Type}
    {p : Problem Candidate} {bounds : RegionBounds p Region}
    (cert : Certificate p bounds) (next : Candidate) (hfeasible : p.feasible next)
    (hbetter : p.objective next ≤ p.objective cert.incumbent.candidate) :
    p.objective (cert.improve next hfeasible hbetter).incumbent.candidate ≤
      p.objective cert.incumbent.candidate := hbetter

/-- Replace one unresolved region by examined candidates and child regions. The
replacement must cover every feasible candidate formerly covered by the parent.
The resulting frontier remains a cover. -/
def Certificate.refine {Candidate Region : Type} [DecidableEq Region]
    {p : Problem Candidate} {bounds : RegionBounds p Region}
    (cert : Certificate p bounds) (parent : Region)
    (newlyExplored : List Candidate) (children : List Region)
    (replacementCover : ∀ c, p.feasible c → bounds.contains parent c →
      c ∈ newlyExplored ∨ ∃ r, r ∈ children ∧ bounds.contains r c)
    (newExploredFloor : ∀ c, c ∈ newlyExplored → p.feasible c →
      cert.lower ≤ p.objective c)
    (childFloor : ∀ r, r ∈ children → cert.lower ≤ bounds.lower r) :
    Certificate p bounds where
  frontier := {
    explored := newlyExplored ++ cert.frontier.explored
    unresolved := children ++ cert.frontier.unresolved.filter (· ≠ parent)
    cover := by
      intro c hc
      rcases cert.frontier.cover c hc with hexplored | ⟨r, hr, hrc⟩
      · exact Or.inl (by simp [hexplored])
      · by_cases hparent : r = parent
        · subst r
          rcases replacementCover c hc hrc with hnew | ⟨child, hchild, hcontains⟩
          · exact Or.inl (by simp [hnew])
          · exact Or.inr ⟨child, by simp [hchild], hcontains⟩
        · exact Or.inr ⟨r, by simp [hr, hparent], hrc⟩
  }
  incumbent := cert.incumbent
  lower := cert.lower
  exploredFloor := by
    intro c hc hfeasible
    simp only [List.mem_append] at hc
    rcases hc with hnew | hold
    · exact newExploredFloor c hnew hfeasible
    · exact cert.exploredFloor c hold hfeasible
  unresolvedFloor := by
    intro r hr
    simp only [List.mem_append] at hr
    rcases hr with hchild | hold
    · exact childFloor r hchild
    · exact cert.unresolvedFloor r (List.mem_filter.mp hold).1

@[simp] theorem Certificate.refine_lower {Candidate Region : Type} [DecidableEq Region]
    {p : Problem Candidate} {bounds : RegionBounds p Region}
    (cert : Certificate p bounds) (parent : Region)
    (newlyExplored : List Candidate) (children : List Region)
    (replacementCover : ∀ c, p.feasible c → bounds.contains parent c →
      c ∈ newlyExplored ∨ ∃ r, r ∈ children ∧ bounds.contains r c)
    (newExploredFloor : ∀ c, c ∈ newlyExplored → p.feasible c →
      cert.lower ≤ p.objective c)
    (childFloor : ∀ r, r ∈ children → cert.lower ≤ bounds.lower r) :
    (cert.refine parent newlyExplored children replacementCover newExploredFloor childFloor).lower =
      cert.lower := rfl

/-- Raise the advertised lower endpoint after stronger local evidence becomes
available. Coverage and the incumbent do not change. -/
def Certificate.raiseLower {Candidate Region : Type}
    {p : Problem Candidate} {bounds : RegionBounds p Region}
    (cert : Certificate p bounds) (nextLower : Nat)
    (exploredFloor : ∀ c, c ∈ cert.frontier.explored → p.feasible c →
      nextLower ≤ p.objective c)
    (unresolvedFloor : ∀ r, r ∈ cert.frontier.unresolved →
      nextLower ≤ bounds.lower r) : Certificate p bounds where
  frontier := cert.frontier
  incumbent := cert.incumbent
  lower := nextLower
  exploredFloor := exploredFloor
  unresolvedFloor := unresolvedFloor

@[simp] theorem Certificate.raiseLower_value {Candidate Region : Type}
    {p : Problem Candidate} {bounds : RegionBounds p Region}
    (cert : Certificate p bounds) (nextLower : Nat)
    (exploredFloor : ∀ c, c ∈ cert.frontier.explored → p.feasible c →
      nextLower ≤ p.objective c)
    (unresolvedFloor : ∀ r, r ∈ cert.frontier.unresolved →
      nextLower ≤ bounds.lower r) :
    (cert.raiseLower nextLower exploredFloor unresolvedFloor).lower = nextLower := rfl

#print axioms Certificate.globalLower
#print axioms Certificate.globalInterval
#print axioms Certificate.optimalOfBoundsMeet
#print axioms Certificate.safePrune

end Kelana.QuantizationCertificates
