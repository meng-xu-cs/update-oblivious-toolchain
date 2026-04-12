import Lake
open Lake DSL

package «uo-toolchain»

@[default_target]
lean_lib UOToolchain

lean_exe checkRuntimeWitness where
  root := `CheckRuntimeWitness
