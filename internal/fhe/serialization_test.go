package fhe

import (
	"strings"
	"testing"
)

func TestMarshalUnmarshalUpdate_RoundTrip(t *testing.T) {
	tests := []struct {
		name   string
		update EncryptedUpdate
	}{
		{"typical values", EncryptedUpdate{Contributor: "node-x", Values: []int64{9, 8, 7}}},
		{"negative values", EncryptedUpdate{Contributor: "node-y", Values: []int64{-1, -2, -3}}},
		{"empty contributor", EncryptedUpdate{Contributor: "", Values: []int64{1}}},
		{"single value", EncryptedUpdate{Contributor: "solo", Values: []int64{42}}},
		{"large values", EncryptedUpdate{Contributor: "big", Values: []int64{9223372036854775807, -9223372036854775808}}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			raw, err := MarshalUpdate(tt.update)
			if err != nil {
				t.Fatalf("marshal failed: %v", err)
			}
			decoded, err := UnmarshalUpdate(raw)
			if err != nil {
				t.Fatalf("unmarshal failed: %v", err)
			}
			if decoded.Contributor != tt.update.Contributor {
				t.Fatalf("contributor mismatch: got %q, want %q", decoded.Contributor, tt.update.Contributor)
			}
			if len(decoded.Values) != len(tt.update.Values) {
				t.Fatalf("values length mismatch: got %d, want %d", len(decoded.Values), len(tt.update.Values))
			}
			for i := range tt.update.Values {
				if decoded.Values[i] != tt.update.Values[i] {
					t.Fatalf("value %d mismatch: got %d, want %d", i, decoded.Values[i], tt.update.Values[i])
				}
			}
		})
	}
}

func TestMarshalUpdate_UsesExpectedJSONFieldNames(t *testing.T) {
	raw, err := MarshalUpdate(EncryptedUpdate{Contributor: "node-x", Values: []int64{1, 2}})
	if err != nil {
		t.Fatalf("marshal failed: %v", err)
	}
	s := string(raw)
	if !strings.Contains(s, `"contributor":"node-x"`) {
		t.Fatalf("expected contributor field in JSON, got: %s", s)
	}
	if !strings.Contains(s, `"values":[1,2]`) {
		t.Fatalf("expected values field in JSON, got: %s", s)
	}
}

func TestUnmarshalUpdate_MalformedJSONErrors(t *testing.T) {
	if _, err := UnmarshalUpdate([]byte("{not valid json")); err == nil {
		t.Fatal("expected malformed JSON to fail")
	}
}

func TestUnmarshalUpdate_EmptyBytesErrors(t *testing.T) {
	if _, err := UnmarshalUpdate([]byte("")); err == nil {
		t.Fatal("expected empty input to fail")
	}
}

func TestUnmarshalUpdate_WrongShapeJSONErrors(t *testing.T) {
	if _, err := UnmarshalUpdate([]byte(`{"contributor": 123, "values": "not-an-array"}`)); err == nil {
		t.Fatal("expected type-mismatched JSON to fail")
	}
}

func TestUnmarshalUpdate_UnknownFieldsIgnored(t *testing.T) {
	decoded, err := UnmarshalUpdate([]byte(`{"contributor":"node-x","values":[1,2,3],"extra":"ignored"}`))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if decoded.Contributor != "node-x" || len(decoded.Values) != 3 {
		t.Fatalf("unexpected decode result: %+v", decoded)
	}
}

func TestUnmarshalUpdate_NullValuesProducesEmptySlice(t *testing.T) {
	decoded, err := UnmarshalUpdate([]byte(`{"contributor":"node-x","values":null}`))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(decoded.Values) != 0 {
		t.Fatalf("expected empty values, got %v", decoded.Values)
	}
}
