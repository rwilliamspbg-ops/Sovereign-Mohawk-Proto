package fhe

import "encoding/json"

func MarshalUpdate(update EncryptedUpdate) ([]byte, error) {
	return json.Marshal(update)
}

func UnmarshalUpdate(raw []byte) (EncryptedUpdate, error) {
	var out EncryptedUpdate
	err := json.Unmarshal(raw, &out)
	return out, err
}
