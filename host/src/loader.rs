use wasmtime::{Engine, Module, Config};
use std::fs;

pub fn load_mohawk_core(engine: &Engine, path: &str) -> anyhow::Result<Module> {
    // Read the pre-compiled .cwasm file from disk
    let cwasm_bytes = fs::read(path)?;

    // DESERIALIZE is significantly faster than compiling at runtime
    // Safety: Ensure the .cwasm was built with the same Wasmtime version
    let module = unsafe { Module::deserialize(engine, cwasm_bytes)? };
    
    Ok(module)
}
