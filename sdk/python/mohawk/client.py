"""Main client interface for the MOHAWK Python SDK."""

import ctypes
import json
import os
from pathlib import Path
from typing import Dict, Any, Optional

from .exceptions import MohawkError, VerificationError, InitializationError


class MohawkNode:
    """Python interface to the MOHAWK federated learning runtime.
    
    This class provides a Pythonic wrapper around the Go-based MOHAWK runtime,
    enabling Python developers to leverage the high-performance federated learning
    capabilities with zk-SNARK verification.
    
    Example:
        >>> node = MohawkNode()
        >>> result = node.start(config_path="capabilities.json", node_id="node-001")
        >>> print(result)
        {'success': True, 'message': 'Node started successfully'}
    """
    
    def __init__(self, lib_path: Optional[str] = None):
        """Initialize the MOHAWK node client.
        
        Args:
            lib_path: Path to the libmohawk shared library. If None, searches
                     in standard locations.
        
        Raises:
            InitializationError: If the library cannot be loaded.
        """
        if lib_path is None:
            lib_path = self._find_library()
        
        try:
            self.lib = ctypes.CDLL(os.path.abspath(lib_path))
        except OSError as e:
            raise InitializationError(f"Failed to load MOHAWK library: {e}")
        
        self._setup_functions()
    
    def _find_library(self) -> str:
        """Locate the MOHAWK shared library."""
        possible_paths = [
            "./libmohawk.so",
            "./libmohawk.dylib",
            "../../../libmohawk.so",
            "../../../libmohawk.dylib",
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                return path
        
        raise InitializationError(
            "MOHAWK library not found. Please build it with 'make build-python-lib'"
        )
    
    def _setup_functions(self):
        """Configure ctypes function signatures."""
        # InitializeNode
        self.lib.InitializeNode.restype = ctypes.c_char_p
        self.lib.InitializeNode.argtypes = [ctypes.c_char_p]
        
        # VerifyZKProof
        self.lib.VerifyZKProof.restype = ctypes.c_char_p
        self.lib.VerifyZKProof.argtypes = [ctypes.c_char_p]
        
        # AggregateUpdates
        self.lib.AggregateUpdates.restype = ctypes.c_char_p
        self.lib.AggregateUpdates.argtypes = [ctypes.c_char_p]
        
        # GetNodeStatus
        self.lib.GetNodeStatus.restype = ctypes.c_char_p
        self.lib.GetNodeStatus.argtypes = [ctypes.c_char_p]
        
        # LoadWasmModule
        self.lib.LoadWasmModule.restype = ctypes.c_char_p
        self.lib.LoadWasmModule.argtypes = [ctypes.c_char_p]
        
        # AttestNode
        self.lib.AttestNode.restype = ctypes.c_char_p
        self.lib.AttestNode.argtypes = [ctypes.c_char_p]
        
        # FreeString
        self.lib.FreeString.argtypes = [ctypes.c_char_p]
    
    def _call_and_parse(self, func, arg: str) -> Dict[str, Any]:
        """Call a C function and parse JSON response."""
        arg_bytes = arg.encode('utf-8')
        result_ptr = func(arg_bytes)
        result_str = ctypes.c_char_p(result_ptr).value.decode('utf-8')
        
        # Free the C string
        self.lib.FreeString(result_ptr)
        
        try:
            result = json.loads(result_str)
        except json.JSONDecodeError as e:
            raise MohawkError(f"Failed to parse response: {e}")
        
        if not result.get('success', False):
            raise MohawkError(result.get('message', 'Unknown error'))
        
        return result
    
    def start(self, config_path: str, node_id: str = "default", 
              capabilities: Optional[str] = None) -> Dict[str, Any]:
        """Initialize and start a MOHAWK node.
        
        Args:
            config_path: Path to the node configuration file (e.g., capabilities.json)
            node_id: Unique identifier for this node
            capabilities: Optional JSON string of node capabilities
        
        Returns:
            Dictionary containing success status and initialization details
        
        Raises:
            InitializationError: If node initialization fails
        """
        config = {
            "node_id": node_id,
            "config_path": config_path,
            "capabilities": capabilities or ""
        }
        
        try:
            return self._call_and_parse(self.lib.InitializeNode, json.dumps(config))
        except MohawkError as e:
            raise InitializationError(str(e))
    
    def verify_proof(self, proof: Dict[str, Any]) -> Dict[str, Any]:
        """Verify a zk-SNARK proof.
        
        Args:
            proof: Dictionary containing the proof data to verify
        
        Returns:
            Verification result with timing information
        
        Raises:
            VerificationError: If proof verification fails
        """
        try:
            return self._call_and_parse(self.lib.VerifyZKProof, json.dumps(proof))
        except MohawkError as e:
            raise VerificationError(str(e))
    
    def aggregate(self, updates: list) -> Dict[str, Any]:
        """Aggregate federated learning updates.
        
        Args:
            updates: List of model updates from participating nodes
        
        Returns:
            Aggregation result
        
        Raises:
            MohawkError: If aggregation fails
        """
        updates_json = json.dumps({"updates": updates})
        return self._call_and_parse(self.lib.AggregateUpdates, updates_json)
    
    def status(self, node_id: str) -> Dict[str, Any]:
        """Get the current status of a node.
        
        Args:
            node_id: ID of the node to query
        
        Returns:
            Node status information
        """
        result = self._call_and_parse(self.lib.GetNodeStatus, node_id)
        if result.get('data'):
            result['status_data'] = json.loads(result['data'])
        return result
    
    def load_wasm(self, module_path: str) -> Dict[str, Any]:
        """Load a WebAssembly module.
        
        Args:
            module_path: Path to the .wasm module file
        
        Returns:
            Load result
        
        Raises:
            MohawkError: If module loading fails
        """
        return self._call_and_parse(self.lib.LoadWasmModule, module_path)
    
    def attest(self, node_id: str) -> Dict[str, Any]:
        """Perform TPM attestation for a node.
        
        Args:
            node_id: ID of the node to attest
        
        Returns:
            Attestation data
        
        Raises:
            MohawkError: If attestation fails
        """
        return self._call_and_parse(self.lib.AttestNode, node_id)


if __name__ == "__main__":
    # Example usage
    try:
        node = MohawkNode()
        result = node.start("capabilities.json", node_id="demo-node")
        print(f"✅ {result['message']}")
        
        status = node.status("demo-node")
        print(f"📊 Node status: {status}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
