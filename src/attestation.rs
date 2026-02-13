use tpm2_tss::{Context, TctiNameConf, types::PcrSelection};
use std::convert::TryInto;

pub struct AttestationReport {
    pub quote: Vec<u8>,
    pub signature: Vec<u8>,
}

pub fn generate_quote(nonce: [u8; 32]) -> AttestationReport {
    // 1. Connect to the local hardware TPM
    let mut ctx = Context::new(TctiNameConf::Device).expect("TPM missing");
    
    // 2. Select PCR 10 (Standard for Wasm measurements in 2026)
    let pcr_selection = PcrSelection::new_sha256(&[10]);
    
    // 3. Generate Hardware Quote
    // This signs the hash of the Wasm module currently in memory
    let (quote, signature) = ctx.quote(
        &pcr_selection, 
        &nonce.into()
    ).expect("Failed to sign hardware state");

    AttestationReport {
        quote: quote.to_vec(),
        signature: signature.to_vec(),
    }
}
