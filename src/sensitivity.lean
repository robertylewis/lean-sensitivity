import tactic
import tactic.fin_cases
import data.real.basic
import linear_algebra.dual
import linear_algebra.finsupp
import linear_algebra.finite_dimensional
import ring_theory.ideals
import analysis.normed_space.basic

noncomputable theory

local attribute [instance, priority 1] classical.prop_decidable
local attribute [instance, priority 0] set.decidable_mem_of_fintype

@[simp] lemma abs_nonpos_iff {α : Type*} [decidable_linear_ordered_comm_group α] {a : α} :
  abs a ≤ 0 ↔ a = 0 :=
by rw [← not_lt, abs_pos_iff, not_not]

open function

/-- The hypercube.-/
def Q (n) : Type := fin n → bool

/-- The only element of Q0 -/
def eQ0 : Q 0 := λ _, tt

lemma Q0_unique (p : Q 0) : p = eQ0 :=
by { ext x, fin_cases x }

namespace Q
variable (n : ℕ)

instance : fintype (Q n) := by delta Q; apply_instance

variable {n}

def xor (x y : Q n) : Q n :=
λ i, bxor (x i) (y i)

@[symm] lemma xor_comm (x y : Q n) : x.xor y = y.xor x :=
funext $ λ i, bool.bxor_comm _ _

/-- The distance between two vertices of the hypercube.-/
def dist (x y : Q n) : ℕ :=
(finset.univ : finset (fin n)).sum $ λ i, cond (x.xor y i) 1  0

@[simp] lemma dist_self (x : Q n) : x.dist x = 0 :=
finset.sum_eq_zero $ λ i hi, by simp only [xor, bxor_self, bool.cond_ff]

@[symm] lemma dist_symm (x y : Q n) : x.dist y = y.dist x :=
congr_arg ((finset.univ : finset (fin n)).sum) $
by { funext i, simp [xor_comm] }

/-- Two vertices of the hypercube are adjacent if their distance is 1.-/
def adjacent (x y : Q n) : Prop := x.dist y = 1

/-- The set of n-/
def neighbours (x : Q n) : set (Q n) := {y | x.adjacent y}

variable (n)

/-- The cardinality of the hypercube.-/
@[simp] lemma card : fintype.card (Q n) = 2^n :=
calc _ = _ : fintype.card_fun
   ... = _ : by simp only [fintype.card_fin, fintype.card_bool]

/-- The (n+1)-dimensional hypercube is equivalent to two copies of the n-dimensional hypercube.-/
def equiv_sum : Q (n+1) ≃ Q n ⊕ Q n :=
{ to_fun := λ x, cond (x 0)
                   (sum.inl (x ∘ fin.succ))
                   (sum.inr (x ∘ fin.succ)),
  inv_fun := λ x, sum.rec_on x
                   (λ y i, if h : i = 0 then tt else y (i.pred h))
                   (λ y i, if h : i = 0 then ff else y (i.pred h)),
  left_inv := λ x,
  begin
    dsimp only, cases h : x 0;
    { funext i, dsimp only [bool.cond_tt, bool.cond_ff], split_ifs with H,
      { rw [H, h] },
      { rw [function.comp_app, fin.succ_pred] } }
  end,
  right_inv := λ x,
  begin
    cases x;
    { simp only [dif_pos, bool.cond_tt, bool.cond_ff, cond, function.comp],
      funext i, rw [dif_neg, i.pred_succ], rw [fin.ext_iff, fin.succ_val],
      exact nat.succ_ne_zero _ }
  end }

lemma equiv_sum_apply (x : Q (n+1)) :
  equiv_sum n x = cond (x 0) (sum.inl (x ∘ fin.succ)) (sum.inr (x ∘ fin.succ)) := rfl

end Q

/-- The free vector space on vertices of a hypercube, defined inductively. -/
def V : ℕ → Type
| 0 := ℝ
| (n+1) := V n × V n

noncomputable instance : Π n, add_comm_group (V n) :=
begin
  apply nat.rec,
  { dunfold V, apply_instance },
  { introsI n IH, dunfold V, apply_instance }
end

noncomputable instance : Π n, vector_space ℝ (V n) :=
begin
  apply nat.rec,
  { dunfold V, apply_instance },
  { introsI n IH, dunfold V, apply_instance }
end

lemma dim_V {n : ℕ} : vector_space.dim ℝ (V n) = 2^n :=
begin
  induction n with n IH,
  { apply dim_of_field },
  { dunfold V,
    rw [dim_prod, IH, pow_succ, two_mul] }
end

open finite_dimensional

section cardinal_lemma
universe u

lemma cardinal.monoid_pow_eq_cardinal_pow {κ : cardinal.{u}} {n : ℕ} : κ ^ n = (κ ^ (↑n : cardinal.{u})) :=
begin
  induction n with n ih,
    {simp},
    { rw[nat.cast_succ, cardinal.power_add, <-ih, cardinal.power_one, mul_comm], refl }
end

end cardinal_lemma

instance {n}: finite_dimensional ℝ (V n) :=
begin
  rw [finite_dimensional_iff_dim_lt_omega, dim_V],
  suffices : ∃ k : ℕ, (↑2) ^ (↑k : cardinal.{0}) = (2 ^ n : cardinal.{0}),
    by {cases this with k H_k, rw[<-H_k, <-cardinal.nat_cast_pow],
        exact cardinal.nat_lt_omega _},
  from ⟨n, by {convert (@cardinal.monoid_pow_eq_cardinal_pow 2 n).symm, simp}⟩
end

lemma findim_V {n} : findim ℝ (V n) = 2^n :=
begin
  have := findim_eq_dim ℝ (V n),
  rw dim_V at this,
  rw [← cardinal.nat_cast_inj, this],
  simp[cardinal.monoid_pow_eq_cardinal_pow]
end

/-- The basis of V indexed by the hypercube.-/
noncomputable def e : Π {n}, Q n → V n
| 0     := λ _, (1:ℝ)
| (n+1) := λ x, cond (x 0) (e (x ∘ fin.succ), 0) (0, e (x ∘ fin.succ))

@[simp] lemma e_zero_apply (x : Q 0) :
  e x = (1 : ℝ) := rfl

lemma e_succ_apply {n} (x : Q (n+1)) :
  e x = cond (x 0) (e (x ∘ fin.succ), 0) (0, e (x ∘ fin.succ)) :=
by rw e

lemma e.is_basis (n) : is_basis ℝ (e : Q n → V n) :=
begin
  induction n with n ih,
  { split,
    { apply linear_map.ker_eq_bot'.mpr,
      intros v hv, ext i,
      have : v = finsupp.single eQ0 (v eQ0),
      { ext k,
        simp only [Q0_unique k, finsupp.single, finsupp.single_eq_same] },
      rw [finsupp.total_apply, this, finsupp.sum_single_index] at hv,
      { simp only [e_zero_apply, smul_eq_mul, mul_one] at hv,
        rwa [Q0_unique i, finsupp.zero_apply] },
      { rw zero_smul } },
    { refine (ideal.eq_top_iff_one _).mpr (submodule.subset_span _),
      rw set.mem_range, exact ⟨(λ _, tt), rfl⟩ } },
  convert (is_basis_inl_union_inr ih ih).comp (Q.equiv_sum n) (Q.equiv_sum n).bijective,
  funext x,
  rw [e_succ_apply, function.comp_apply, Q.equiv_sum_apply],
  cases h : x 0;
  { simp only [bool.cond_tt, bool.cond_ff, prod.mk.inj_iff, sum.elim_inl, sum.elim_inr, cond,
      linear_map.inl_apply, linear_map.inr_apply, function.comp_apply, and_true],
    exact ⟨rfl, rfl⟩ }
end

/-- The linear operator f_n corresponding to Huang's matrix A_n. -/
noncomputable def f : Π n, V n →ₗ[ℝ] V n
| 0 := 0
| (n+1) :=
  linear_map.pair
    (linear_map.copair (f n) linear_map.id)
    (linear_map.copair linear_map.id (-f n))

lemma f_squared {n : ℕ} : ∀ v, (f n) (f n v) = (n : ℝ) • v :=
-- The (n : ℝ) is necessary since `n • v` refers to the multiplication defined
-- using only the addition of V.
begin
  induction n with n IH,
  { intro v, dunfold f, simp, refl },
  { rintro ⟨v, v'⟩,
    ext,
    { dunfold f V,
      conv_rhs { change ((n : ℝ) + 1) • v, rw add_smul },
      simp [IH] },
    { dunfold f V,
      conv_rhs { change ((n : ℝ) + 1) • v', rw add_smul },
      have : Π (x y : V n), -x + (y + x) = y := by { intros, abel }, -- ugh
      simp [IH, this] } }
end

/-- The dual basis to e -/
noncomputable def ε : Π {n : ℕ} (p : Q n), V n →ₗ[ℝ] ℝ
| 0 _ := linear_map.id
| (n+1) p := cond (p 0) ((ε $ p ∘ fin.succ).comp $ linear_map.fst _ _ _) ((ε $ p ∘ fin.succ).comp $ linear_map.snd _ _ _)

lemma fin.succ_ne_zero {n} (k : fin n) : fin.succ k ≠ 0 :=
begin
  cases k with k hk,
  intro h,
  have : k + 1 = 0 := (fin.ext_iff _ _).1 h,
  finish
end

open bool

lemma Q_succ_n_eq {n} (p q : Q (n+1)) : p = q ↔ (p 0 = q 0 ∧ p ∘ fin.succ = q ∘ fin.succ) :=
begin
  split,
  { intro h, split ; rw h ; refl, },
  { rintros ⟨h₀, h⟩,
    ext x,
    by_cases hx : x = 0,
    { rwa hx },
    rw ← fin.succ_pred x hx,
    convert congr_fun h (fin.pred x hx) }
end

lemma duality {n : ℕ} (p q : Q n) : ε p (e q) = if p = q then 1 else 0 :=
begin
  induction n with n IH,
  { dsimp [ε, e],
    simp [Q0_unique p, Q0_unique q] },
  { cases hp : p 0 ; cases hq : q 0,
    all_goals {
      dsimp [ε, e],
      rw [hp, hq],
      repeat {rw cond_tt},
      repeat {rw cond_ff},
      simp only [linear_map.fst_apply, linear_map.snd_apply, linear_map.comp_apply] },
    { rw IH,
      congr'  1,
      rw Q_succ_n_eq,
      finish },
    { erw (ε _).map_zero,
      have : p ≠ q,
      { intro h,
        rw Q_succ_n_eq p q at h,
        finish },
      simp [this] },
    { erw (ε _).map_zero,
      have : p ≠ q,
      { intro h,
        rw Q_succ_n_eq p q at h,
        finish },
      simp [this] },
    { rw IH,
      congr'  1,
      rw Q_succ_n_eq,
      finish } }
end

/-- The adjacency relation on Q^n. -/
def adjacent : Π {n : ℕ}, Q n → (set $ Q n)
| 0 p q := false
| (n+1) p q := (p 0 = q 0 ∧ adjacent (p ∘ fin.succ) (q ∘ fin.succ)) ∨ (p 0 ≠ q 0 ∧ p ∘ fin.succ = q ∘ fin.succ)

lemma adjacent.symm : Π {n} {p q}, @adjacent n p q ↔ adjacent q p
| 0     p q := iff.rfl
| (n+1) p q := begin
  dsimp [adjacent],
  rw [adjacent.symm],
  simp [eq_comm]
end

@[reducible]def adjacent' : Π {n : ℕ}, Q n → (set $ Q n) :=
λ n q, (λ p, adjacent p q)

@[simp] lemma adjacent_of_adjacent' {n} (p q) : p ∈ @adjacent' n q ↔ q ∈ adjacent p := by refl

lemma f_matrix {n} : ∀ (p q : Q n), abs (ε q (f n (e p))) = if adjacent p q then 1 else 0 :=
begin
  induction n with n IH,
  { intros p q,
    dsimp [f, adjacent],
    simp [Q0_unique p, Q0_unique q] },
  { intros p q,
    have ite_nonneg : ite (q ∘ fin.succ = p ∘ fin.succ) (1 : ℝ) 0 ≥ 0,
    { by_cases h : q ∘ fin.succ = p ∘ fin.succ; simp [h] ; norm_num },
    cases hp : p 0 ; cases hq : q 0,
    all_goals {
      dsimp [e, ε, f, adjacent],
      rw [hp, hq],
      repeat { rw cond_tt },
      repeat { rw cond_ff },
      simp only [add_zero, linear_map.id_apply, linear_map.fst_apply, linear_map.snd_apply,
                cond, cond_tt, cond_ff, linear_map.neg_apply,
                linear_map.copair_apply, linear_map.comp_apply],
      try { erw (f n).map_zero },
      try { simp only [abs_neg, abs_of_nonneg ite_nonneg, add_comm, add_zero, duality,
              false_and, false_or, IH, linear_map.map_add, linear_map.map_neg, linear_map.map_zero,
              neg_zero, not_false_iff, not_true, or_false, true_and, zero_add] },
      try { congr' 1, apply propext, rw eq_comm },
      try { simp } } }
end

/-- The linear operator g_n corresponding to Knuth's matrix B_n.
  We adopt the convention n = m+1. -/
noncomputable def g (m : ℕ) : V m →ₗ[ℝ] V (m+1) :=
linear_map.pair (f m + real.sqrt (m+1) • linear_map.id) linear_map.id

lemma g_injective {m : ℕ} : function.injective (g m) :=
begin
  rw[g], intros x₁ x₂ H_eq, simp at *, exact H_eq.right
end

-- I don't understand why the type ascription is necessary here, when f_squared worked fine
lemma f_image_g {m : ℕ} (w : V (m + 1)) (hv : ∃ v, w = g m v) :
  (f (m + 1) : V (m + 1) → V (m + 1)) w = real.sqrt (m + 1) • w :=
begin
  rcases hv with ⟨v, rfl⟩,
  dsimp [g],
  erw f,
  simp [f_squared],
  rw [smul_add, smul_smul, real.mul_self_sqrt (by exact_mod_cast zero_le _ : 0 ≤ (1 : ℝ) + m), add_smul, one_smul],
  abel,
end

lemma abs_sqrt_nat {m : ℕ} : abs (real.sqrt (↑m + 1) : ℝ) = real.sqrt (↑m + 1) :=
  abs_of_pos $ real.sqrt_pos.mpr $ nat.cast_add_one_pos m

lemma finset.card_eq_sum_ones {α} (s : finset α) : s.card = (s.sum $ λ _, 1) :=
by simp

lemma fintype.card_eq_sum_ones {α} [fintype α] : fintype.card α = (fintype.elems α).sum (λ _, 1) :=
finset.card_eq_sum_ones _

lemma refold_coe {α β γ} [ring α] [add_comm_group γ] [add_comm_group β] [module α β] [module α γ] {f : β →ₗ[α] γ} : f.to_fun = ⇑f := rfl

lemma abs_triangle_sum {α : Type*} {s : finset α} {f : α → ℝ} : abs (s.sum f) ≤ (s.sum (λ x, abs (f x))) :=
(norm_triangle_sum _ _ : ∥ _ ∥ ≤ finset.sum s (λ x, ∥ f x∥))

lemma injective_e {n} : injective (@e n) :=
linear_independent.injective (by norm_num) (e.is_basis n).1

lemma range_restrict {α : Type*} {β : Type*} (f : α → β) (p : α → Prop) : set.range (restrict f p) = f '' (p : set α) :=
by { ext x,  simp [restrict], refl }

example {α} (s : finset α) (H_sub : s ⊆ ∅) : s = ∅ := finset.subset_empty.mp ‹_›

-- TODO(jesse): remove later
lemma finset.sum_remove_zeros {α β : Type*} [add_comm_group β] {s : finset α} {f : α → β} (t : finset α) (H_sub : t ⊆ s) (Ht : ∀ x ∈ s, f x = 0 ↔ x ∈ (s \ t)) : s.sum f = t.sum f :=
(@finset.sum_subset _ _ t s f _ ‹_› (by finish)).symm

lemma finset.sum_factor_constant {α β : Type*} [field β] {s : finset α} (b : β) : (s.sum (λ x, b) = (s.sum (λ x, 1) * b)) := sorry

variables {m : ℕ} (H : set (Q (m + 1))) (hH : fintype.card H ≥ 2^m + 1)
include hH

local notation `d` := vector_space.dim ℝ
local notation `fd` := findim ℝ

attribute [elim_cast] cardinal.nat_cast_inj
attribute [elim_cast] cardinal.nat_cast_lt
attribute [elim_cast] cardinal.nat_cast_le

lemma exists_eigenvalue :
  ∃ y ∈ submodule.span ℝ (e '' H) ⊓ (g m).range, y ≠ (0 : _) :=
begin
  let W := submodule.span ℝ (e '' H),
  let img := (g m).range,
  suffices : 0 < fd ↥(W ⊓ img),
  { simp only [exists_prop],
    apply exists_mem_ne_zero_of_dim_pos,
    rw ← findim_eq_dim ℝ,
    exact_mod_cast this },
  have dim_le : fd ↥(W ⊔ img) ≤ 2 ^ (m + 1),
  { have := dim_submodule_le (W ⊔ img),
    repeat { rw ← findim_eq_dim ℝ at this },
    norm_cast at this,
    rwa findim_V at this},
  have dim_add : fd ↥(W ⊔ img) + fd ↥(W ⊓ img) = fd ↥W + 2^m,
  { have : d ↥(W ⊔ img) + d ↥(W ⊓ img) = d ↥W + d ↥img,
      from dim_sup_add_dim_inf_eq W img,
    rw ← dim_eq_injective (g m) g_injective at this,
    repeat { rw ← findim_eq_dim ℝ at this },
    norm_cast at this,
    rwa findim_V at this },
  have dimW : fd ↥W = fintype.card ↥H,
  { let eH := restrict e H,
    have li : linear_independent ℝ eH,
    { refine linear_independent_comp_subtype.2 (λ l hl, _),
      clear hl, revert l,
      rw [← linear_map.ker_eq_bot'],
      exact (e.is_basis (m+1)).1 },
    have hdW := dim_span li,
    rw [cardinal.mk_range_eq eH (subtype.restrict_injective _ injective_e),
        cardinal.fintype_card, range_restrict, ← findim_eq_dim ℝ] at hdW,
    exact_mod_cast hdW },
  replace hH : fd ↥W ≥ 2 ^ m + 1 := dimW.symm ▸ hH, clear dimW,
  rw [nat.pow_succ] at dim_le,
  linarith
end

theorem degree_theorem :
  ∃ q, q ∈ H ∧ real.sqrt (m + 1) ≤ finset.card ({p | p ∈ H ∧ adjacent q p}.to_finset) :=
begin
  rcases exists_eigenvalue H ‹_› with ⟨y, ⟨H_mem, H_nonzero⟩⟩,
  cases H_mem with H_mem' H_mem'',
  rcases (finsupp.mem_span_iff_total _).mp H_mem' with ⟨l, H_l₁, H_l₂⟩,
  have H_q_max : ∃ q, q ∈ H ∧ ∀ q', q' ∈ H → abs (l q') ≤ abs (l q),
    by {sorry}, -- get q by finset.sup?
  rcases H_q_max with ⟨q, H_mem_H, H_max⟩,
  have H_q_pos : 0 < abs (l q),
  { rw [abs_pos_iff],
    assume h,
    rw [finsupp.mem_supported'] at H_l₁,
    have H_max' : ∀ q', l q' = 0,
    { intro q',
      by_cases hq' : q' ∈ H,
      { revert q', simpa [h] using H_max },
      { exact H_l₁ _ hq' } },
    have hl0 : l = 0,
    { ext, rw [H_max', finsupp.zero_apply] },
    simp [hl0] at H_l₂,
    exact H_nonzero H_l₂.symm },
  refine ⟨q, ⟨‹_›, _⟩⟩,
  suffices : real.sqrt (↑m + 1) * abs (l q) ≤ ↑(_) * abs (l q),
    by { exact (mul_le_mul_right H_q_pos).mp ‹_› },
  rw [<-abs_sqrt_nat, <-abs_mul],
  transitivity abs (ε q (real.sqrt (↑m + 1) • y)),
    by {sorry},
  rw[<-f_image_g, <-H_l₂],
    swap, {simp at H_mem'', rcases H_mem'' with ⟨v,Hv⟩, exact ⟨v, Hv.symm⟩},
  rw[finsupp.total, finsupp.lsum], unfold_coes, dsimp, rw[finsupp.sum], -- unfolding finsupp.total
  simp only [refold_coe], rw[linear_map.map_sum, linear_map.map_sum],
  refine le_trans abs_triangle_sum _,
  conv { congr, congr, skip, simp[abs_mul] },
  rw[<-finset.sum_subset], show finset _,
    exact (l.support ∩ H.to_finset ∩ ({p | adjacent p q}).to_finset), rotate,
    { intros x Hx, simp[-finsupp.mem_support_iff] at Hx, exact Hx.left },
    { intros x H_mem H_not_mem,
        by_cases x ∈ H,
          { simp at H_mem H_not_mem, rw[f_matrix], have := (H_not_mem ‹_› ‹_›),
            change ¬ adjacent _ _ at this, simp* },
          { suffices : (l x) = 0,
              by {simp [this]},
            rw [finsupp.mem_supported'] at H_l₁,
            exact H_l₁ _ ‹_› }},

  refine le_trans (finset.sum_le_sum _) _, exact λ p, abs (l q),
    { intros x Hx, rw[f_matrix], simp at Hx,
      have := Hx.right.right, change adjacent _ _ at this, simp* },
    rw[finset.card_eq_sum_ones, finset.sum_factor_constant], simp,
    refine (mul_le_mul_right ‹_›).mpr _,
    change _ ≤ ↑((finset.card (set.to_finset {p : Q (m + 1) | p ∈ H ∧ adjacent q p}))),
    norm_cast, refine finset.card_le_of_subset _,
    intros x Hx, simp at Hx, rcases Hx with ⟨Hx₁, Hx₂, Hx₃⟩, simp*, rwa adjacent.symm
end
