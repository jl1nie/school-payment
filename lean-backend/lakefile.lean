import Lake
open Lake DSL

package «school-payment» where
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git"

lean_lib «SchoolPayment» where
  srcDir := "src"

@[default_target]
lean_exe «advisor» where
  root := `Main
