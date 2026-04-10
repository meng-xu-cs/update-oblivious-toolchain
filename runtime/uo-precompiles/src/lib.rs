use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum UoOpcode {
    Begin,
    CellGet,
    CellSet,
    ArrayGet,
    ArraySet,
    MapGet,
    MapPut,
    Commit,
    Wipe,
}
