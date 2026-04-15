import Lake
open Lake DSL

package «uo-toolchain»

@[default_target]
lean_lib UOToolchain

@[default_target]
lean_exe checkRuntimeWitness where
  root := `CheckRuntimeWitness

@[default_target]
lean_exe checkRuntimeControllerCertificate where
  root := `CheckRuntimeControllerCertificate

@[default_target]
lean_exe checkRuntimePathOramHiddenCertificate where
  root := `CheckRuntimePathOramHiddenCertificate

@[default_target]
lean_exe checkRuntimeWitnessFamily where
  root := `CheckRuntimeWitnessFamily

@[default_target]
lean_exe checkRuntimeFreshCoinFamily where
  root := `CheckRuntimeFreshCoinFamily

@[default_target]
lean_exe checkRuntimeFreshCoinTheoremInput where
  root := `CheckRuntimeFreshCoinTheoremInput

@[default_target]
lean_exe checkPathOramPairCertificate where
  root := `CheckPathOramPairCertificate

@[default_target]
lean_exe checkCanonicalPathOramPairCertificate where
  root := `CheckCanonicalPathOramPairCertificate

@[default_target]
lean_exe checkCanonicalPathOramPairTheoremInput where
  root := `CheckCanonicalPathOramPairTheoremInput
