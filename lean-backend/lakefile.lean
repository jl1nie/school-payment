import Lake
open Lake DSL

package «school-payment» where
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

require batteries from git
  "https://github.com/leanprover-community/batteries" @ "main"

lean_lib «SchoolPayment» where
  srcDir := "src"

@[default_target]
lean_exe «advisor» where
  root := `Main
