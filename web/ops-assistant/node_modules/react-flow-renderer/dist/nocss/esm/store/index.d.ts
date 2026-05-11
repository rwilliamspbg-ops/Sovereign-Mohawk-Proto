/// <reference types="react" />
import { ReactFlowState } from '../types';
declare const Provider: ({ initialStore, createStore, children, }: {
    initialStore?: import("zustand").UseBoundStore<ReactFlowState, import("zustand").StoreApi<ReactFlowState>> | undefined;
    createStore: () => import("zustand").UseBoundStore<ReactFlowState, import("zustand").StoreApi<ReactFlowState>>;
    children: import("react").ReactNode;
}) => import("react").FunctionComponentElement<import("react").ProviderProps<import("zustand").UseBoundStore<ReactFlowState, import("zustand").StoreApi<ReactFlowState>> | undefined>>, useStore: import("zustand/context").UseContextStore<ReactFlowState>, useStoreApi: () => {
    getState: import("zustand").GetState<ReactFlowState>;
    setState: import("zustand").SetState<ReactFlowState>;
    subscribe: import("zustand").Subscribe<ReactFlowState>;
    destroy: import("zustand").Destroy;
};
declare const createStore: () => import("zustand").UseBoundStore<ReactFlowState, import("zustand").StoreApi<ReactFlowState>>;
export { Provider, useStore, createStore, useStoreApi };
