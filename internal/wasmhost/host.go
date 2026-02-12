package wasmhost

import (
	"context"

	"github.com/bytecodealliance/wasmtime-go/v15"
	"github.com/your-org/sovereign-mohawk-proto/internal/manifest"
)

type HostEnv struct {
	Caps   map[manifest.Capability]bool
	LogFn  func(level, msg string)
	FLSend func(payload []byte) error
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

	// LOG capability
	if env.Caps[manifest.CapLog] {
		err := linker.DefineFunc(store, "env", "log", func(caller *wasmtime.Caller, level int32, ptr, length int32) {
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

	// SUBMIT_GRADIENTS capability
	if env.Caps[manifest.CapSubmitGrad] {
		err := linker.DefineFunc(store, "env", "submit_gradients", func(caller *wasmtime.Caller, ptr, length int32) int32 {
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

	return nil
}

func fmtLevel(level int32) string {
	switch level {
	case 0:
		return "info"
	case 1:
		return "warn"
	case 2:
		return "error"
	default:
		return "debug"
	}
}
