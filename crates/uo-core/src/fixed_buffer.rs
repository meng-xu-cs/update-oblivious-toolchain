use std::{mem::MaybeUninit, slice};

/// Returns the initialized prefix of a fixed `MaybeUninit<T>` buffer.
///
/// Invariant: callers must have initialized exactly the first `len` entries
/// and must not mutate or drop those entries while the returned slice is live.
pub(crate) fn initialized_prefix<T>(entries: &[MaybeUninit<T>], len: usize) -> &[T] {
    assert!(len <= entries.len(), "initialized prefix exceeds capacity");
    let ptr = entries.as_ptr() as *const T;
    // SAFETY: the public API of the fixed builders/journals maintains a prefix
    // initialization invariant: all slots below `len` have been written and no
    // slots at or above `len` are observed.
    unsafe { slice::from_raw_parts(ptr, len) }
}

/// Moves the initialized prefix of `entries` into a freshly sized boxed slice.
///
/// Invariant: callers must have initialized exactly the first `len` entries.
/// After this returns, callers must set their own initialized length to zero so
/// their drop path does not also drop the moved values.
pub(crate) fn move_initialized_prefix_to_box<T>(
    entries: &mut [MaybeUninit<T>],
    len: usize,
) -> Box<[T]> {
    assert!(len <= entries.len(), "initialized prefix exceeds capacity");
    let mut out = Box::<[T]>::new_uninit_slice(len);
    for (slot, entry) in out.iter_mut().zip(entries.iter_mut().take(len)) {
        // SAFETY: the caller's prefix invariant says `entry` is initialized, and
        // this function moves each initialized value exactly once into `out`.
        slot.write(unsafe { entry.assume_init_read() });
    }
    assume_init_boxed_slice(out)
}

/// Clones the initialized prefix of `entries` into a freshly sized boxed slice.
///
/// Invariant: callers must have initialized exactly the first `len` entries.
pub(crate) fn clone_initialized_prefix_to_box<T: Clone>(
    entries: &[MaybeUninit<T>],
    len: usize,
) -> Box<[T]> {
    initialized_prefix(entries, len).to_vec().into_boxed_slice()
}

/// Treats a fully initialized boxed `MaybeUninit<T>` slice as `Box<[T]>`.
///
/// Invariant: every element of `entries` must be initialized.
pub(crate) fn assume_init_boxed_slice<T>(entries: Box<[MaybeUninit<T>]>) -> Box<[T]> {
    let raw = Box::into_raw(entries) as *mut [T];
    // SAFETY: callers only invoke this helper after filling every output slot.
    unsafe { Box::from_raw(raw) }
}

/// Drops the initialized prefix of a fixed `MaybeUninit<T>` buffer.
///
/// Invariant: callers must have initialized exactly the first `len` entries and
/// must set their initialized length to zero if they call this manually before
/// the owner is dropped.
pub(crate) fn drop_initialized_prefix<T>(entries: &mut [MaybeUninit<T>], len: usize) {
    assert!(len <= entries.len(), "initialized prefix exceeds capacity");
    for entry in entries.iter_mut().take(len) {
        // SAFETY: the caller's prefix invariant says `entry` is initialized.
        unsafe { entry.assume_init_drop() };
    }
}

/// Safe owner for a public-capacity buffer with an initialized prefix.
pub struct FixedPrefixBuffer<T> {
    entries: Box<[MaybeUninit<T>]>,
    len: usize,
}

impl<T> FixedPrefixBuffer<T> {
    pub fn with_capacity(capacity: usize) -> Self {
        Self {
            entries: Box::<[T]>::new_uninit_slice(capacity),
            len: 0,
        }
    }

    pub fn len(&self) -> usize {
        self.len
    }

    pub fn capacity(&self) -> usize {
        self.entries.len()
    }

    pub fn as_slice(&self) -> &[T] {
        initialized_prefix(&self.entries, self.len)
    }

    pub fn push(&mut self, value: T) -> Result<(), T> {
        let Some(slot) = self.entries.get_mut(self.len) else {
            return Err(value);
        };
        slot.write(value);
        self.len += 1;
        Ok(())
    }

    pub fn into_boxed_slice(mut self) -> Box<[T]> {
        let out = move_initialized_prefix_to_box(&mut self.entries, self.len);
        self.len = 0;
        out
    }
}

impl<T> Drop for FixedPrefixBuffer<T> {
    fn drop(&mut self) {
        drop_initialized_prefix(&mut self.entries, self.len);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;
    use std::rc::Rc;

    #[derive(Clone)]
    struct DropToken {
        drops: Rc<Cell<usize>>,
    }

    impl Drop for DropToken {
        fn drop(&mut self) {
            self.drops.set(self.drops.get() + 1);
        }
    }

    #[test]
    fn move_initialized_prefix_moves_each_value_once() {
        let drops = Rc::new(Cell::new(0));
        let mut entries = Box::<[DropToken]>::new_uninit_slice(2);
        entries[0].write(DropToken {
            drops: Rc::clone(&drops),
        });
        entries[1].write(DropToken {
            drops: Rc::clone(&drops),
        });

        let moved = move_initialized_prefix_to_box(&mut entries, 2);
        assert_eq!(moved.len(), 2);
        assert_eq!(drops.get(), 0);
        drop(moved);
        assert_eq!(drops.get(), 2);
    }

    #[test]
    fn drop_initialized_prefix_drops_only_written_values() {
        let drops = Rc::new(Cell::new(0));
        let mut entries = Box::<[DropToken]>::new_uninit_slice(3);
        entries[0].write(DropToken {
            drops: Rc::clone(&drops),
        });
        entries[1].write(DropToken {
            drops: Rc::clone(&drops),
        });

        drop_initialized_prefix(&mut entries, 2);
        assert_eq!(drops.get(), 2);
    }

    #[test]
    fn fixed_prefix_buffer_rejects_overflow_and_moves_prefix() {
        let drops = Rc::new(Cell::new(0));
        let mut buffer = FixedPrefixBuffer::with_capacity(1);
        assert_eq!(buffer.capacity(), 1);
        assert_eq!(buffer.len(), 0);
        buffer
            .push(DropToken {
                drops: Rc::clone(&drops),
            })
            .ok()
            .expect("initial push should fit");
        assert_eq!(buffer.len(), 1);
        assert!(buffer
            .push(DropToken {
                drops: Rc::clone(&drops),
            })
            .is_err());
        assert_eq!(drops.get(), 1);

        let moved = buffer.into_boxed_slice();
        assert_eq!(moved.len(), 1);
        assert_eq!(drops.get(), 1);
        drop(moved);
        assert_eq!(drops.get(), 2);
    }
}
