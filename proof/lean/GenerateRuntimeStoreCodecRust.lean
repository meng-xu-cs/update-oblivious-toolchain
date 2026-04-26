import UOToolchain.RuntimeStoreCodecGeneratedRust

def main (_args : List String) : IO UInt32 := do
  IO.print GenerateRuntimeStoreCodecRust.generatedRust
  pure 0
