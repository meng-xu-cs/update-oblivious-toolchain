import UOToolchain.RuntimeStoreSurfaceGeneratedRust

def main : IO Unit := do
  IO.print GenerateRuntimeStoreSurfaceRust.generatedRust
