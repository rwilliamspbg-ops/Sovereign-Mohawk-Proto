use ed25519_dalek::{Signature, VerifyingKey, Verifier};

#[link(wasm_import_module = "env")]
extern "C" {
    fn log(level: i32, ptr: *const u8, len: i32);
    fn submit_gradients(ptr: *const u8, len: i32) -> i32;
}

fn host_log(level: i32, msg: &str) {
    unsafe { log(level, msg.as_ptr(), msg.len() as i32) }
}

static mut HEAP_PTR: usize = 65536;

#[no_mangle]
pub extern "C" fn alloc(size: i32) -> i32 {
    if size <= 0 {
        return 0;
    }
    unsafe {
        let ptr = HEAP_PTR;
        HEAP_PTR += size as usize;
        HEAP_PTR = (HEAP_PTR + 7) & !7;
        ptr as i32
    }
}

#[no_mangle]
pub extern "C" fn verify_proof(ptr: i32, len: i32) -> i32 {
    if len < 96 || ptr <= 0 {
        return 0;
    }
    let slice = unsafe { core::slice::from_raw_parts(ptr as *const u8, len as usize) };

    let mut sig_bytes = [0u8; 64];
    sig_bytes.copy_from_slice(&slice[0..64]);
    let mut pk_bytes = [0u8; 32];
    pk_bytes.copy_from_slice(&slice[64..96]);
    let message = &slice[96..];

    let signature = Signature::from_bytes(&sig_bytes);
    let verifying_key = match VerifyingKey::from_bytes(&pk_bytes) {
        Ok(k) => k,
        Err(_) => return 0,
    };

    if verifying_key.verify(message, &signature).is_ok() {
        host_log(1, "verify_proof succeeded");
        1
    } else {
        host_log(3, "verify_proof failed");
        0
    }
}

#[no_mangle]
pub extern "C" fn run_task() {
    host_log(1, "FL Wasm task started");
    let grads: [f32; 3] = [0.1, 0.2, 0.3];
    let bytes: &[u8] = unsafe {
        core::slice::from_raw_parts(
            grads.as_ptr() as *const u8,
            core::mem::size_of::<[f32; 3]>(),
        )
    };
    unsafe {
        let rc = submit_gradients(bytes.as_ptr(), bytes.len() as i32);
        if rc != 0 {
            host_log(3, "submit_gradients failed");
        } else {
            host_log(1, "submit_gradients ok");
        }
    }
}


/// Clamp an integer gradient component to [-bound, bound].
pub fn clamp_i32(x: i32, bound: i32) -> i32 {
    if bound <= 0 {
        0
    } else if x > bound {
        bound
    } else if x < -bound {
        -bound
    } else {
        x
    }
}

#[cfg(kani)]
#[kani::proof]
fn verify_clamp_i32() {
    let x: i32 = kani::any();
    let bound: i32 = kani::any();
    kani::assume(bound >= 0);
    kani::assume(bound <= i32::MAX / 2);
    let y = clamp_i32(x, bound);
    assert!(y >= -bound);
    assert!(y <= bound);
}


/// Sum four i32 values in i64 to avoid overflow; returns the exact sum.
pub fn sum4_i64(xs: [i32; 4]) -> i64 {
    xs[0] as i64 + xs[1] as i64 + xs[2] as i64 + xs[3] as i64
}

#[cfg(kani)]
#[kani::proof]
fn verify_sum4_i64_bounded() {
    let xs: [i32; 4] = kani::any();
    let bound: i32 = kani::any();
    kani::assume(bound >= 0);
    kani::assume(bound <= 1_000);
    for i in 0..4 {
        kani::assume(xs[i] >= -bound && xs[i] <= bound);
    }
    let s = sum4_i64(xs);
    // |sum| <= 4 * bound
    assert!(s >= -(4 * bound as i64));
    assert!(s <= 4 * bound as i64);
}

/// Stale weight in basis points (0..=10000), decreasing with age.
pub fn stale_weight_bps(age: u32, max_age: u32) -> u32 {
    if max_age == 0 || age >= max_age {
        0
    } else {
        let a = age as u64;
        let m = max_age as u64;
        (10000u64 - (a * 10000u64 / m)) as u32
    }
}

#[cfg(kani)]
#[kani::proof]
fn verify_stale_weight_bps_bounds() {
    let age: u32 = kani::any();
    let max_age: u32 = kani::any();
    kani::assume(max_age <= 1_000);
    let w = stale_weight_bps(age, max_age);
    assert!(w <= 10000);
}
