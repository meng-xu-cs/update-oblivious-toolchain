import UOToolchain.TranslationValidationJson
import UOToolchain.OramModel

namespace UOToolchain

def ImportedProofRelevantOramAccessView.toPair
  (access : ImportedProofRelevantOramAccessView) : Nat × Nat :=
  (access.object_id, access.accesses)

def ImportedProofRelevantEntrypointView.toManifestWitnessWithExpected
  (entry : ImportedProofRelevantEntrypointView)
  (expected : List (Nat × Nat)) : ManifestWitness :=
  { publicGasBudget := entry.public_gas_budget
  , secretArgs := entry.secret_args
  , oramAccesses := expected
  }

theorem lookupEntrypoint_signature_exact
  {signature : String}
  {entry : ImportedProofRelevantEntrypointView}
  {entrypoints : List ImportedProofRelevantEntrypointView}
  (hLookup : lookupEntrypoint signature entrypoints = some entry) :
  entry.signature = signature := by
  induction entrypoints with
  | nil =>
      simp [lookupEntrypoint] at hLookup
  | cons hd tl ih =>
      by_cases hSig : hd.signature == signature
      · simp [lookupEntrypoint, hSig] at hLookup
        subst entry
        simpa using hSig
      · simp [lookupEntrypoint, hSig] at hLookup
        exact ih hLookup

def ImportedProofRelevantManifestObjectView.toOramObjectManifest?
  (manifestObject : ImportedProofRelevantManifestObjectView)
  (stateObject : ImportedProofRelevantStateObjectView) : Option OramObjectManifest :=
  match manifestObject.oram with
  | none => none
  | some oram =>
      some
        { objectId := stateObject.id
        , objectName := stateObject.name
        , capacity := stateObject.capacity.getD 1
        , scheme := oram.scheme
        , blockSize := oram.block_size
        , bucketSize := oram.bucket_size
        , bucketCount := oram.bucket_count
        , blocksPerBucket := oram.blocks_per_bucket
        , treeHeight := oram.tree_height
        , stashBound := oram.stash_bound
        , recursionDepth := oram.recursion_depth
        , metadataPages := oram.metadata_pages
        , metadataPagesPerAccess := oram.metadata_pages_per_access
        , bucketsPerAccess := oram.buckets_per_access
        , accessesPerCall := oram.accesses_per_call
        }

def ImportedProofRelevantContractView.buildExpectedOramObjectWitnesses
  (view : ImportedProofRelevantContractView)
  (expected : List (Nat × Nat)) : Except String (List OramObjectManifest) :=
  expected.mapM fun entry => do
    let objectId := entry.fst
    let stateObject ←
      match stateObjectById? view.state objectId with
      | some object => pure object
      | none => throw s!"missing state object {objectId} for ORAM witness"
    let manifestObject ←
      match manifestObjectById? view.manifest.objects objectId with
      | some object => pure object
      | none => throw s!"missing manifest object {objectId} for ORAM witness"
    match manifestObject.toOramObjectManifest? stateObject with
    | some object => pure object
    | none => throw s!"object {objectId} does not carry ORAM metadata"

def ImportedProofRelevantContractView.toOramEntrypointWitnessFromExpected
  (view : ImportedProofRelevantContractView)
  (entry : ImportedProofRelevantEntrypointView)
  (expected : List (Nat × Nat)) : Except String OramEntrypointWitness := do
  let oramObjects ← view.buildExpectedOramObjectWitnesses expected
  pure
    { entry.toManifestWitnessWithExpected expected with
      entrypointId := entry.signature
      oramObjects := oramObjects
    }

inductive ExpectedOramObjectWitnessAlignment :
    List (Nat × Nat) → List OramObjectManifest → Prop
  | nil : ExpectedOramObjectWitnessAlignment [] []
  | cons {entry expectedTail object objectTail} :
      WellFormedOramObject object →
      ((1 < entry.snd) → WellFormedAnyPathOramObject object) →
      ExpectedOramObjectWitnessAlignment expectedTail objectTail →
      ExpectedOramObjectWitnessAlignment (entry :: expectedTail) (object :: objectTail)

theorem ExpectedOramObjectWitnessAlignment.objectsWellFormed
  {expected : List (Nat × Nat)}
  {objects : List OramObjectManifest}
  (hAligned : ExpectedOramObjectWitnessAlignment expected objects) :
  ∀ object, object ∈ objects → WellFormedOramObject object := by
  induction hAligned with
  | nil =>
      intro object hMem
      simp at hMem
  | cons hWellFormed _hPathIfMany _hTail ih =>
      intro object hMem
      simp at hMem
      rcases hMem with rfl | hMemTail
      · exact hWellFormed
      · exact ih object hMemTail

theorem ExpectedOramObjectWitnessAlignment.length_eq
  {expected : List (Nat × Nat)}
  {objects : List OramObjectManifest}
  (hAligned : ExpectedOramObjectWitnessAlignment expected objects) :
  expected.length = objects.length := by
  induction hAligned with
  | nil =>
      rfl
  | cons _hWellFormed _hPathIfMany _hTail ih =>
      simp [ih]

theorem ImportedProofRelevantManifestObjectView.exists_oramObjectManifest_of_validateImportedOramShape
  {stateObject : ImportedProofRelevantStateObjectView}
  {manifestObject : ImportedProofRelevantManifestObjectView}
  {accesses : Nat}
  (hShape : validateImportedOramShape stateObject manifestObject accesses = true) :
  ∃ object,
    manifestObject.toOramObjectManifest? stateObject = some object ∧
    WellFormedOramObject object ∧
    ((1 < accesses) → WellFormedAnyPathOramObject object) := by
  cases hOram : manifestObject.oram with
  | none =>
      simp [validateImportedOramShape, hOram] at hShape
  | some oram =>
      by_cases hSurrogate : oram.scheme = translationSurrogateOramScheme
      · have hBlocksPerBucket : oram.blocks_per_bucket = 2 := by
          by_cases hEq : oram.blocks_per_bucket = 2
          · exact hEq
          · simp [validateImportedOramShape, hOram, hSurrogate, hEq] at hShape
        have hBucketSize :
            oram.bucket_size =
              translationOramBucketHeaderBytes + oram.blocks_per_bucket * oram.block_size := by
          by_cases hEq :
              oram.bucket_size =
                translationOramBucketHeaderBytes + oram.blocks_per_bucket * oram.block_size
          · exact hEq
          · simp [validateImportedOramShape, hOram, hSurrogate, hEq] at hShape
        have hBucketCount : 0 < oram.bucket_count := by
          by_cases hPos : 0 < oram.bucket_count
          · exact hPos
          · simp [validateImportedOramShape, hOram, hSurrogate, hPos] at hShape
        have hMetadataPagesPerAccess :
            oram.metadata_pages_per_access = oram.metadata_pages + 1 := by
          by_cases hEq : oram.metadata_pages_per_access = oram.metadata_pages + 1
          · exact hEq
          · simp [validateImportedOramShape, hOram, hSurrogate, hEq] at hShape
        have hBucketsPerAccess :
            oram.buckets_per_access = max (oram.tree_height + 2) 3 := by
          by_cases hEq : oram.buckets_per_access = max (oram.tree_height + 2) 3
          · exact hEq
          · simp [validateImportedOramShape, hOram, hSurrogate, hEq] at hShape
        have hStashBound : oram.stash_bound = 0 := by
          by_cases hEq : oram.stash_bound = 0
          · exact hEq
          · simp [validateImportedOramShape, hOram, hSurrogate, hEq] at hShape
        have hRecursionDepth : oram.recursion_depth = 0 := by
          by_cases hEq : oram.recursion_depth = 0
          · exact hEq
          · simp [validateImportedOramShape, hOram, hSurrogate, hEq] at hShape
        have hAccessesPerCall : oram.accesses_per_call = 1 := by
          by_cases hEq : oram.accesses_per_call = 1
          · exact hEq
          · simp [validateImportedOramShape, hOram, hSurrogate, hEq] at hShape
        have hWellFormedSurrogate :
            WellFormedSurrogateOramObject
              { objectId := stateObject.id
              , objectName := stateObject.name
              , capacity := stateObject.capacity.getD 1
              , scheme := oram.scheme
              , blockSize := oram.block_size
              , bucketSize := oram.bucket_size
              , bucketCount := oram.bucket_count
              , blocksPerBucket := oram.blocks_per_bucket
              , treeHeight := oram.tree_height
              , stashBound := oram.stash_bound
              , recursionDepth := oram.recursion_depth
              , metadataPages := oram.metadata_pages
              , metadataPagesPerAccess := oram.metadata_pages_per_access
              , bucketsPerAccess := oram.buckets_per_access
              , accessesPerCall := oram.accesses_per_call
              } := by
          simpa
            [ WellFormedSurrogateOramObject
            , translationSurrogateOramScheme
            , surrogateOramScheme
            , translationOramBucketHeaderBytes
            , oramBucketHeaderBytes
            , hSurrogate
            ] using
            And.intro hSurrogate <|
              And.intro hBlocksPerBucket <|
              And.intro hBucketSize <|
              And.intro hBucketCount <|
              And.intro hMetadataPagesPerAccess <|
              And.intro hBucketsPerAccess <|
              And.intro hStashBound <|
              And.intro hRecursionDepth hAccessesPerCall
        have hNotManyAccesses : ¬ 1 < accesses := by
          intro hMany
          have hImpossible := hShape
          simp
            [ validateImportedOramShape
            , hOram
            , hSurrogate
            , hMany
            , translationSurrogateOramScheme
            , translationPathOramScheme
            , translationPathOramPrivatePosmapScheme
            , translationIsPathOramScheme
            ] at hImpossible
        refine
          ⟨{ objectId := stateObject.id
           , objectName := stateObject.name
           , capacity := stateObject.capacity.getD 1
           , scheme := oram.scheme
           , blockSize := oram.block_size
           , bucketSize := oram.bucket_size
           , bucketCount := oram.bucket_count
           , blocksPerBucket := oram.blocks_per_bucket
           , treeHeight := oram.tree_height
           , stashBound := oram.stash_bound
           , recursionDepth := oram.recursion_depth
           , metadataPages := oram.metadata_pages
           , metadataPagesPerAccess := oram.metadata_pages_per_access
           , bucketsPerAccess := oram.buckets_per_access
           , accessesPerCall := oram.accesses_per_call
           }, ?_, ?_, ?_⟩
        · simp [ImportedProofRelevantManifestObjectView.toOramObjectManifest?, hOram]
        ·
          left
          exact hWellFormedSurrogate
        ·
          intro hMany
          exact False.elim (hNotManyAccesses hMany)
      · have hNotSurrogate : ¬ oram.scheme = "surrogate_public_schedule_v1" := by
          simpa [translationSurrogateOramScheme] using hSurrogate
        by_cases hPathScheme : oram.scheme = translationPathOramScheme
        · have hBlocksPerBucket : oram.blocks_per_bucket = 5 := by
            by_cases hEq : oram.blocks_per_bucket = 5
            · exact hEq
            · simp [validateImportedOramShape, hOram, hPathScheme, hEq,
                translationSurrogateOramScheme, translationPathOramScheme,
                translationPathOramPrivatePosmapScheme,
                translationIsPathOramScheme, translationPathOramPositionMapShapeWellFormed] at hShape
          have hBucketSize :
              oram.bucket_size =
                translationOramBucketHeaderBytes + oram.blocks_per_bucket * oram.block_size := by
            by_cases hEq :
                oram.bucket_size =
                  translationOramBucketHeaderBytes + oram.blocks_per_bucket * oram.block_size
            · exact hEq
            · simp [validateImportedOramShape, hOram, hPathScheme, hEq,
                translationSurrogateOramScheme, translationPathOramScheme,
                translationPathOramPrivatePosmapScheme,
                translationIsPathOramScheme, translationPathOramPositionMapShapeWellFormed] at hShape
          have hBucketCount : 0 < oram.bucket_count := by
            by_cases hPos : 0 < oram.bucket_count
            · exact hPos
            · simp [validateImportedOramShape, hOram, hPathScheme, hPos,
                translationSurrogateOramScheme, translationPathOramScheme,
                translationPathOramPrivatePosmapScheme,
                translationIsPathOramScheme, translationPathOramPositionMapShapeWellFormed] at hShape
          have hStashBound :
              oram.stash_bound = translationPathOramStashBound (stateObject.capacity.getD 1) := by
            by_cases hEq : oram.stash_bound = translationPathOramStashBound (stateObject.capacity.getD 1)
            · exact hEq
            · simp [validateImportedOramShape, hOram, hPathScheme, hEq,
                translationSurrogateOramScheme, translationPathOramScheme,
                translationPathOramPrivatePosmapScheme,
                translationIsPathOramScheme, translationPathOramPositionMapShapeWellFormed] at hShape
          have hRecursionDepth : oram.recursion_depth = 0 := by
            by_cases hEq : oram.recursion_depth = 0
            · exact hEq
            · simp [validateImportedOramShape, hOram, hPathScheme, hEq,
                translationSurrogateOramScheme, translationPathOramScheme,
                translationPathOramPrivatePosmapScheme,
                translationIsPathOramScheme, translationPathOramPositionMapShapeWellFormed] at hShape
          have hMetadataPagesPerAccess :
              oram.metadata_pages_per_access = oram.metadata_pages + 1 := by
            by_cases hEq : oram.metadata_pages_per_access = oram.metadata_pages + 1
            · exact hEq
            · simp [validateImportedOramShape, hOram, hPathScheme, hEq,
                translationSurrogateOramScheme, translationPathOramScheme,
                translationPathOramPrivatePosmapScheme,
                translationIsPathOramScheme, translationPathOramPositionMapShapeWellFormed] at hShape
          have hBucketsPerAccess :
              oram.buckets_per_access = oram.tree_height + 1 := by
            by_cases hEq : oram.buckets_per_access = oram.tree_height + 1
            · exact hEq
            · simp [validateImportedOramShape, hOram, hPathScheme, hEq,
                translationSurrogateOramScheme, translationPathOramScheme,
                translationPathOramPrivatePosmapScheme,
                translationIsPathOramScheme, translationPathOramPositionMapShapeWellFormed] at hShape
          have hAccessesPerCall : oram.accesses_per_call = 1 := by
            by_cases hEq : oram.accesses_per_call = 1
            · exact hEq
            · simp [validateImportedOramShape, hOram, hPathScheme, hEq,
                translationSurrogateOramScheme, translationPathOramScheme,
                translationPathOramPrivatePosmapScheme,
                translationIsPathOramScheme, translationPathOramPositionMapShapeWellFormed] at hShape
          have hWellFormedPath :
              WellFormedPathOramObject
                { objectId := stateObject.id
                , objectName := stateObject.name
                , capacity := stateObject.capacity.getD 1
                , scheme := oram.scheme
                , blockSize := oram.block_size
                , bucketSize := oram.bucket_size
                , bucketCount := oram.bucket_count
                , blocksPerBucket := oram.blocks_per_bucket
                , treeHeight := oram.tree_height
                , stashBound := oram.stash_bound
                , recursionDepth := oram.recursion_depth
                , metadataPages := oram.metadata_pages
                , metadataPagesPerAccess := oram.metadata_pages_per_access
                , bucketsPerAccess := oram.buckets_per_access
                , accessesPerCall := oram.accesses_per_call
                } := by
            simpa
              [ WellFormedPathOramObject
              , translationPathOramScheme
              , pathOramScheme
              , translationOramBucketHeaderBytes
              , oramBucketHeaderBytes
              , pathOramStashBound
              , pathOramStashBoundLimit
              , translationPathOramStashBound
              , translationPathOramStashBoundLimit
              , hPathScheme
              ] using
              And.intro hPathScheme <|
                And.intro hBlocksPerBucket <|
                And.intro hBucketSize <|
                And.intro hBucketCount <|
                And.intro hStashBound <|
                And.intro hRecursionDepth <|
                And.intro hMetadataPagesPerAccess <|
                And.intro hBucketsPerAccess hAccessesPerCall
          refine
            ⟨{ objectId := stateObject.id
             , objectName := stateObject.name
             , capacity := stateObject.capacity.getD 1
             , scheme := oram.scheme
             , blockSize := oram.block_size
             , bucketSize := oram.bucket_size
             , bucketCount := oram.bucket_count
             , blocksPerBucket := oram.blocks_per_bucket
             , treeHeight := oram.tree_height
             , stashBound := oram.stash_bound
             , recursionDepth := oram.recursion_depth
             , metadataPages := oram.metadata_pages
             , metadataPagesPerAccess := oram.metadata_pages_per_access
             , bucketsPerAccess := oram.buckets_per_access
             , accessesPerCall := oram.accesses_per_call
             }, ?_, ?_, ?_⟩
          · simp [ImportedProofRelevantManifestObjectView.toOramObjectManifest?, hOram]
          ·
            right
            left
            exact hWellFormedPath
          ·
            intro _hMany
            exact Or.inl hWellFormedPath
        · by_cases hPrivateScheme : oram.scheme = translationPathOramPrivatePosmapScheme
          · have hBlocksPerBucket : oram.blocks_per_bucket = 5 := by
              by_cases hEq : oram.blocks_per_bucket = 5
              · exact hEq
              · simp [validateImportedOramShape, hOram, hPrivateScheme, hEq,
                  translationSurrogateOramScheme, translationPathOramScheme,
                  translationPathOramPrivatePosmapScheme, translationIsPathOramScheme,
                  translationPathOramPositionMapShapeWellFormed] at hShape
            have hBucketSize :
                oram.bucket_size =
                  translationOramBucketHeaderBytes + oram.blocks_per_bucket * oram.block_size := by
              by_cases hEq :
                  oram.bucket_size =
                    translationOramBucketHeaderBytes + oram.blocks_per_bucket * oram.block_size
              · exact hEq
              · simp [validateImportedOramShape, hOram, hPrivateScheme, hEq,
                  translationSurrogateOramScheme, translationPathOramScheme,
                  translationPathOramPrivatePosmapScheme, translationIsPathOramScheme,
                  translationPathOramPositionMapShapeWellFormed] at hShape
            have hBucketCount : 0 < oram.bucket_count := by
              by_cases hPos : 0 < oram.bucket_count
              · exact hPos
              · simp [validateImportedOramShape, hOram, hPrivateScheme, hPos,
                  translationSurrogateOramScheme, translationPathOramScheme,
                  translationPathOramPrivatePosmapScheme, translationIsPathOramScheme,
                  translationPathOramPositionMapShapeWellFormed] at hShape
            have hStashBound :
                oram.stash_bound = translationPathOramTreeStashBound (stateObject.capacity.getD 1) := by
              by_cases hEq : oram.stash_bound = translationPathOramTreeStashBound (stateObject.capacity.getD 1)
              · exact hEq
              · simp [validateImportedOramShape, hOram, hPrivateScheme, hEq,
                  translationSurrogateOramScheme, translationPathOramScheme,
                  translationPathOramPrivatePosmapScheme, translationIsPathOramScheme,
                  translationPathOramPositionMapShapeWellFormed] at hShape
            have hRecursionDepth : oram.recursion_depth = 1 := by
              by_cases hEq : oram.recursion_depth = 1
              · exact hEq
              · simp [validateImportedOramShape, hOram, hPrivateScheme, hEq,
                  translationSurrogateOramScheme, translationPathOramScheme,
                  translationPathOramPrivatePosmapScheme, translationIsPathOramScheme,
                  translationPathOramPositionMapShapeWellFormed] at hShape
            have hMetadataPagesPerAccess :
                oram.metadata_pages_per_access = oram.metadata_pages + 1 := by
              by_cases hEq : oram.metadata_pages_per_access = oram.metadata_pages + 1
              · exact hEq
              · simp [validateImportedOramShape, hOram, hPrivateScheme, hEq,
                  translationSurrogateOramScheme, translationPathOramScheme,
                  translationPathOramPrivatePosmapScheme, translationIsPathOramScheme,
                  translationPathOramPositionMapShapeWellFormed] at hShape
            have hBucketsPerAccess :
                oram.buckets_per_access = oram.tree_height + 1 := by
              by_cases hEq : oram.buckets_per_access = oram.tree_height + 1
              · exact hEq
              · simp [validateImportedOramShape, hOram, hPrivateScheme, hEq,
                  translationSurrogateOramScheme, translationPathOramScheme,
                  translationPathOramPrivatePosmapScheme, translationIsPathOramScheme,
                  translationPathOramPositionMapShapeWellFormed] at hShape
            have hAccessesPerCall : oram.accesses_per_call = 1 := by
              by_cases hEq : oram.accesses_per_call = 1
              · exact hEq
              · simp [validateImportedOramShape, hOram, hPrivateScheme, hEq,
                  translationSurrogateOramScheme, translationPathOramScheme,
                  translationPathOramPrivatePosmapScheme, translationIsPathOramScheme,
                  translationPathOramPositionMapShapeWellFormed] at hShape
            have hWellFormedPrivate :
                WellFormedPrivatePathOramObject
                  { objectId := stateObject.id
                  , objectName := stateObject.name
                  , capacity := stateObject.capacity.getD 1
                  , scheme := oram.scheme
                  , blockSize := oram.block_size
                  , bucketSize := oram.bucket_size
                  , bucketCount := oram.bucket_count
                  , blocksPerBucket := oram.blocks_per_bucket
                  , treeHeight := oram.tree_height
                  , stashBound := oram.stash_bound
                  , recursionDepth := oram.recursion_depth
                  , metadataPages := oram.metadata_pages
                  , metadataPagesPerAccess := oram.metadata_pages_per_access
                  , bucketsPerAccess := oram.buckets_per_access
                  , accessesPerCall := oram.accesses_per_call
                  } := by
              simpa
                [ WellFormedPrivatePathOramObject
                , translationPathOramPrivatePosmapScheme
                , privatePathOramScheme
                , translationOramBucketHeaderBytes
                , oramBucketHeaderBytes
                , pathOramTreeStashBound
                , pathOramStashBoundLimit
                , translationPathOramTreeStashBound
                , translationPathOramStashBoundLimit
                , hPrivateScheme
                ] using
                And.intro hPrivateScheme <|
                  And.intro hBlocksPerBucket <|
                  And.intro hBucketSize <|
                  And.intro hBucketCount <|
                  And.intro hStashBound <|
                  And.intro hRecursionDepth <|
                  And.intro hMetadataPagesPerAccess <|
                  And.intro hBucketsPerAccess hAccessesPerCall
            refine
              ⟨{ objectId := stateObject.id
               , objectName := stateObject.name
               , capacity := stateObject.capacity.getD 1
               , scheme := oram.scheme
               , blockSize := oram.block_size
               , bucketSize := oram.bucket_size
               , bucketCount := oram.bucket_count
               , blocksPerBucket := oram.blocks_per_bucket
               , treeHeight := oram.tree_height
               , stashBound := oram.stash_bound
               , recursionDepth := oram.recursion_depth
               , metadataPages := oram.metadata_pages
               , metadataPagesPerAccess := oram.metadata_pages_per_access
               , bucketsPerAccess := oram.buckets_per_access
               , accessesPerCall := oram.accesses_per_call
               }, ?_, ?_, ?_⟩
            · simp [ImportedProofRelevantManifestObjectView.toOramObjectManifest?, hOram]
            ·
              right
              right
              exact hWellFormedPrivate
            ·
              intro _hMany
              exact Or.inr hWellFormedPrivate
          · simp [validateImportedOramShape, hOram, hNotSurrogate,
              translationSurrogateOramScheme, translationPathOramScheme,
              translationPathOramPrivatePosmapScheme, translationIsPathOramScheme] at hShape
            rcases hShape with ⟨_hPrefix, hPathLike, _hRest⟩
            rcases hPathLike with hLocal | hPrivate
            · exact False.elim (hPathScheme (by simpa [translationPathOramScheme] using hLocal))
            · exact False.elim
                (hPrivateScheme (by simpa [translationPathOramPrivatePosmapScheme] using hPrivate))

theorem ImportedProofRelevantContractView.exists_buildExpectedOramObjectWitnesses_of_expected
  (view : ImportedProofRelevantContractView)
  {expected : List (Nat × Nat)}
  (hWitness :
    ∀ {objectId accesses},
      (objectId, accesses) ∈ expected →
        ∃ stateObject manifestObject object,
          stateObjectById? view.state objectId = some stateObject ∧
          manifestObjectById? view.manifest.objects objectId = some manifestObject ∧
          manifestObject.toOramObjectManifest? stateObject = some object ∧
          WellFormedOramObject object) :
  ∃ objects,
    view.buildExpectedOramObjectWitnesses expected = .ok objects ∧
    ∀ object, object ∈ objects → WellFormedOramObject object := by
  revert hWitness
  induction expected with
  | nil =>
      intro hWitness
      refine ⟨[], ?_, ?_⟩
      simp [ImportedProofRelevantContractView.buildExpectedOramObjectWitnesses]
      intro object hMem
      simp at hMem
  | cons head tail ih =>
      intro hWitness
      rcases
          hWitness
            (objectId := head.fst)
            (accesses := head.snd)
            (by simp) with
        ⟨stateObject, manifestObject, object, hState, hManifest, hObject, hWellFormed⟩
      have hWitnessTail :
        ∀ {objectId accesses},
          (objectId, accesses) ∈ tail →
            ∃ stateObject manifestObject object,
              stateObjectById? view.state objectId = some stateObject ∧
              manifestObjectById? view.manifest.objects objectId = some manifestObject ∧
              manifestObject.toOramObjectManifest? stateObject = some object ∧
              WellFormedOramObject object := by
        intro objectId accesses hMem
        exact
          hWitness
            (objectId := objectId)
            (accesses := accesses)
            (by simp [hMem])
      rcases ih hWitnessTail with ⟨objects, hBuildTail, hForallTail⟩
      refine ⟨object :: objects, ?_, ?_⟩
      ·
        let buildOne : Nat × Nat → Except String OramObjectManifest := fun entry => do
          let objectId := entry.fst
          let stateObject ←
            match stateObjectById? view.state objectId with
            | some object => pure object
            | none => throw s!"missing state object {objectId} for ORAM witness"
          let manifestObject ←
            match manifestObjectById? view.manifest.objects objectId with
            | some object => pure object
            | none => throw s!"missing manifest object {objectId} for ORAM witness"
          match manifestObject.toOramObjectManifest? stateObject with
          | some object => pure object
          | none => throw s!"object {objectId} does not carry ORAM metadata"
        have hMapHead : buildOne head = Except.ok object := by
          change
            (do
              let stateObject ←
                match stateObjectById? view.state head.fst with
                | some object => pure object
                | none => throw s!"missing state object {head.fst} for ORAM witness"
              let manifestObject ←
                match manifestObjectById? view.manifest.objects head.fst with
                | some object => pure object
                | none => throw s!"missing manifest object {head.fst} for ORAM witness"
              match manifestObject.toOramObjectManifest? stateObject with
              | some object => pure object
              | none => throw s!"object {head.fst} does not carry ORAM metadata") =
              Except.ok object
          rw [hState, hManifest]
          change
            (match manifestObject.toOramObjectManifest? stateObject with
            | some object => Except.ok object
            | none => throw s!"object {head.fst} does not carry ORAM metadata") =
            Except.ok object
          rw [hObject]
        have hMapTail : tail.mapM buildOne = Except.ok objects := by
          simpa [ImportedProofRelevantContractView.buildExpectedOramObjectWitnesses, buildOne] using
            hBuildTail
        simpa [ImportedProofRelevantContractView.buildExpectedOramObjectWitnesses, buildOne] using
          (show List.mapM buildOne (head :: tail) = Except.ok (object :: objects) from by
            rw [List.mapM_cons, hMapHead, hMapTail]
            rfl)
      ·
        intro object' hMem
        simp at hMem
        rcases hMem with rfl | hMemTail
        · exact hWellFormed
        · exact hForallTail object' hMemTail

theorem ImportedProofRelevantContractView.exists_buildExpectedOramObjectWitnesses_aligned_of_expected
  (view : ImportedProofRelevantContractView)
  {expected : List (Nat × Nat)}
  (hWitness :
    ∀ {objectId accesses},
      (objectId, accesses) ∈ expected →
        ∃ stateObject manifestObject object,
          stateObjectById? view.state objectId = some stateObject ∧
          manifestObjectById? view.manifest.objects objectId = some manifestObject ∧
          manifestObject.toOramObjectManifest? stateObject = some object ∧
          WellFormedOramObject object ∧
          ((1 < accesses) → WellFormedAnyPathOramObject object)) :
  ∃ objects,
    view.buildExpectedOramObjectWitnesses expected = .ok objects ∧
    ExpectedOramObjectWitnessAlignment expected objects := by
  revert hWitness
  induction expected with
  | nil =>
      intro hWitness
      refine ⟨[], ?_, ?_⟩
      · simp [ImportedProofRelevantContractView.buildExpectedOramObjectWitnesses]
      · exact ExpectedOramObjectWitnessAlignment.nil
  | cons head tail ih =>
      intro hWitness
      rcases
          hWitness
            (objectId := head.fst)
            (accesses := head.snd)
            (by simp) with
        ⟨stateObject, manifestObject, object, hState, hManifest, hObject, hWellFormed, hPathIfMany⟩
      have hWitnessTail :
        ∀ {objectId accesses},
          (objectId, accesses) ∈ tail →
            ∃ stateObject manifestObject object,
              stateObjectById? view.state objectId = some stateObject ∧
              manifestObjectById? view.manifest.objects objectId = some manifestObject ∧
              manifestObject.toOramObjectManifest? stateObject = some object ∧
              WellFormedOramObject object ∧
              ((1 < accesses) → WellFormedAnyPathOramObject object) := by
        intro objectId accesses hMem
        exact
          hWitness
            (objectId := objectId)
            (accesses := accesses)
            (by simp [hMem])
      rcases ih hWitnessTail with ⟨objects, hBuildTail, hAlignedTail⟩
      refine ⟨object :: objects, ?_, ?_⟩
      ·
        let buildOne : Nat × Nat → Except String OramObjectManifest := fun entry => do
          let objectId := entry.fst
          let stateObject ←
            match stateObjectById? view.state objectId with
            | some object => pure object
            | none => throw s!"missing state object {objectId} for ORAM witness"
          let manifestObject ←
            match manifestObjectById? view.manifest.objects objectId with
            | some object => pure object
            | none => throw s!"missing manifest object {objectId} for ORAM witness"
          match manifestObject.toOramObjectManifest? stateObject with
          | some object => pure object
          | none => throw s!"object {objectId} does not carry ORAM metadata"
        have hMapHead : buildOne head = Except.ok object := by
          change
            (do
              let stateObject ←
                match stateObjectById? view.state head.fst with
                | some object => pure object
                | none => throw s!"missing state object {head.fst} for ORAM witness"
              let manifestObject ←
                match manifestObjectById? view.manifest.objects head.fst with
                | some object => pure object
                | none => throw s!"missing manifest object {head.fst} for ORAM witness"
              match manifestObject.toOramObjectManifest? stateObject with
              | some object => pure object
              | none => throw s!"object {head.fst} does not carry ORAM metadata") =
              Except.ok object
          rw [hState, hManifest]
          change
            (match manifestObject.toOramObjectManifest? stateObject with
            | some object => Except.ok object
            | none => throw s!"object {head.fst} does not carry ORAM metadata") =
            Except.ok object
          rw [hObject]
        have hMapTail : tail.mapM buildOne = Except.ok objects := by
          simpa [ImportedProofRelevantContractView.buildExpectedOramObjectWitnesses, buildOne] using
            hBuildTail
        simpa [ImportedProofRelevantContractView.buildExpectedOramObjectWitnesses, buildOne] using
          (show List.mapM buildOne (head :: tail) = Except.ok (object :: objects) from by
            rw [List.mapM_cons, hMapHead, hMapTail]
            rfl)
      ·
        exact ExpectedOramObjectWitnessAlignment.cons hWellFormed hPathIfMany hAlignedTail

theorem proofGradeManifestFieldsExactOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  (entry.secret_args = fn.secret_args ∧
    entry.param_names = fn.params.map ImportedProofRelevantParamView.name) ∧
    (∃ inputLen returnLen,
      expectedEntrypointInputLen fn = .ok inputLen ∧
      expectedReturnCanonicalLen fn = .ok returnLen ∧
      entry.entry_input_len = inputLen ∧
      entry.return_canonical_len = returnLen) ∧
    (∃ counts,
      countBodyStrings fn.body = .ok counts ∧
      entry.arena_bytes = 4096 + counts.localCount * 64 ∧
      entry.max_stack_words = 64 + counts.localCount ∧
      entry.uocell_reads = counts.cellReads ∧
      entry.uocell_writes = counts.cellWrites ∧
      entry.uoarray_reads = counts.arrayReads ∧
      entry.uoarray_writes = counts.arrayWrites ∧
      entry.uomap_reads = counts.mapReads ∧
      entry.uomap_writes = counts.mapWrites) ∧
    (∃ expectedOramAccesses,
      countFunctionOramAccesses fn bundle.source_view.state = .ok expectedOramAccesses ∧
      oramAccessesMatchExpected expectedOramAccesses entry.oram_accesses = true ∧
      ∀ objectId accesses,
        (objectId, accesses) ∈ expectedOramAccesses →
          (match
              stateObjectById? bundle.source_view.state objectId,
              manifestObjectById? bundle.source_view.manifest.objects objectId with
          | some stateObject, some manifestObject =>
              validateImportedOramShape stateObject manifestObject accesses
          | _, _ => false) = true) ∧
    (∃ maxCommitOps,
      expectedCommitOpsForFunction bundle.source_view fn = .ok maxCommitOps ∧
      entry.max_commit_ops = maxCommitOps) := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · exact
      bundle.source_view.manifest_secrets_exact_of_lookup
        (bundle.source_view_structural_valid hValid)
        hMem
        hLookup
  · exact
      bundle.source_view.manifest_boundary_lengths_exact_of_lookup
        (bundle.source_view_structural_valid hValid)
        hMem
        hLookup
  · exact
      bundle.source_view.manifest_counts_exact_of_lookup
        (bundle.source_view_structural_valid hValid)
        hMem
        hLookup
  · exact
      bundle.source_view.manifest_oram_accesses_exact_of_lookup
        (bundle.source_view_structural_valid hValid)
        hMem
        hLookup
  · exact
      bundle.source_view.manifest_commit_ops_exact_of_lookup
        (bundle.source_view_structural_valid hValid)
        hMem
        hLookup

theorem proofGradeManifestWitnessWithExpectedOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected witness,
    countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
    witness = entry.toManifestWitnessWithExpected expected ∧
    witness.secretArgs = fn.secret_args ∧
    witness.publicGasBudget = entry.public_gas_budget ∧
    witness.oramAccesses = expected := by
  rcases
      bundle.source_view.manifest_oram_accesses_exact_of_lookup
        (bundle.source_view_structural_valid hValid)
        hMem
        hLookup with
    ⟨expected, hExpected, _hMatchExpected, _hShape⟩
  have hSecrets :=
    bundle.source_view.manifest_secrets_exact_of_lookup
      (bundle.source_view_structural_valid hValid)
      hMem
      hLookup
  refine ⟨expected, entry.toManifestWitnessWithExpected expected, hExpected, rfl, ?_, rfl, rfl⟩
  simpa [ImportedProofRelevantEntrypointView.toManifestWitnessWithExpected] using hSecrets.1

theorem proofGradeExpectedOramObjectWitnessExistsOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∀ {objectId accesses},
    (objectId, accesses) ∈
        (match countFunctionOramAccesses fn bundle.source_view.state with
        | .ok expected => expected
        | .error _ => []) →
      ∃ stateObject manifestObject object,
        stateObjectById? bundle.source_view.state objectId = some stateObject ∧
        manifestObjectById? bundle.source_view.manifest.objects objectId = some manifestObject ∧
        manifestObject.toOramObjectManifest? stateObject = some object ∧
        WellFormedOramObject object ∧
        ((1 < accesses) → WellFormedAnyPathOramObject object) := by
  rcases
      bundle.source_view.manifest_oram_accesses_exact_of_lookup
        (bundle.source_view_structural_valid hValid)
        hMem
        hLookup with
    ⟨expected, hExpected, _hMatchExpected, hShape⟩
  intro objectId accesses hMemExpected
  have hShapeForObject := hShape objectId accesses (by simpa [hExpected] using hMemExpected)
  cases hState : stateObjectById? bundle.source_view.state objectId with
  | none =>
      simp [hState] at hShapeForObject
  | some stateObject =>
      cases hManifest : manifestObjectById? bundle.source_view.manifest.objects objectId with
      | none =>
          simp [hState, hManifest] at hShapeForObject
      | some manifestObject =>
          simp [hState, hManifest] at hShapeForObject
          rcases
              manifestObject.exists_oramObjectManifest_of_validateImportedOramShape
                (stateObject := stateObject)
                (accesses := accesses)
                hShapeForObject with
            ⟨object, hObject, hWellFormed, hPathIfMany⟩
          refine ⟨stateObject, manifestObject, object, ?_⟩
          simp [hObject, hWellFormed]
          exact hPathIfMany

theorem proofGradeExpectedOramObjectWitnessesBuildOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected objects,
    countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
    bundle.source_view.buildExpectedOramObjectWitnesses expected = .ok objects ∧
    ∀ object, object ∈ objects → WellFormedOramObject object := by
  rcases
      bundle.source_view.manifest_oram_accesses_exact_of_lookup
        (bundle.source_view_structural_valid hValid)
        hMem
        hLookup with
    ⟨expected, hExpected, _hMatchExpected, _hShape⟩
  have hWitness :
    ∀ {objectId accesses},
      (objectId, accesses) ∈ expected →
        ∃ stateObject manifestObject object,
          stateObjectById? bundle.source_view.state objectId = some stateObject ∧
          manifestObjectById? bundle.source_view.manifest.objects objectId = some manifestObject ∧
          manifestObject.toOramObjectManifest? stateObject = some object ∧
          WellFormedOramObject object := by
    intro objectId accesses hMemExpected
    rcases
        proofGradeExpectedOramObjectWitnessExistsOfLookup
          bundle hValid hMem hLookup
          (by simpa [hExpected] using hMemExpected) with
      ⟨stateObject, manifestObject, object, hState, hManifest, hObject, hWellFormed, _hPathIfMany⟩
    exact ⟨stateObject, manifestObject, object, hState, hManifest, hObject, hWellFormed⟩
  rcases
      bundle.source_view.exists_buildExpectedOramObjectWitnesses_of_expected
        (expected := expected)
        hWitness with
    ⟨objects, hBuildObjects, hForallObjects⟩
  exact ⟨expected, objects, hExpected, hBuildObjects, hForallObjects⟩

theorem proofGradeExpectedPathOramObjectWitnessExistsOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∀ {objectId accesses},
    (objectId, accesses) ∈
        (match countFunctionOramAccesses fn bundle.source_view.state with
        | .ok expected => expected
        | .error _ => []) →
      1 < accesses →
      ∃ stateObject manifestObject object,
        stateObjectById? bundle.source_view.state objectId = some stateObject ∧
        manifestObjectById? bundle.source_view.manifest.objects objectId = some manifestObject ∧
        manifestObject.toOramObjectManifest? stateObject = some object ∧
        WellFormedAnyPathOramObject object := by
  intro objectId accesses hMemExpected hMany
  rcases
      proofGradeExpectedOramObjectWitnessExistsOfLookup
        bundle hValid hMem hLookup hMemExpected with
    ⟨stateObject, manifestObject, object, hState, hManifest, hObject, _hWellFormed, hPathIfMany⟩
  exact ⟨stateObject, manifestObject, object, hState, hManifest, hObject, hPathIfMany hMany⟩

theorem proofGradeExpectedOramObjectWitnessesAlignedOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected objects,
    countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
    bundle.source_view.buildExpectedOramObjectWitnesses expected = .ok objects ∧
    ExpectedOramObjectWitnessAlignment expected objects := by
  rcases
      bundle.source_view.manifest_oram_accesses_exact_of_lookup
        (bundle.source_view_structural_valid hValid)
        hMem
        hLookup with
    ⟨expected, hExpected, _hMatchExpected, _hShape⟩
  have hWitness :
    ∀ {objectId accesses},
      (objectId, accesses) ∈ expected →
        ∃ stateObject manifestObject object,
          stateObjectById? bundle.source_view.state objectId = some stateObject ∧
          manifestObjectById? bundle.source_view.manifest.objects objectId = some manifestObject ∧
          manifestObject.toOramObjectManifest? stateObject = some object ∧
          WellFormedOramObject object ∧
          ((1 < accesses) → WellFormedAnyPathOramObject object) := by
    intro objectId accesses hMemExpected
    exact
      proofGradeExpectedOramObjectWitnessExistsOfLookup
        bundle hValid hMem hLookup
        (by simpa [hExpected] using hMemExpected)
  rcases
      bundle.source_view.exists_buildExpectedOramObjectWitnesses_aligned_of_expected
        (expected := expected)
        hWitness with
    ⟨objects, hBuildObjects, hAligned⟩
  exact ⟨expected, objects, hExpected, hBuildObjects, hAligned⟩

theorem proofGradeOramEntrypointWitnessAlignedExactOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected witness,
    countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
    bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
    witness.entrypointId = entry.signature ∧
    witness.secretArgs = fn.secret_args ∧
    witness.publicGasBudget = entry.public_gas_budget ∧
    witness.oramAccesses = expected ∧
    ExpectedOramObjectWitnessAlignment expected witness.oramObjects := by
  rcases
      proofGradeExpectedOramObjectWitnessesAlignedOfLookup
        bundle hValid hMem hLookup with
    ⟨expected, objects, hExpected, hBuildObjects, hAligned⟩
  have hSecrets :=
    bundle.source_view.manifest_secrets_exact_of_lookup
      (bundle.source_view_structural_valid hValid)
      hMem
      hLookup
  refine
    ⟨ expected
    , { (entry.toManifestWitnessWithExpected expected) with
        entrypointId := entry.signature
        oramObjects := objects
      }
    , hExpected
    , ?_
    , rfl
    , ?_
    , rfl
    , rfl
    , hAligned
    ⟩
  ·
    rw [ImportedProofRelevantContractView.toOramEntrypointWitnessFromExpected, hBuildObjects]
    rfl
  ·
    simpa [ImportedProofRelevantEntrypointView.toManifestWitnessWithExpected] using hSecrets.1

theorem proofGradeOramEntrypointWitnessExactOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected witness,
    countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
    bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
    witness.entrypointId = entry.signature ∧
    witness.secretArgs = fn.secret_args ∧
    witness.publicGasBudget = entry.public_gas_budget ∧
    witness.oramAccesses = expected ∧
    ∀ object, object ∈ witness.oramObjects → WellFormedOramObject object := by
  rcases
      proofGradeOramEntrypointWitnessAlignedExactOfLookup
        bundle hValid hMem hLookup with
    ⟨expected, witness, hExpected, hWitness, hEntryId, hSecretArgs, hGas, hAccesses, hAligned⟩
  refine ⟨expected, witness, hExpected, hWitness, hEntryId, hSecretArgs, hGas, hAccesses, ?_⟩
  exact hAligned.objectsWellFormed

theorem proofGradeOramEntrypointWitnessObjectCountExactOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected witness,
    countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
    bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
    witness.oramObjects.length = expected.length := by
  rcases
      proofGradeOramEntrypointWitnessAlignedExactOfLookup
        bundle hValid hMem hLookup with
    ⟨expected, witness, hExpected, hWitness, _hEntryId, _hSecretArgs, _hGas, _hAccesses, hAligned⟩
  exact ⟨expected, witness, hExpected, hWitness, hAligned.length_eq.symm⟩

theorem proofGradeConfidentialKernelLoweringExactOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry)
  (hConf : fn.confidential = true) :
  ∃ expectedProgram fnProgram fnSlotProgram entryProgram entrySlotProgram expectedHashPartBytes,
    expectedConfidentialKernelProgramForFunction fn = .ok expectedProgram ∧
    parseFunctionConfidentialProgram fn = .ok (some fnProgram) ∧
    parseFunctionConfidentialSlotProgram fn = .ok (some fnSlotProgram) ∧
    parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
    parseEntrypointConfidentialSlotProgram entry = .ok (some entrySlotProgram) ∧
    importedConfidentialKernelProgramEq fnProgram expectedProgram = true ∧
    fnProgram.expectedRuntimeKernelSteps = expectedProgram.expectedRuntimeKernelSteps ∧
    importedConfidentialKernelProgramEq fnProgram entryProgram = true ∧
    fnProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps ∧
    checkImportedConfidentialKernelProgramSlotLowering fnProgram fnSlotProgram = true ∧
    checkImportedConfidentialKernelProgramSlotLowering entryProgram entrySlotProgram = true ∧
    fn.confidential_program = entry.confidential_program ∧
    fn.confidential_slot_program = entry.confidential_slot_program ∧
    importedConfidentialKernelProgramMaxHashPartBytes bundle.source_view.state entryProgram = .ok expectedHashPartBytes ∧
    entryProgram.entrypoint_id = fn.signature ∧
    entrySlotProgram.entrypoint_id = fn.signature ∧
    entryProgram.secret_args = fn.secret_args ∧
    entrySlotProgram.secret_args = fn.secret_args ∧
    entry.max_hash_part_bytes = expectedHashPartBytes ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        entryProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        entrySlotProgram.expectedRuntimeKernelSteps = entry.kernel_steps := by
  exact
    functionConfidentialLoweringMatchesManifest_confidential_exact
      (bundle.source_view.confidential_lowering_exact_of_lookup
        (bundle.source_view_structural_valid hValid)
      hMem
      hLookup)
    hConf

theorem proofGradeSourceExpectedKernelScheduleExactOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry)
  (hConf : fn.confidential = true) :
  ∃ expectedProgram entryProgram,
    expectedConfidentialKernelProgramForFunction fn = .ok expectedProgram ∧
    parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
    expectedProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      expectedProgram.expectedRuntimeKernelSteps = entry.kernel_steps := by
  rcases
      proofGradeConfidentialKernelLoweringExactOfLookup
        bundle hValid hMem hLookup hConf with
    ⟨ expectedProgram
    , fnProgram
    , _fnSlotProgram
    , entryProgram
    , _entrySlotProgram
    , _expectedHashPartBytes
    , hExpected
    , _hFnProgram
    , _hFnSlotProgram
    , hEntryProgram
    , _hEntrySlotProgram
    , _hFnProgramExpected
    , hFnExpectedSchedule
    , _hFnProgramEntry
    , hFnEntrySchedule
    , _hFnSlotLowering
    , _hEntrySlotLowering
    , _hProgramEq
    , _hSlotEq
    , _hHash
    , _hEntryProgramId
    , _hEntrySlotProgramId
    , _hEntryProgramSecrets
    , _hEntrySlotProgramSecrets
    , _hHashBound
    , hEntrySteps
    , _hEntrySlotSteps
    ⟩
  have hExpectedEntrySchedule :
      expectedProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps := by
    exact hFnExpectedSchedule.symm.trans hFnEntrySchedule
  have hExpectedProofRelevantSteps :
      importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        expectedProgram.expectedRuntimeKernelSteps = entry.kernel_steps := by
    simpa [hExpectedEntrySchedule] using hEntrySteps
  exact
    ⟨expectedProgram, entryProgram, hExpected, hEntryProgram,
      hExpectedEntrySchedule, hExpectedProofRelevantSteps⟩

theorem proofGradeOramEntrypointRecomputedSlotLoweringExactOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry)
  (hConf : fn.confidential = true) :
  ∃ expected witness entryProgram entrySlotProgram lowered,
    countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
    bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
    parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
    parseEntrypointConfidentialSlotProgram entry = .ok (some entrySlotProgram) ∧
    entryProgram.toConfidentialKernelSlotProgram? = .ok lowered ∧
    checkImportedConfidentialKernelSlotProgramEq lowered entrySlotProgram = true ∧
    lowered.entrypoint_id = entry.signature ∧
    lowered.secret_args = fn.secret_args ∧
    witness.entrypointId = lowered.entrypoint_id ∧
    witness.secretArgs = lowered.secret_args ∧
    witness.publicGasBudget = entry.public_gas_budget ∧
    witness.oramAccesses = expected ∧
    ExpectedOramObjectWitnessAlignment expected witness.oramObjects ∧
    entryProgram.toConfidentialKernelProgram.SlotLoweringMatches
      lowered.toConfidentialKernelSlotProgram ∧
    lowered.RuntimeNormalForm ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      entrySlotProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      entryProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    entryProgram.expectedRuntimeKernelSteps = lowered.expectedRuntimeKernelSteps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      lowered.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    entryProgram.toConfidentialKernelProgram.expectedRuntimeKernelSteps =
      lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
    lowered.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
      lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
  rcases
      proofGradeOramEntrypointWitnessAlignedExactOfLookup
        bundle hValid hMem hLookup with
    ⟨expected, witness, hExpected, hWitness, hWitnessEntryId, hWitnessSecretArgs, hGas, hAccesses, hAligned⟩
  rcases
      proofGradeConfidentialKernelLoweringExactOfLookup
        bundle hValid hMem hLookup hConf with
    ⟨ _expectedProgram
    , _fnProgram
    , _fnSlotProgram
    , entryProgram
    , entrySlotProgram
    , _expectedHashPartBytes
    , _hExpectedProgram
    , _hFnProgram
    , _hFnSlotProgram
    , hEntryProgram
    , hEntrySlotProgram
    , _hFnEq
    , _hFnExpectedSchedule
    , _hFnEntryEq
    , _hFnEntrySchedule
    , _hFnSlotLowering
    , hEntrySlotLowering
    , _hProgramEq
    , _hSlotEq
    , _hHash
    , _hEntryProgramId
    , hEntrySlotProgramId
    , _hEntryProgramSecrets
    , hEntrySlotProgramSecrets
    , _hHashBound
    , hEntrySteps
    , hEntrySlotSteps
    ⟩
  have hImportedLowering : entryProgram.SlotLoweringMatches entrySlotProgram := by
    exact (checkImportedConfidentialKernelProgramSlotLowering_eq_true_iff
      entryProgram entrySlotProgram).mp hEntrySlotLowering
  rcases importedConfidentialKernelProgram_slotLowering_exists
      entryProgram entrySlotProgram hImportedLowering with
    ⟨lowered, hLowered⟩
  have hLoweredStored :
      checkImportedConfidentialKernelSlotProgramEq lowered entrySlotProgram = true := by
    unfold ImportedConfidentialKernelProgram.SlotLoweringMatches
      checkImportedConfidentialKernelProgramSlotLowering at hImportedLowering
    rw [hLowered] at hImportedLowering
    exact hImportedLowering
  have hLoweredEqTree := hLoweredStored
  simp [checkImportedConfidentialKernelSlotProgramEq, Bool.and_eq_true] at hLoweredEqTree
  have hLoweredEntryId :
      lowered.entrypoint_id = entrySlotProgram.entrypoint_id := by
    exact hLoweredEqTree.1.1.1.1.1
  have hLoweredSecrets :
      lowered.secret_args = entrySlotProgram.secret_args := by
    exact hLoweredEqTree.1.1.2
  have hLoweredRuntime :
      entryProgram.toConfidentialKernelProgram.SlotLoweringMatches
        lowered.toConfidentialKernelSlotProgram := by
    exact importedConfidentialKernelProgram_slotLowering_ok_toRuntime hLowered
  have hNamedImportedSteps :
      entryProgram.expectedRuntimeKernelSteps = lowered.expectedRuntimeKernelSteps := by
    exact importedConfidentialKernelProgram_slotLowering_ok_expectedRuntimeKernelSteps hLowered
  have hLoweredProofRelevantSteps :
      importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        lowered.expectedRuntimeKernelSteps = entry.kernel_steps := by
    simpa [hNamedImportedSteps] using hEntrySteps
  have hRuntimeStepEq :
      entryProgram.toConfidentialKernelProgram.expectedRuntimeKernelSteps =
        lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
    exact confidentialKernelProgram_slotLowering_expectedRuntimeKernelSteps hLoweredRuntime
  have hLoweredNormal : lowered.RuntimeNormalForm := by
    exact importedConfidentialKernelProgram_slotLowering_ok_runtimeNormalForm hLowered
  have hLookupSignature : entry.signature = fn.signature := by
    exact lookupEntrypoint_signature_exact hLookup
  have hLoweredEntrySignature : lowered.entrypoint_id = entry.signature := by
    exact hLoweredEntryId.trans hEntrySlotProgramId |>.trans hLookupSignature.symm
  have hLoweredSecretArgs : lowered.secret_args = fn.secret_args := by
    exact hLoweredSecrets.trans hEntrySlotProgramSecrets
  refine
    ⟨ expected
    , witness
    , entryProgram
    , entrySlotProgram
    , lowered
    , hExpected
    , hWitness
    , hEntryProgram
    , hEntrySlotProgram
    , hLowered
    , hLoweredStored
    , hLoweredEntrySignature
    , hLoweredSecretArgs
    , hWitnessEntryId.trans hLoweredEntrySignature.symm
    , hWitnessSecretArgs.trans hLoweredSecretArgs.symm
    , hGas
    , hAccesses
    , hAligned
    , hLoweredRuntime
    , hLoweredNormal
    , hEntrySlotSteps
    , hEntrySteps
    , hNamedImportedSteps
    , hLoweredProofRelevantSteps
    , hRuntimeStepEq
    , importedConfidentialKernelSlotProgram_expectedRuntimeKernelSteps_toRuntime lowered
    ⟩

theorem proofGradeSourceToRuntimeSlotScheduleExactOfLookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry)
  (hConf : fn.confidential = true) :
  ∃ expectedProgram entryProgram entrySlotProgram lowered runtimeProgram runtimeSlotProgram,
    expectedConfidentialKernelProgramForFunction fn = .ok expectedProgram ∧
    parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
    parseEntrypointConfidentialSlotProgram entry = .ok (some entrySlotProgram) ∧
    entryProgram.toConfidentialKernelSlotProgram? = .ok lowered ∧
    runtimeProgram = entryProgram.toConfidentialKernelProgram ∧
    runtimeSlotProgram = lowered.toConfidentialKernelSlotProgram ∧
    expectedProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps ∧
    entryProgram.expectedRuntimeKernelSteps = lowered.expectedRuntimeKernelSteps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      expectedProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      entryProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      lowered.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    expectedProgram.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
      runtimeProgram.expectedRuntimeKernelSteps ∧
    lowered.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
      runtimeSlotProgram.expectedRuntimeKernelSteps ∧
    runtimeProgram.expectedRuntimeKernelSteps = runtimeSlotProgram.expectedRuntimeKernelSteps := by
  rcases
      proofGradeSourceExpectedKernelScheduleExactOfLookup
        bundle hValid hMem hLookup hConf with
    ⟨expectedProgram, sourceEntryProgram, hExpected, hSourceEntryProgram,
      hExpectedEntrySchedule, hExpectedProofRelevantSteps⟩
  rcases
      proofGradeOramEntrypointRecomputedSlotLoweringExactOfLookup
        bundle hValid hMem hLookup hConf with
    ⟨ _expected
    , _witness
    , entryProgram
    , entrySlotProgram
    , lowered
    , _hOramExpected
    , _hWitness
    , hEntryProgram
    , hEntrySlotProgram
    , hLowered
    , _hStoredEq
    , _hLoweredEntrypoint
    , _hLoweredSecrets
    , _hWitnessEntrypoint
    , _hWitnessSecrets
    , _hGas
    , _hAccesses
    , _hAligned
    , _hRuntimeLowering
    , _hLoweredNormal
    , _hEntrySlotProofRelevantSteps
    , hEntryProofRelevantSteps
    , hEntryLoweredSchedule
    , hLoweredProofRelevantSteps
    , hRuntimeStepEq
    , hLoweredStepsToRuntime
    ⟩
  have hSameEntryProgram : sourceEntryProgram = entryProgram := by
    rw [hEntryProgram] at hSourceEntryProgram
    simpa using hSourceEntryProgram.symm
  subst sourceEntryProgram
  have hExpectedRuntimeProgram :
      expectedProgram.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
        entryProgram.toConfidentialKernelProgram.expectedRuntimeKernelSteps := by
    rw [hExpectedEntrySchedule]
    exact importedConfidentialKernelProgram_expectedRuntimeKernelSteps_toRuntime entryProgram
  refine
    ⟨ expectedProgram
    , entryProgram
    , entrySlotProgram
    , lowered
    , entryProgram.toConfidentialKernelProgram
    , lowered.toConfidentialKernelSlotProgram
    , hExpected
    , hEntryProgram
    , hEntrySlotProgram
    , hLowered
    , rfl
    , rfl
    , hExpectedEntrySchedule
    , hEntryLoweredSchedule
    , hExpectedProofRelevantSteps
    , hEntryProofRelevantSteps
    , hLoweredProofRelevantSteps
    , hExpectedRuntimeProgram
    , hLoweredStepsToRuntime
    , hRuntimeStepEq
    ⟩

structure ProofGradeCompilerFacts
  (bundle : ImportedProofRelevantTranslationBundle) : Prop where
  sourceViewStructuralValid :
    bundle.source_view.StructuralValid
  artifactViewStructuralValid :
    bundle.artifact_view.StructuralValid
  sourceArtifactViewsExact :
    bundle.source_view = bundle.artifact_view
  manifestFieldsExact :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      (entry.secret_args = fn.secret_args ∧
        entry.param_names = fn.params.map ImportedProofRelevantParamView.name) ∧
        (∃ inputLen returnLen,
          expectedEntrypointInputLen fn = .ok inputLen ∧
          expectedReturnCanonicalLen fn = .ok returnLen ∧
          entry.entry_input_len = inputLen ∧
          entry.return_canonical_len = returnLen) ∧
        (∃ counts,
          countBodyStrings fn.body = .ok counts ∧
          entry.arena_bytes = 4096 + counts.localCount * 64 ∧
          entry.max_stack_words = 64 + counts.localCount ∧
          entry.uocell_reads = counts.cellReads ∧
          entry.uocell_writes = counts.cellWrites ∧
          entry.uoarray_reads = counts.arrayReads ∧
          entry.uoarray_writes = counts.arrayWrites ∧
          entry.uomap_reads = counts.mapReads ∧
          entry.uomap_writes = counts.mapWrites) ∧
        (∃ expectedOramAccesses,
          countFunctionOramAccesses fn bundle.source_view.state = .ok expectedOramAccesses ∧
          oramAccessesMatchExpected expectedOramAccesses entry.oram_accesses = true ∧
          ∀ objectId accesses,
            (objectId, accesses) ∈ expectedOramAccesses →
              (match
                  stateObjectById? bundle.source_view.state objectId,
                  manifestObjectById? bundle.source_view.manifest.objects objectId with
              | some stateObject, some manifestObject =>
                  validateImportedOramShape stateObject manifestObject accesses
              | _, _ => false) = true) ∧
        (∃ maxCommitOps,
          expectedCommitOpsForFunction bundle.source_view fn = .ok maxCommitOps ∧
          entry.max_commit_ops = maxCommitOps)
  confidentialKernelLoweringExact :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      fn.confidential = true →
      ∃ expectedProgram fnProgram fnSlotProgram entryProgram entrySlotProgram expectedHashPartBytes,
        expectedConfidentialKernelProgramForFunction fn = .ok expectedProgram ∧
        parseFunctionConfidentialProgram fn = .ok (some fnProgram) ∧
        parseFunctionConfidentialSlotProgram fn = .ok (some fnSlotProgram) ∧
        parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
        parseEntrypointConfidentialSlotProgram entry = .ok (some entrySlotProgram) ∧
        importedConfidentialKernelProgramEq fnProgram expectedProgram = true ∧
        fnProgram.expectedRuntimeKernelSteps = expectedProgram.expectedRuntimeKernelSteps ∧
        importedConfidentialKernelProgramEq fnProgram entryProgram = true ∧
        fnProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps ∧
        checkImportedConfidentialKernelProgramSlotLowering fnProgram fnSlotProgram = true ∧
        checkImportedConfidentialKernelProgramSlotLowering entryProgram entrySlotProgram = true ∧
        fn.confidential_program = entry.confidential_program ∧
        fn.confidential_slot_program = entry.confidential_slot_program ∧
        importedConfidentialKernelProgramMaxHashPartBytes bundle.source_view.state entryProgram = .ok expectedHashPartBytes ∧
        entryProgram.entrypoint_id = fn.signature ∧
        entrySlotProgram.entrypoint_id = fn.signature ∧
        entryProgram.secret_args = fn.secret_args ∧
        entrySlotProgram.secret_args = fn.secret_args ∧
        entry.max_hash_part_bytes = expectedHashPartBytes ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        entryProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
      importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        entrySlotProgram.expectedRuntimeKernelSteps = entry.kernel_steps
  confidentialKernelTargetsNonRaw :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      fn.confidential = true →
      ∀ {kernelStep : ImportedProofRelevantKernelStepView}
        {objectId : Nat},
        kernelStep ∈ entry.kernel_steps →
        kernelStep.object_id = some objectId →
        ∃ stateObject,
          stateObjectById? bundle.source_view.state objectId = some stateObject ∧
            stateObject.backend ≠ "raw"
  sourceExpectedKernelScheduleExact :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      fn.confidential = true →
      ∃ expectedProgram entryProgram,
        expectedConfidentialKernelProgramForFunction fn = .ok expectedProgram ∧
        parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
        expectedProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps ∧
        importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
          expectedProgram.expectedRuntimeKernelSteps = entry.kernel_steps
  sourceToRuntimeSlotScheduleExact :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      fn.confidential = true →
      ∃ expectedProgram entryProgram entrySlotProgram lowered runtimeProgram runtimeSlotProgram,
        expectedConfidentialKernelProgramForFunction fn = .ok expectedProgram ∧
        parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
        parseEntrypointConfidentialSlotProgram entry = .ok (some entrySlotProgram) ∧
        entryProgram.toConfidentialKernelSlotProgram? = .ok lowered ∧
        runtimeProgram = entryProgram.toConfidentialKernelProgram ∧
        runtimeSlotProgram = lowered.toConfidentialKernelSlotProgram ∧
        expectedProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps ∧
        entryProgram.expectedRuntimeKernelSteps = lowered.expectedRuntimeKernelSteps ∧
        importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
          expectedProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
        importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
          entryProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
        importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
          lowered.expectedRuntimeKernelSteps = entry.kernel_steps ∧
        expectedProgram.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
          runtimeProgram.expectedRuntimeKernelSteps ∧
        lowered.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
          runtimeSlotProgram.expectedRuntimeKernelSteps ∧
        runtimeProgram.expectedRuntimeKernelSteps = runtimeSlotProgram.expectedRuntimeKernelSteps
  manifestWitnessWithExpected :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      ∃ expected witness,
        countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
        witness = entry.toManifestWitnessWithExpected expected ∧
        witness.secretArgs = fn.secret_args ∧
        witness.publicGasBudget = entry.public_gas_budget ∧
        witness.oramAccesses = expected
  expectedOramObjectWitnessExists :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      ∀ {objectId accesses},
        (objectId, accesses) ∈
            (match countFunctionOramAccesses fn bundle.source_view.state with
            | .ok expected => expected
            | .error _ => []) →
          ∃ stateObject manifestObject object,
            stateObjectById? bundle.source_view.state objectId = some stateObject ∧
            manifestObjectById? bundle.source_view.manifest.objects objectId = some manifestObject ∧
            manifestObject.toOramObjectManifest? stateObject = some object ∧
            WellFormedOramObject object ∧
            ((1 < accesses) → WellFormedAnyPathOramObject object)
  expectedPathOramObjectWitnessExists :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      ∀ {objectId accesses},
        (objectId, accesses) ∈
            (match countFunctionOramAccesses fn bundle.source_view.state with
            | .ok expected => expected
            | .error _ => []) →
          1 < accesses →
          ∃ stateObject manifestObject object,
            stateObjectById? bundle.source_view.state objectId = some stateObject ∧
            manifestObjectById? bundle.source_view.manifest.objects objectId = some manifestObject ∧
            manifestObject.toOramObjectManifest? stateObject = some object ∧
            WellFormedAnyPathOramObject object
  expectedOramObjectWitnessesAligned :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      ∃ expected objects,
        countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
        bundle.source_view.buildExpectedOramObjectWitnesses expected = .ok objects ∧
        ExpectedOramObjectWitnessAlignment expected objects
  oramEntrypointWitnessAlignedExact :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      ∃ expected witness,
        countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
        bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
        witness.entrypointId = entry.signature ∧
        witness.secretArgs = fn.secret_args ∧
        witness.publicGasBudget = entry.public_gas_budget ∧
        witness.oramAccesses = expected ∧
        ExpectedOramObjectWitnessAlignment expected witness.oramObjects
  oramEntrypointWitnessExact :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      ∃ expected witness,
        countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
        bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
        witness.entrypointId = entry.signature ∧
        witness.secretArgs = fn.secret_args ∧
        witness.publicGasBudget = entry.public_gas_budget ∧
        witness.oramAccesses = expected ∧
        ∀ object, object ∈ witness.oramObjects → WellFormedOramObject object
  oramEntrypointRecomputedSlotLoweringExact :
    ∀ {fn : ImportedProofRelevantFunctionView}
      {entry : ImportedProofRelevantEntrypointView},
      fn ∈ bundle.source_view.functions →
      lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry →
      fn.confidential = true →
      ∃ expected witness entryProgram entrySlotProgram lowered,
        countFunctionOramAccesses fn bundle.source_view.state = .ok expected ∧
        bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
        parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
        parseEntrypointConfidentialSlotProgram entry = .ok (some entrySlotProgram) ∧
        entryProgram.toConfidentialKernelSlotProgram? = .ok lowered ∧
        checkImportedConfidentialKernelSlotProgramEq lowered entrySlotProgram = true ∧
        lowered.entrypoint_id = entry.signature ∧
        lowered.secret_args = fn.secret_args ∧
        witness.entrypointId = lowered.entrypoint_id ∧
        witness.secretArgs = lowered.secret_args ∧
        witness.publicGasBudget = entry.public_gas_budget ∧
        witness.oramAccesses = expected ∧
        ExpectedOramObjectWitnessAlignment expected witness.oramObjects ∧
        entryProgram.toConfidentialKernelProgram.SlotLoweringMatches
          lowered.toConfidentialKernelSlotProgram ∧
        lowered.RuntimeNormalForm ∧
        importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
          entrySlotProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
        importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
          entryProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
        entryProgram.expectedRuntimeKernelSteps = lowered.expectedRuntimeKernelSteps ∧
        importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
          lowered.expectedRuntimeKernelSteps = entry.kernel_steps ∧
        entryProgram.toConfidentialKernelProgram.expectedRuntimeKernelSteps =
          lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
        lowered.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
          lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps

theorem proofGradeCompilerFactsOfValid
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid) :
  ProofGradeCompilerFacts bundle := by
  refine
    { sourceViewStructuralValid := bundle.source_view_structural_valid hValid
    , artifactViewStructuralValid := bundle.artifact_view_structural_valid hValid
    , sourceArtifactViewsExact := importedProofRelevantTranslationBundle_views_exact bundle hValid
    , manifestFieldsExact := ?_
    , confidentialKernelLoweringExact := ?_
    , confidentialKernelTargetsNonRaw := ?_
    , sourceExpectedKernelScheduleExact := ?_
    , sourceToRuntimeSlotScheduleExact := ?_
    , manifestWitnessWithExpected := ?_
    , expectedOramObjectWitnessExists := ?_
    , expectedPathOramObjectWitnessExists := ?_
    , expectedOramObjectWitnessesAligned := ?_
    , oramEntrypointWitnessAlignedExact := ?_
    , oramEntrypointWitnessExact := ?_
    , oramEntrypointRecomputedSlotLoweringExact := ?_
    }
  · intro fn entry hMem hLookup
    exact proofGradeManifestFieldsExactOfLookup bundle hValid hMem hLookup
  · intro fn entry hMem hLookup hConf
    exact proofGradeConfidentialKernelLoweringExactOfLookup bundle hValid hMem hLookup hConf
  · intro fn entry hMem hLookup hConf kernelStep objectId hStepMem hObjectId
    exact
      bundle.source_view.confidential_kernel_step_targets_non_raw_of_lookup
        (bundle.source_view_structural_valid hValid)
        hMem
        hLookup
        hConf
        hStepMem
        hObjectId
  · intro fn entry hMem hLookup hConf
    exact proofGradeSourceExpectedKernelScheduleExactOfLookup bundle hValid hMem hLookup hConf
  · intro fn entry hMem hLookup hConf
    exact proofGradeSourceToRuntimeSlotScheduleExactOfLookup bundle hValid hMem hLookup hConf
  · intro fn entry hMem hLookup
    exact proofGradeManifestWitnessWithExpectedOfLookup bundle hValid hMem hLookup
  · intro fn entry hMem hLookup objectId accesses hExpected
    exact
      proofGradeExpectedOramObjectWitnessExistsOfLookup
        bundle hValid hMem hLookup hExpected
  · intro fn entry hMem hLookup objectId accesses hExpected hMany
    exact
      proofGradeExpectedPathOramObjectWitnessExistsOfLookup
        bundle hValid hMem hLookup hExpected hMany
  · intro fn entry hMem hLookup
    exact
      proofGradeExpectedOramObjectWitnessesAlignedOfLookup
        bundle hValid hMem hLookup
  · intro fn entry hMem hLookup
    exact
      proofGradeOramEntrypointWitnessAlignedExactOfLookup
        bundle hValid hMem hLookup
  · intro fn entry hMem hLookup
    exact proofGradeOramEntrypointWitnessExactOfLookup bundle hValid hMem hLookup
  · intro fn entry hMem hLookup hConf
    exact
      proofGradeOramEntrypointRecomputedSlotLoweringExactOfLookup
        bundle hValid hMem hLookup hConf

end UOToolchain
