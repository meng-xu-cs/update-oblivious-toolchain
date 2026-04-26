import UOToolchain.RuntimeKernelSlotSupportGeneratedRust

def main (_args : List String) : IO UInt32 := do
  IO.print GenerateRuntimeKernelSlotSupportRust.generatedRust
  pure 0
