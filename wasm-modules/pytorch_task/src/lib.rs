#[link(wasm_import_module = "env")]
extern "C" {
    fn log(level: i32, ptr: *const u8, len: i32);
    fn submit_gradients(ptr: *const u8, len: i32) -> i32;
}

fn host_log(level: i32, msg: &str) {
    unsafe { log(level, msg.as_ptr(), msg.len() as i32) }
}

#[no_mangle]
pub extern "C" fn run_task() {
    host_log(1, "PyTorch federated training step started");
    let grads: [f32; 4] = [0.11, 0.07, 0.19, 0.03];
    let bytes: &[u8] = unsafe {
        core::slice::from_raw_parts(grads.as_ptr() as *const u8, core::mem::size_of::<[f32; 4]>())
    };
    unsafe {
        let rc = submit_gradients(bytes.as_ptr(), bytes.len() as i32);
        if rc != 0 {
            host_log(3, "pytorch submit_gradients failed");
        }
    }
}