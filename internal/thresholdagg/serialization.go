package thresholdagg

import "encoding/json"

func MarshalUpdate(update Update) ([]byte, error) {
	return json.Marshal(update)
}

func UnmarshalUpdate(raw []byte) (Update, error) {
	var out Update
	err := json.Unmarshal(raw, &out)
	return out, err
}
