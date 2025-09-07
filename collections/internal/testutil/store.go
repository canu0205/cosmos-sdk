package testutil

import (
	"context"
	"fmt"

	db "github.com/cosmos/cosmos-db"

	store "cosmossdk.io/collections/corecompat"
	corestore "cosmossdk.io/core/store"
)

var _ store.KVStoreService = (*kvStoreService)(nil)

func KVStoreService(ctx context.Context, moduleName string) store.KVStoreService {
	unwrap(ctx).stores[moduleName] = db.NewMemDB()
	return kvStoreService{
		moduleName: moduleName,
	}
}

type kvStoreService struct {
	moduleName string
}

func (k kvStoreService) OpenKVStore(ctx context.Context) store.KVStore {
	kv, ok := unwrap(ctx).stores[k.moduleName]
	if !ok {
		panic(fmt.Sprintf("KVStoreService %s not found", k.moduleName))
	}
	return kv
}

func TransientStoreService(ctx context.Context, moduleName string) corestore.TransientStoreService {
	unwrap(ctx).stores[moduleName] = db.NewMemDB()
	return transientStoreService{
		moduleName: moduleName,
	}
}

type transientStoreService struct {
	moduleName string
}

func (t transientStoreService) OpenTransientStore(ctx context.Context) store.KVStore {
	kv, ok := unwrap(ctx).stores[t.moduleName]
	if !ok {
		panic(fmt.Sprintf("TransientStoreService %s not found", t.moduleName))
	}
	return kv
}
