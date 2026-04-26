import UOToolchain.RuntimeKernelMachineGeneratedRust

def main (_args : List String) : IO UInt32 := do
  GenerateRuntimeKernelMachineRust.checkMethodSchedules
  IO.print GenerateRuntimeKernelMachineRust.generatedRust
  pure 0
