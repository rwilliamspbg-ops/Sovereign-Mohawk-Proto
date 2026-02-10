cd wasm-modules/fl_task
rustup target add wasm32-unknown-unknown
cargo build --release --target wasm32-unknown-unknown
