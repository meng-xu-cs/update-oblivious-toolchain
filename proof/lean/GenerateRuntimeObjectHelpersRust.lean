import UOToolchain.RuntimeObjectHelpersGeneratedRust

def main (_args : List String) : IO UInt32 := do
  GenerateRuntimeObjectHelpersRust.checkDisciplines
  IO.print GenerateRuntimeObjectHelpersRust.generatedRust
  pure 0
