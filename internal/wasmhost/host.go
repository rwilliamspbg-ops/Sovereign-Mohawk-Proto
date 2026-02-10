// internal/wasmhost/host.go
package wasmhost

import (
	"context"
	"fmt"
	"time"

	"github.com/bytecodealliance/wasmtime-go/v15"
	"sovereign/internal/manifest"
)

type HostEnv struct {
	Caps   map[manifest.Capability]bool
	LogFn  func(level, msg string)
	FLSend func(payload []byte) error
	// Add sensor/NPU hooks as needed.
}

type Runner struct {
	engine *wasmtime.Engine
}

func NewRunner() *Runner {
	cfg := wasmtime.NewConfig()
	cfg.SetWasmMultiValue(true)
	return &Runner{engine: wasmtime.NewEngineWithConfig(cfg)}
}

func (r *Runner) RunTask(ctx context.Context, wasmBytes []byte, m *manifest.Manifest, env *HostEnv) error {
	store := wasmtime.NewStore(r.engine)

	linker := wasmtime.NewLinker(r.engine)

	// log(level: i32, ptr: i32, len: i32)
	if env.Caps[manifest.CapLog] {
		err := linker.DefineFunc("env", "log",
			func(caller *wasmtime.Caller, level int32, ptr, length int32) {
				mem := caller.GetExport("memory").Memory()
				if mem == nil {
					return
				}
				data := mem.UnsafeData(store)[ptr : ptr+length]
				env.LogFn(fmtLevel(level), string(data))
			})
		if err != nil {
			return err
		}
	}

	// submit_gradients(ptr: i32, len: i32) -> i32 (0=OK)
	if env.Caps[manifest.CapSubmitGrad] {
		err := linker.DefineFunc("env", "submit_gradients",
			func(caller *wasmtime.Caller, ptr, length int32) int32 {
				mem := caller.GetExport("memory").Memory()
				if mem == nil {
					return 1
				}
				data := make([]byte, length)
				copy(data, mem.UnsafeData(store)[ptr:ptr+length])
				if err := env.FLSend(data); err != nil {
					env.LogFn("error", "submit_gradients failed: "+err.Error())
					return 1
				}
				return 0
			})
		if err != nil {
			return err
		}
	}

	module, err := wasmtime.NewModule(r.engine, wasmBytes)
	if err != nil {
		return err
	}

	instance, err := linker.Instantiate(store, module)
	if err != nil {
		return err
	}

	entry := instance.GetFunc(store, "run_task")
	if entry == nil {
		return fmt.Errorf("run_task export not found")
	}

	done := make(chan error, 1)
	go func() {
		_, err := entry.Call(store)
		done <- err
	}()

	select {
	case <-ctx.Done():
		return ctx.Err()
	case err := <-done:
		return err
	case <-time.After(time.Duration(m.MaxMillis) * time.Millisecond):
		// Circuit breaker on timeout.
		return fmt.Errorf("task timeout")
	}
}

func fmtLevel(l int32) string {
	switch l {
	case 0:
		return "debug"
	case 1:
		return "info"
	case 2:
		return "warn"
	default:
		return "error"
	}
}
