package familyauth

import "errors"

// ErrForbidden is returned when the caller is not a family member.
var ErrForbidden = errors.New("not a member of this family")
