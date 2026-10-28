//go:build !race

package main

// Without -race a plain build is what the test binary matches.
func goBuildArgs() []string { return []string{"build"} }
