import Lake
open Lake DSL

package «uo-toolchain»

@[default_target]
lean_lib UOToolchain

@[default_target]
lean_exe checkProofGradeRuntimeWitness where
  root := `CheckProofGradeRuntimeWitness

@[default_target]
lean_exe checkProofGradeRuntimeKernelInterface where
  root := `CheckProofGradeRuntimeKernelInterface

@[default_target]
lean_exe checkProofGradeRuntimeKernelInterfaceBundle where
  root := `CheckProofGradeRuntimeKernelInterfaceBundle

@[default_target]
lean_exe checkProofGradeRuntimeKernelInterfaceFamily where
  root := `CheckProofGradeRuntimeKernelInterfaceFamily

@[default_target]
lean_exe checkProofGradeRuntimePaperMainFamily where
  root := `CheckProofGradeRuntimePaperMainFamily

lean_exe checkProofGradeRuntimePaperMainFamilyBundle where
  root := `CheckProofGradeRuntimePaperMainFamilyBundle

@[default_target]
lean_exe checkProofGradeRuntimePaperMainSlotFamilyBundle where
  root := `CheckProofGradeRuntimePaperMainSlotFamilyBundle

@[default_target]
lean_exe checkProofGradeRuntimeConfidentialCore where
  root := `CheckProofGradeRuntimeConfidentialCore

@[default_target]
lean_exe checkProofGradeRuntimeConfidentialCoreSlot where
  root := `CheckProofGradeRuntimeConfidentialCoreSlot

@[default_target]
lean_exe checkProofGradeRuntimeConfidentialCoreShellBoundarySlot where
  root := `CheckProofGradeRuntimeConfidentialCoreShellBoundarySlot

@[default_target]
lean_exe checkProofGradeRuntimeConfidentialCoreKernelInterfaceSlot where
  root := `CheckProofGradeRuntimeConfidentialCoreKernelInterfaceSlot

@[default_target]
lean_exe checkProofGradeRuntimeConfidentialCoreLowering where
  root := `CheckProofGradeRuntimeConfidentialCoreLowering

@[default_target]
lean_exe checkProofGradeRuntimeConfidentialCoreShellBoundaryLowering where
  root := `CheckProofGradeRuntimeConfidentialCoreShellBoundaryLowering

@[default_target]
lean_exe checkProofGradeRuntimeKernelDsl where
  root := `CheckProofGradeRuntimeKernelDsl

@[default_target]
lean_exe checkProofGradeRuntimeKernelSlotDsl where
  root := `CheckProofGradeRuntimeKernelSlotDsl

@[default_target]
lean_exe checkProofGradeRuntimeKernelLowering where
  root := `CheckProofGradeRuntimeKernelLowering

@[default_target]
lean_exe checkProofGradeRuntimeKernelWitness where
  root := `CheckProofGradeRuntimeKernelWitness

@[default_target]
lean_exe checkProofGradeRuntimeKernelRefinementWitness where
  root := `CheckProofGradeRuntimeKernelRefinementWitness

@[default_target]
lean_exe checkProofGradeRuntimeShellBoundary where
  root := `CheckProofGradeRuntimeShellBoundary

@[default_target]
lean_exe checkProofGradeRuntimeShellBoundarySlot where
  root := `CheckProofGradeRuntimeShellBoundarySlot

@[default_target]
lean_exe checkProofGradeRuntimeShellBoundaryLowering where
  root := `CheckProofGradeRuntimeShellBoundaryLowering

@[default_target]
lean_exe checkProofGradeRuntimeTrustedKernel where
  root := `CheckProofGradeRuntimeTrustedKernel

@[default_target]
lean_exe checkProofGradeTranslationArtifacts where
  root := `CheckProofGradeTranslationArtifacts

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
lean_exe checkProofGradeRuntimeWitnessFamily where
  root := `CheckProofGradeRuntimeWitnessFamily

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

@[default_target]
lean_exe checkCanonicalPathOramPaperInstantiation where
  root := `CheckCanonicalPathOramPaperInstantiation
