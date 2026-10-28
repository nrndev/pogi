//go:build race

package main

// The test job compiled every package with -race, so building pogi with -race here only links.
func goBuildArgs() []string { return []string{"build", "-race"} }
