import UOToolchain.RuntimeStoreHelpersGeneratedRust

def main (_args : List String) : IO UInt32 := do
  IO.print GenerateRuntimeStoreHelpersRust.generatedRust
  pure 0
