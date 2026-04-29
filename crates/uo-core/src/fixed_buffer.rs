/// Safe owner for a public-capacity buffer with an initialized prefix.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FixedPrefixBuffer<T> {
    entries: Vec<T>,
    capacity: usize,
}

impl<T> FixedPrefixBuffer<T> {
    pub fn with_capacity(capacity: usize) -> Self {
        Self {
            entries: Vec::with_capacity(capacity),
            capacity,
        }
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    pub fn capacity(&self) -> usize {
        self.capacity
    }

    pub fn as_slice(&self) -> &[T] {
        &self.entries
    }

    pub fn push(&mut self, value: T) -> Result<(), T> {
        if self.entries.len() == self.capacity {
            return Err(value);
        }
        self.entries.push(value);
        Ok(())
    }

    pub fn into_boxed_slice(self) -> Box<[T]> {
        self.entries.into_boxed_slice()
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
