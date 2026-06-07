package rest

import (
	"io"
	"net/http"
	"strings"

	"github.com/baobao/credit-sub-ad-svc/internal/appattest"
)

func readIAPVerifyBody(r *http.Request) ([]byte, error) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if len(strings.TrimSpace(string(body))) == 0 {
		return nil, errEmptyBody
	}
	return body, nil
}

func verifyAppAttest(
	w http.ResponseWriter,
	r *http.Request,
	verifier appattest.Verifier,
	transactionID, productID string,
	body []byte,
) bool {
	if verifier == nil {
		return true
	}
	payload, err := appattest.ParsePayload(body)
	if err != nil {
		writeError(w, http.StatusBadRequest, "COMMON_BAD_PARAM", "invalid json", r)
		return false
	}
	if err := verifier.Verify(appattest.VerifyInput{
		TransactionID: transactionID,
		ProductID:     productID,
		Payload:       payload,
	}); err != nil {
		writeAppAttestError(w, r, err)
		return false
	}
	return true
}

func writeAppAttestError(w http.ResponseWriter, r *http.Request, err error) {
	switch err {
	case appattest.ErrMissingPayload, appattest.ErrInvalidPayload, appattest.ErrClientDataHashMismatch:
		writeError(w, http.StatusUnprocessableEntity, "APP_ATTEST_FAILED", "app attest verification failed", r)
	default:
		writeError(w, http.StatusUnprocessableEntity, "APP_ATTEST_FAILED", "app attest verification failed", r)
	}
}
