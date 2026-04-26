import UOToolchain.ConfidentialKernelGeneratedRust

def main (_args : List String) : IO UInt32 := do
  GenerateConfidentialKernelRust.checkProfileLengths
  IO.print GenerateConfidentialKernelRust.generatedRust
  pure 0
