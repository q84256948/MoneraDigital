// internal/performance/benchmark.go
package performance

import (
	"fmt"
	"time"
)

// BenchmarkResult represents the result of a benchmark
type BenchmarkResult struct {
	Name            string
	Iterations      int
	TotalDuration   time.Duration
	AvgDuration     time.Duration
	MinDuration     time.Duration
	MaxDuration     time.Duration
	OpsPerSecond    float64
	MemoryAllocated uint64
}

// Benchmark runs a function multiple times and measures performance
type Benchmark struct {
	name       string
	iterations int
	fn         func() error
	results    []time.Duration
}

// NewBenchmark creates a new benchmark
func NewBenchmark(name string, iterations int, fn func() error) *Benchmark {
	return &Benchmark{
		name:       name,
		iterations: iterations,
		fn:         fn,
		results:    make([]time.Duration, 0, iterations),
	}
}

// Run executes the benchmark
func (b *Benchmark) Run() (*BenchmarkResult, error) {
	for i := 0; i < b.iterations; i++ {
		start := time.Now()
		if err := b.fn(); err != nil {
			return nil, fmt.Errorf("benchmark iteration %d failed: %w", i, err)
		}
		duration := time.Since(start)
		b.results = append(b.results, duration)
	}

	return b.calculateResults(), nil
}

// calculateResults calculates benchmark statistics
func (b *Benchmark) calculateResults() *BenchmarkResult {
	if len(b.results) == 0 {
		return &BenchmarkResult{Name: b.name}
	}

	var totalDuration time.Duration
	minDuration := b.results[0]
	maxDuration := b.results[0]

	for _, duration := range b.results {
		totalDuration += duration
		if duration < minDuration {
			minDuration = duration
		}
		if duration > maxDuration {
			maxDuration = duration
		}
	}

	avgDuration := totalDuration / time.Duration(len(b.results))
	opsPerSecond := float64(len(b.results)) / totalDuration.Seconds()

	return &BenchmarkResult{
		Name:          b.name,
		Iterations:    len(b.results),
		TotalDuration: totalDuration,
		AvgDuration:   avgDuration,
		MinDuration:   minDuration,
		MaxDuration:   maxDuration,
		OpsPerSecond:  opsPerSecond,
	}
}

// String returns a formatted string representation of the result
func (r *BenchmarkResult) String() string {
	return fmt.Sprintf(
		"Benchmark: %s\n"+
			"  Iterations: %d\n"+
			"  Total Duration: %v\n"+
			"  Avg Duration: %v\n"+
			"  Min Duration: %v\n"+
			"  Max Duration: %v\n"+
			"  Ops/sec: %.2f\n",
		r.Name,
		r.Iterations,
		r.TotalDuration,
		r.AvgDuration,
		r.MinDuration,
		r.MaxDuration,
		r.OpsPerSecond,
	)
}

// BenchmarkSuite runs multiple benchmarks
type BenchmarkSuite struct {
	name       string
	benchmarks []*Benchmark
	results    []*BenchmarkResult
}

// NewBenchmarkSuite creates a new benchmark suite
func NewBenchmarkSuite(name string) *BenchmarkSuite {
	return &BenchmarkSuite{
		name:       name,
		benchmarks: make([]*Benchmark, 0),
		results:    make([]*BenchmarkResult, 0),
	}
}

// Add adds a benchmark to the suite
func (bs *BenchmarkSuite) Add(benchmark *Benchmark) {
	bs.benchmarks = append(bs.benchmarks, benchmark)
}

// Run executes all benchmarks in the suite
func (bs *BenchmarkSuite) Run() error {
	fmt.Printf("Running Benchmark Suite: %s\n", bs.name)
	fmt.Println(string(make([]byte, 50)))

	for _, benchmark := range bs.benchmarks {
		result, err := benchmark.Run()
		if err != nil {
			return err
		}
		bs.results = append(bs.results, result)
		fmt.Println(result.String())
	}

	return nil
}

// Summary returns a summary of all benchmark results
func (bs *BenchmarkSuite) Summary() string {
	summary := fmt.Sprintf("Benchmark Suite Summary: %s\n", bs.name)
	summary += fmt.Sprintf("Total Benchmarks: %d\n", len(bs.results))

	var totalOpsPerSecond float64
	for _, result := range bs.results {
		totalOpsPerSecond += result.OpsPerSecond
	}

	summary += fmt.Sprintf("Total Ops/sec: %.2f\n", totalOpsPerSecond)
	return summary
}
