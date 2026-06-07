package audit

import "errors"

var (
	ErrVendorTimeout     = errors.New("vendor audit timeout")
	ErrRegionMismatch    = errors.New("request region does not match deploy region")
	ErrUnknownKind       = errors.New("unknown audit kind")
	ErrAuditJobNotFound  = errors.New("rejected audit job not found for task")
	ErrAppealNotAllowed  = errors.New("appeal only allowed for rejected audit jobs")
	ErrAppealDuplicate   = errors.New("appeal already exists for audit job")
	ErrInvalidKind       = errors.New("invalid audit kind")
	ErrInvalidRegion     = errors.New("invalid region")
	ErrMissingTargetRef  = errors.New("target_ref required")
	ErrMissingAppealText = errors.New("appeal reason required")
)
