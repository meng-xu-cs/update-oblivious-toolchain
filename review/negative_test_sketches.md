# Negative Test Sketches

These are intentionally small tests designed to fail closed after remediation.

## 1. Public entrypoint secret branch changes gas/storage trace

```solidity
contract SecretBranchLeak {
    uint256 secret;
    uint256 publicDummy;

    function leakSchedule() public {
        if (secret != 0) {
            uint256 x = publicDummy;
        }
    }
}
```

Expected: reject unless `leakSchedule` is `confidential: true` and the confidential kernel path proves fixed observer shape. The reason is that the branch can change modeled gas/object schedule even without return/status/public write.

## 2. Public entrypoint secret branch writes public state

```solidity
contract SecretPublicWrite {
    uint256 secret;
    uint256 publicOut;

    function writeBit() public {
        if (secret != 0) {
            publicOut = 1;
        } else {
            publicOut = 0;
        }
    }
}
```

Expected: reject unless `public_state_declassifies` names `publicOut`; after policy tightening, require a release function/delta, not just whole-object label.

## 3. Write then abort rollback

```solidity
contract AbortRollback {
    uint256 publicOut;

    function f() public {
        publicOut = 7;
        require(false);
    }
}
```

Expected: source/IR/runtime theorem must agree on final public state. If rollback semantics are intended, final public state equals initial public state.

## 4. Unknown sidecar field

```yaml
entrypoints:
  f:
    confidential: false
    returns: forbidden
    status: public
    declassify_public_state: [x]   # misspelled or obsolete field
```

Expected: reject due unknown field; package hash must differ from a sidecar without that field if raw metadata hashing is retained.

## 5. Duplicate or extraneous policy labels

```yaml
entrypoints:
  f:
    confidential: true
    secret_args: [a, a]
    returns: encrypted_to_client
    status: public
    declassifies: [success, success]
```

Expected: reject duplicate secret args and duplicate/extraneous declassification labels.

## 6. Irrelevant ORAM scheme on non-ORAM backend

```yaml
state:
  x:
    kind: cell
    value: uint256
    backend: full_scan
    oram_scheme: path_oram_local_posmap_v1
    confidential: true
```

Expected: reject because `oram_scheme` is meaningful only for ORAM maps.
