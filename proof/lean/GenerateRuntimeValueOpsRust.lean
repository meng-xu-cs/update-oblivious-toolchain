import UOToolchain.RuntimeValueOpsGeneratedRust

def main (_args : List String) : IO UInt32 := do
  IO.print GenerateRuntimeValueOpsRust.generatedRust
  pure 0
