package appattest

import "encoding/json"

type appAttestRequestFields struct {
	KeyID          string `json:"keyId"`
	Assertion      string `json:"assertion"`
	ClientDataHash string `json:"clientDataHash"`
}

// ParsePayload extracts optional appAttest fields from an IAP verify JSON body.
func ParsePayload(raw json.RawMessage) (*Payload, error) {
	if len(raw) == 0 {
		return nil, nil
	}
	var body struct {
		AppAttest *appAttestRequestFields `json:"appAttest"`
	}
	if err := json.Unmarshal(raw, &body); err != nil {
		return nil, err
	}
	if body.AppAttest == nil {
		return nil, nil
	}
	return &Payload{
		KeyID:          body.AppAttest.KeyID,
		Assertion:      body.AppAttest.Assertion,
		ClientDataHash: body.AppAttest.ClientDataHash,
	}, nil
}
