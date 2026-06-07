package worker

import "time"

// retryBackoffSteps are exponential backoff delays after model failures (design-backend §5.5).
var retryBackoffSteps = []time.Duration{
	2 * time.Second,
	5 * time.Second,
}

// RetryBackoff returns the sleep duration before the next model retry attempt.
func RetryBackoff(retryCount int) time.Duration {
	if retryCount < 0 {
		return retryBackoffSteps[0]
	}
	if retryCount >= len(retryBackoffSteps) {
		return retryBackoffSteps[len(retryBackoffSteps)-1]
	}
	return retryBackoffSteps[retryCount]
}
