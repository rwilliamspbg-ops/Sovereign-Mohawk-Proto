import { MouseEvent } from 'react';
import { GetState, SetState } from 'zustand';
import { HandleElement, Node, ReactFlowState } from '../../types';
export declare const getHandleBounds: (selector: string, nodeElement: HTMLDivElement, zoom: number) => HandleElement[] | null;
export declare function getMouseHandler(id: string, getState: GetState<ReactFlowState>, handler?: (event: MouseEvent, node: Node) => void): ((event: MouseEvent) => void) | undefined;
export declare function handleNodeClick({ id, store, }: {
    id: string;
    store: {
        getState: GetState<ReactFlowState>;
        setState: SetState<ReactFlowState>;
    };
}): void;
